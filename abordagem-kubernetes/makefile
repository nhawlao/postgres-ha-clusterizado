install-kind:
	chmod +x ./kind
	sudo mv ./kind /usr/local/bin/kind

arm-kind:
	[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.32.0/kind-linux-arm64
	install-kind

amd-kind:
	[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.32.0/kind-linux-amd64
	install-kind

deps:
	sudo apt-get update
	sudo apt-get install -y curl
	sudo apt-get install -y snapd
	sudo snap install kubectl --classic
	sudo snap install helm --classic


kube-cluster:
	kind create cluster --name pg-ha-cluster --config kind-config.yaml
	kubectl cluster-info --context kind-pg-ha-cluster
	kubectl get nodes

kube-pg-setup:
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update
	helm upgrade --install my-postgres-ha oci://registry-1.docker.io/bitnamicharts/postgresql-ha --namespace db-layer --values values.yaml

kube-pg-clean:
	helm uninstall my-postgres-ha -n db-layer
	kubectl delete pvc -l app.kubernetes.io/instance=my-postgres-ha -n db-layer
	helm repo update

kube-pg-update:
	helm upgrade --install my-postgres-ha oci://registry-1.docker.io/bitnamicharts/postgresql-ha --namespace db-layer --values values.yaml

kube-pg-helm-status:
	helm status my-postgres-ha -n db-layer
	helm list -n db-layer

describe:
	kubectl get all -n db-layer
	kubectl exec -it my-postgres-ha-postgresql-ha-postgresql-0 -n db-layer -- /opt/bitnami/scripts/postgresql-repmgr/entrypoint.sh repmgr -f /opt/bitnami/repmgr/conf/repmgr.conf cluster show

port-forward:
	kubectl port-forward svc/my-postgres-ha-postgresql-ha-pgpool 5432:5432 -n db-layer

sleep:
	kubectl scale deployment my-postgres-ha-postgresql-ha-pgpool --replicas=0 -n db-layer
	kubectl scale statefulset  my-postgres-ha-postgresql-ha-postgresql --replicas=0 -n db-layer

wakeup:
	kubectl scale deployment my-postgres-ha-postgresql-ha-pgpool --replicas=1 -n db-layer
	kubectl scale statefulset  my-postgres-ha-postgresql-ha-postgresql --replicas=3 -n db-layer

delete-cluster:
	kind delete cluster --name pg-ha-cluster
