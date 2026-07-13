# Servidor de Banco de Dados Clusterizado (PostgreSQL HA) - Sistemas Operacionais
Repositório colaborativo para o desenvolvimento do projeto final da disciplina de Sistemas Operacionais.

> **Autores:**  
>    Gabriel Lima Dantas;  
>    João Pedro Sá;  
>    Leonardo Souza Silva;  
>    Nayla Sahra Santos das Chagas.

## Objetivo
 Configurar pelo menos três VMs Linux para suportar um banco de dados em alta disponibilidade. O grupo deve instalar o PostgreSQL, configurar a replicação física de dados (Master/Replica) e utilizar uma ferramenta como o Patroni ou repmgr para gerenciar o cluster e realizar o "failover" automático se o nó principal falhar.


## Metodologia

O desenvolvimento do trabalho se deu a partir do desenvolvimento de quatro etapas:

1. Utilização de abordagens distribuídas em bancos de dados
2. Estudo de caso e desenvolvimento de abordagens
3. Ferramentas, tutoriais e referências
4. Conclusão

## Utilização de abordagens distribuídas em bancos de dados

Por mais direcionados e detalhados sejam os cenários preditos por desenvolvedores, todo sistema apresenta falhas em algum momento do seu ciclo de vida. Geralmente o volume das falhas apresentadas aumenta de acordo com o crescimento no número de acessos ou da necessidade de recursos. Um dos problemas clássicos da área de sistemas operacionais aborda justamente as possíveis consequências do crescimento da demanda de acesso a um banco de dados: o problema dos leitores e escritores. Apesar das diversas aplicações de semáforos e threads em uma instância simples, o que permite um melhor gerenciamento do problema, sistemas de qualidade devem garantir performance, escalabilidade, usabilidade e confiabilidade.
Uma das formas de implementar esses princípios é através da utilização de abordagens distribuídas. Um banco de dados distribuído é caracterizado pelo armazenamento de informação em mais de um ponto, chamados de nós ou instâncias, de forma a possibilitar o acesso às mesmas informações independente do ponto acessado. Assim, bancos de dados distribuídos oferecem escalabilidade horizontal, alta disponibilidade, tolerância a falhas e persistência de dados.

## Abordagens exploradas

Nesse projeto, exploramos três cenários de distribuição de bancos de dados, considerando suas ferramentas e facilidade de compreensão dos conceitos. Durante o desenvolvimento do projeto optamos por selecionar a abordagem de máquina virtual como abordagem principal para apresentação. Os conceitos utilizados no projeto convergem com os conteúdos da disciplina de forma mais clara e direta, além de possibilitar uma reprodução fiel pelo restante da turma caso desejado, já que descarta o uso ferramentas mais abstratas ou hardware específico.
O código de todas as abordagens pode ser encontrado em suas respectivas pastas, referenciadas em cada um dos tópicos a seguir.
## [Abordagem de máquina virtual](abordagem-maquina-virtual/README.md)
![Arquitetura de banco distribuído com máquinas virtuais](docs/abordagem1-maquina-virtual.png)

## [Abordagem de contâiner docker](abordagem-docker/README.md)
![Arquitetura de banco distribuído com containers dockerizados](docs/abordagem2-cluster-docker.png)

## [Abordagem de contâiner kubernetes](abordagem-kubernetes/README.md)
![Arquitetura de banco distribuído com cluster kubernetes](docs/abordagem3-cluster-kubernetes.png)  
A arquitetura baseia-se na separação estrita de responsabilidades entre **roteamento e inteligência de consultas** (camada de proxy) e **armazenamento persistente e replicação** (camada de dados).

### Componentes Chave:

1. **Kubernetes Cluster (Kind):** Fornece a infraestrutura em containers simulando um ambiente multi-nó real (1 Control-Plane e 2 Workers).
2. **Pgpool-II (Camada de Roteamento):** Implantado como um `Deployment`. Funciona como o único ponto de entrada para a aplicação. Analisa as queries SQL para separar escritas de leituras e balancear a carga.
3. **PostgreSQL + repmgr (Camada de Dados):** Implantado como um `StatefulSet` com volumes persistentes para garantir a identidade estável de cada nó (ex: `pod-0`, `pod-1`). O `repmgr` gerencia a saúde local e automatiza o *failover* eleger um novo líder se o principal falhar.


### Dinâmica de Funcionamento (Escritas e Leituras)

Toda a interação é feita apontando para o Service do Pgpool-II (porta `5432`). O comportamento interno opera sob as seguintes regras fundamentais:

#### Fluxo de Escritas (Write)

1. A aplicação envia comandos do tipo `INSERT`, `UPDATE`, `DELETE` ou abre blocos de transação estruturados (`BEGIN ... COMMIT`) para o Pgpool-II.
2. O Pgpool-II intercepta o comando e identifica que ele altera o estado do banco.
3. A operação é **direcionada exclusivamente para o Pod Primário** (`my-postgres-ha-postgresql-ha-postgresql-0`).


4. O nó primário grava o dado e propaga assincronamente as alterações geradas nos arquivos de log (*Write-Ahead Logging - WAL*) para os nós secundários via streaming replication assistido pelo `repmgr`.

#### Fluxo de Leituras (Read)

1. A aplicação executa uma query de consulta pura (`SELECT`).
2. O Pgpool-II analisa o comando e constata que ele é seguro para leitura paralela.
3. Aplicando algoritmos internos de balanceamento de carga, ele envia a query para **qualquer um dos Pods disponíveis no pool** (`pod-0`, `pod-1` ou `pod-2`), distribuindo a carga de CPU e I/O de maneira uniforme e otimizando o uso das réplicas.

## Ferramentas, tutoriais utilizados e referências
- [PostgreSQL](https://www.postgresql.org/docs/)
- [Patroni](https://patroni.readthedocs.io/en/latest/)
- [Repmgr](https://github.com/EnterpriseDB/repmgr)
- [PGPool-ii](https://www.pgpool.net/documentation/)
- [Bitnami](https://charts.bitnami.com/)
- [Helm](https://helm.sh/pt/docs/)
- [Docker](https://docs.docker.com/)
- [Kubernetes](https://kubernetes.io/pt-br/docs/home/)
- [Kubectl](https://kubernetes.io/pt-br/docs/tasks/tools/install-kubectl-linux/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#creating-a-cluster)
- [Helm for Data Engineers: A Beginner’s Guide Using kind and PostgreSQL](https://medium.com/@khoramism/helm-for-data-engineers-a-beginners-guide-using-kind-and-postgresql-5528fe993fbb)
- [Postgres-ha](https://artifacthub.io/packages/helm/bitnami/postgresql-ha)
- [How to implement repmgr for PostgreSQL automatic failover](https://www.enterprisedb.com/postgres-tutorials/how-implement-repmgr-postgresql-automatic-failover)
## Conclusão
