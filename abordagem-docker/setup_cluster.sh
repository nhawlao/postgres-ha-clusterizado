cat << 'SCRIPTEOF' > setup_cluster.sh
#!/bin/bash

echo "Inicializando a estrutura do banco no MASTER..."
docker exec -u postgres pg_master initdb -D /var/lib/postgresql/data

echo "Configurando MASTER..."
docker exec -u postgres pg_master bash -c "cat >> /var/lib/postgresql/data/postgresql.conf <<EOL
listen_addresses = '*'
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
hot_standby = on
archive_mode = on
archive_command = '/bin/true'
EOL"

docker exec -u postgres pg_master bash -c "echo 'host replication repmgr 0.0.0.0/0 trust' >> /var/lib/postgresql/data/pg_hba.conf"
docker exec -u postgres pg_master bash -c "echo 'host all repmgr 0.0.0.0/0 trust' >> /var/lib/postgresql/data/pg_hba.conf"

echo "node_id=1
node_name='node_master'
conninfo='host=pg_master user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/postgresql/data'" > repmgr_master.conf

docker cp repmgr_master.conf pg_master:/var/lib/postgresql/data/repmgr.conf
docker exec -u root pg_master chown postgres:postgres /var/lib/postgresql/data/repmgr.conf

docker exec -u postgres pg_master pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/logfile start
sleep 3
docker exec -u postgres pg_master psql -c "CREATE USER repmgr WITH SUPERUSER;"
docker exec -u postgres pg_master psql -c "CREATE DATABASE repmgr OWNER repmgr;"
docker exec -u postgres pg_master repmgr -f /var/lib/postgresql/data/repmgr.conf primary register
echo ">>> MASTER PRONTO <<<"

echo "Configurando REPLICA 1..."
echo "node_id=2
node_name='node_replica1'
conninfo='host=pg_replica1 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/postgresql/data'" > repmgr_replica1.conf

docker cp repmgr_replica1.conf pg_replica1:/var/lib/postgresql/data/repmgr.conf
docker exec -u root pg_replica1 chown postgres:postgres /var/lib/postgresql/data/repmgr.conf

docker exec -u postgres pg_replica1 repmgr -h pg_master -U repmgr -d repmgr -f /var/lib/postgresql/data/repmgr.conf standby clone
docker exec -u postgres pg_replica1 pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/logfile start
sleep 2
docker exec -u postgres pg_replica1 repmgr -f /var/lib/postgresql/data/repmgr.conf standby register
echo ">>> REPLICA 1 PRONTA <<<"

echo "Configurando REPLICA 2..."
echo "node_id=3
node_name='node_replica2'
conninfo='host=pg_replica2 user=repmgr dbname=repmgr connect_timeout=2'
data_directory='/var/lib/postgresql/data'" > repmgr_replica2.conf

docker cp repmgr_replica2.conf pg_replica2:/var/lib/postgresql/data/repmgr.conf
docker exec -u root pg_replica2 chown postgres:postgres /var/lib/postgresql/data/repmgr.conf

docker exec -u postgres pg_replica2 repmgr -h pg_master -U repmgr -d repmgr -f /var/lib/postgresql/data/repmgr.conf standby clone
docker exec -u postgres pg_replica2 pg_ctl -D /var/lib/postgresql/data -l /var/lib/postgresql/logfile start
sleep 2
docker exec -u postgres pg_replica2 repmgr -f /var/lib/postgresql/data/repmgr.conf standby register
echo ">>> REPLICA 2 PRONTA <<<"

echo "========================================="
echo " CLUSTER CONFIGURADO COM SUCESSO! "
echo "========================================="
SCRIPTEOF