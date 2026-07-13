Antes de iniciar o passo a passo, foi realizada a instalação do Docker e do Docker Compose seguindo o tutorial citados nas referências.

# Fase 1: Preparação dos Arquivos
Na EC2, após instalar o Docker:

Crie uma pasta para o projeto ```mkdir pg-cluster```, entre na pasta do projeto ```cd pg-cluster```. Agora crie o Dockerfile, que é essencial para reduzir a complexidade do Docker Compose:

```
cat <<EOF > Dockerfile
FROM postgres:13
RUN apt-get update && apt-get install -y \
    repmgr \
    postgresql-13-repmgr \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*
EOF
```
_Nota: A versão do PsostgreSQL usada foi a 13, mas podem ser utilizadas outras versões mais recentes._

Crie então o Docker Compose:

```
cat <<EOF > docker-compose.yml
services:
  pg_master:
    build: .
    container_name: pg_master
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    networks:
      - pg_ha_network
    volumes:
      - pg_master_data:/var/lib/postgresql/data
    command: tail -f /dev/null

  pg_replica1:
    build: .
    container_name: pg_replica1
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5433:5432"
    networks:
      - pg_ha_network
    volumes:
      - pg_replica1_data:/var/lib/postgresql/data
    command: tail -f /dev/null
    depends_on:
      - pg_master

  pg_replica2:
    build: .
    container_name: pg_replica2
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5434:5432"
    networks:
      - pg_ha_network
    volumes:
      - pg_replica2_data:/var/lib/postgresql/data
    command: tail -f /dev/null
    depends_on:
      - pg_master

networks:
  pg_ha_network:
    driver: bridge

volumes:
  pg_master_data:
  pg_replica1_data:
  pg_replica2_data:
EOF
```

# Fase 2: Subir a Infraestrutura

Construa as imagens e ligue os containers (com essas especificações pode demorar um pouco):

```
docker compose up -d --build
```
_Nota: O --build é para garantir que use as especificações do Dockerfile_

# Fase 3: Iniciando os nós

Limpeza do ambiente:
```
cd ~/pg-cluster
docker compose down -v
```

_Nota: As vezes ao subir o Docker e testar se deu certo, pode dar algum erro nos passos futuros, por isso limpar a pasta reduz erros._

Agora é só subir os containers:

```
docker compose up -d
```

_Nota: Importante salientar que todas essas operações devem ser realizadas na pasta pg-cluster!_

Com o compose rodando, basta rodar o script de setup:

Primeiro ```chmod +x setup_cluster.sh```, depois ```./setup_cluster.sh```.

Por fim, se tudo der certo, é só validar:

