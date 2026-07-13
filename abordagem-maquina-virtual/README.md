Depois de preparar e instalar as ferramentas necessárias em cada uma das três VMs (Postgresql, etcd e patroni), seguimos esses passos para preparar o terreno:

Fase 1 - Configuração do etcd

O etcd precisa saber quem são os membros do cluster, os nós da topologia

1- Comando para editar o ficheiro de configuração do etcd:
  
    sudo nano /etc/default/etcd

2- Configuração exata para o Nó 1 (172.31.29.97):

    ETCD_NAME="node1"
    ETCD_LISTEN_PEER_URLS="http://172.31.29.97:2380"
    ETCD_LISTEN_CLIENT_URLS="http://172.31.29.97:2379,http://127.0.0.1:2379"
    ETCD_INITIAL_ADVERTISE_PEER_URLS="http://172.31.29.97:2380"
    ETCD_ADVERTISE_CLIENT_URLS="http://172.31.29.97:2379"
    ETCD_INITIAL_CLUSTER_TOKEN="postgres-cluster-token"
    ETCD_INITIAL_CLUSTER="node1=http://172.31.29.97:2380,node2=http://172.31.17.133:2380,node3=http://172.31.31.232:2380"
    ETCD_INITIAL_CLUSTER_STATE="new"
  
(Instruções para VM2 e VM3: Nas VMs 2 e 3, este ficheiro deve ser idêntico, alterando-se apenas o ETCD_NAME para node2 ou node3, e os respetivos IPs nas variáveis LISTEN e ADVERTISE).

3- Reiniciar o serviço etcd para aplicar a rede distribuída:

    sudo systemctl restart etcd
    sudo systemctl enable etcd


    

Fase 2 - Preparação do Terreno

Como o Patroni será o "gestor" oficial, o serviço padrão do PostgreSQL do Ubuntu deve ser desativado para evitar conflitos de portas (5432) e os dados iniciais gerados pelo Ubuntu devem ser eliminados.

Logo, executamos nas 3 VMs:

1- Parar e desativar o serviço padrão do PostgreSQL:

    sudo systemctl stop postgresql
    sudo systemctl disable postgresql


2- Destruir os ficheiros da inicialização padrão para dar espaço ao Patroni:

    sudo rm -rf /var/lib/postgresql/18/main/*
    sudo rm -f /tmp/pgpass






Fase 3 - Configuração do Patroni

Criação do ficheiro YAML para as 3 VMs.
O YAML dita as regras de replicação, autenticação e comunicação.

1- Criar o ficheiro no Nó 1 (172.31.29.97):

    sudo nano /etc/patroni.yml

Dentro da caixa de texto que abre, executamos esse comando

    scope: postgres-cluster
    namespace: /db/
    name: node1
    
    restapi:
      listen: 172.31.29.97:8008
      connect_address: 172.31.29.97:8008
    
    etcd3:
      hosts: 172.31.29.97:2379,172.31.17.133:2379,172.31.31.232:2379
    
    bootstrap:
      dcs:
        ttl: 30
        loop_wait: 10
        retry_timeout: 10
        maximum_lag_on_failover: 1048576
        postgresql:
          use_pg_rewind: true
      initdb:
        - auth-host: md5
        - auth-local: trust
        - encoding: UTF8
        - data-checksums
    
    postgresql:
      listen: 172.31.29.97:5432
      connect_address: 172.31.29.97:5432
      data_dir: /var/lib/postgresql/18/main
      bin_dir: /usr/lib/postgresql/18/bin
      pgpass: /tmp/pgpass
      authentication:
        replication:
          username: replicator
          password: replica_password
        superuser:
          username: postgres
          password: admin_password
      pg_hba:
        - host all all 0.0.0.0/0 md5
        - host replication replicator 0.0.0.0/0 md5
    
(Seguindo a mesma lógica do etcd, nas VMs 2 e 3, cria-se o mesmo ficheiro patroni.yml, substituindo a variável name e os IPs locais do restapi e postgresql pelos da respetiva máquina).





Fase 4 - Inicialização  e Criação de Papéis

Agora os comandos serão apenas no leader da topologia

1- Limpar registos antigos de tentativas anteriores (Nó 1 escolhido):

    etcdctl del --prefix /db/

2 - Ligar o serviço no Líder (Nó 1):

    sudo systemctl start patroni

(Importante esperar um tempo razoável, esperamos 1 minuto para a topologia entender que o nó 1 foi criado e ele é o leader, antes de iniciarmos os outros nós)

3 - Injetar a credencial de replicação burlando o socket local (Apenas no leader - Nó 1):

Aqui uma adaptação que fizemos porque o acesso direto não estava acontecendo, como o pg_hba.conf restringe o acesso direto, o utilizador é forçado pela rede:

    PGPASSWORD="admin_password" psql -h 172.31.29.97 -U postgres -d postgres -c "CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replica_password';"


Fase 5 - Integração das replicas

Basicamente tudo está pronto, só ligar o patroni nas outras VMs e verificar a topologia

1 - Ligar o Patroni nas réplicas (No Nó 2 e Nó 3):

    sudo systemctl start patroni

2 - Verificar e validar a topologia:

    sudo patronictl -c /etc/patroni.yml topology