```
docker exec -u postgres pg_master repmgr -f /var/lib/postgresql/data/repmgr.conf cluster show`
```

Deve aoarecer algo como:

~/pg-cluster$ docker exec -u postgres pg_master repmgr -f /var/lib/postgresql/data/repmgr.conf cluster show

    ID | Name        | Role    | Status    | Upstream | Location | Priority | Timeline | Connection string

    ----+-------------+---------+-----------+----------+----------+----------+----------+------------------------------------------------------------

    1  | node_master | primary | * running | 

Isso significa que o master está funcionando perfeitamente, as réplicas não foram criadas. Isso se deu pois o repmgr não apagou uns arquivos padrão que o próprio Docker cria na pasta da réplica e parou por segurança. Para soluciona isso, se usa o parâmetro -F nos comando de clone para as réplicas:

```
docker exec -u postgres pg_replica1 repmgr -h pg_master -U repmgr -d repmgr -f /var/lib/postgresql/data/repmgr.conf standby clone -F
```

Após os dados serem baixados, é só iniciar ```docker exec -u postgres pg_replica1 pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/logfile start```, e registrar ```docker exec -u postgres pg_replica1 repmgr -f /var/lib/postgresql/data/repmgr.conf standby register```.

O mesmo processo se repete para a próxima réplica:

```
docker exec -u postgres pg_replica2 repmgr -h pg_master -U repmgr -d repmgr -f /var/lib/postgresql/data/repmgr.conf standby clone -F
```

Esperar baixar os dados para iniciar ```docker exec -u postgres pg_replica2 pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/logfile start``` e registrar ```docker exec -u postgres pg_replica2 repmgr -f /var/lib/postgresql/data/repmgr.conf standby register```.

Com isso é possível fazer a validação:
```docker exec -u postgres pg_master repmgr -f /var/lib/postgresql/data/repmgr.conf cluster show```

# Em caso de erros:

Passei por um problema ao dar clone nas réplicas, o "ERROR: this node should be a standby (host=pg_master user=repmgr dbname=repmgr connect_timeout=2)", que ocorre quando é rodado o standby clone -F, ele faz uma cópia exata de tudo que tem no Master, incluindo a pasta de dados. Isso sobrescreve o seu repmgr.conf da réplica e coloca o arquivo do Master no lugar. É possível consertar isso seguindo esses passos:

* 1: Pare o Postgres que está rodando com a configuração errada ```docker exec -u postgres pg_replica1 pg_ctl -D /var/lib/postgresql/data stop```, e reenvie o arquivo de configuração sobrescrevendo o do Master:

```docker cp repmgr_replica1.conf pg_replica1:/var/lib/postgresql/data/repmgr.conf
docker exec -u root pg_replica1 chown postgres:postgres /var/lib/postgresql/data/repmgr.conf
```

Por fim, é só iniciar novamente ```docker exec -u postgres pg_replica1 pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/logfile start```, e registrar ```docker exec -u postgres pg_replica1 repmgr -f /var/lib/postgresql/data/repmgr.conf standby register```.

* 2: Dessa vez ´s só fazer o clone primeiro ```docker exec -u postgres pg_replica2 repmgr -h pg_master -U repmgr -d repmgr -f /var/lib/postgresql/data/repmgr.conf standby clone -F``` e enviar o arquivo correto:

```
docker cp repmgr_replica2.conf pg_replica2:/var/lib/postgresql/data/repmgr.conf
docker exec -u root pg_replica2 chown postgres:postgres /var/lib/postgresql/data/repmgr.conf
```

Para finalizar basta iniciar ```docker exec -u postgres pg_replica2 pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/logfile start``` e registrar ```docker exec -u postgres pg_replica2 repmgr -f /var/lib/postgresql/data/repmgr.conf standby register```.

Por fim, é só viazualizar o resultados do Master e dos dois nós ```docker exec -u postgres pg_master repmgr -f /var/lib/postgresql/data/repmgr.conf cluster show```. É possível também verificar o status interno do Postgres, só rodar esse comando no terminal do Master: ```docker exec -u postgres pg_master psql -c "SELECT client_addr, state, sent_lsn, replay_lsn FROM pg_stat_replication;```.

# Referências:
* Equipe Diolinux. Como instalar Docker no Ubuntu Server - Guia Rápido. Disponível em: https://plus.diolinux.com.br/t/como-instalar-docker-no-ubuntu-server-guia-rapido/55581.
* GLM-5-Turbo [Resposta à pergunta sobre criação de docker-compose e script de automação para cluster PostgreSQL com repmgr]. Resposta fornecida ao usuário em 11 junho 2026.
* ENTERPRISEDB. repmgr: PostgreSQL High Availability and Replication Management Documentation. Disponível em: https://www.repmgr.org/docs/current/. Acesso em: 11 junho 2026.
* DOCKER. Docker Documentation: Compose file version 3.8. Disponível em: https://docs.docker.com/compose/compose-file/compose-file-v3/. Acesso em: 11 junho 2026.
* OLIVEIRA, João. PostgreSQL High Availability and Automatic Failover using repmgr. Medium, 2020. Disponível em: https://medium.com/@joao_o/postgresql-high-availability-and-automatic-failover-using-repmgr-5f505dc6913a. Acesso em: 11 junho 2026.
* POSTGRESQL GLOBAL DEVELOPMENT GROUP. PostgreSQL 13 Documentation: Chapter 26. High Availability, Load Balancing, and Replication. Disponível em: https://www.postgresql.org/docs/13/high-availability.html. Acesso em: 11 junho 2026.
* POSTGRESQL GLOBAL DEVELOPMENT GROUP. PostgreSQL 13 Documentation: Chapter 19. Server Configuration - Write Ahead Log. Disponível em: https://www.postgresql.org/docs/13/wal-configuration.html. Acesso em: 11 junho 2026.


