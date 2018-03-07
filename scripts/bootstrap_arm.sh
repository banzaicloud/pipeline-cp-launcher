#!/usr/bin/env bash

set -o nounset
set -o pipefail
set -o errexit
set -x
 
export LC_ALL=C

KUBERNETES_RELEASE_TAG=v1.8.3
ETCD_RELEASE_TAG=3.0.17
K8S_DNS_RELEASE_TAG=1.14.7
HELM_RELEASE_TAG=v2.7.0
PROMETHEUS_RELEASE_TAG=v1.8.2

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
    apt-transport-https \
    socat \
    ebtables \
    cloud-utils \
    cloud-init \
    cloud-initramfs-growroot \
    docker.io=1.13.1-0ubuntu1~16.04.2 \
    kubelet=1.8.3-00 \
    kubeadm=1.8.3-00 \
    kubernetes-cni=0.5.1-00 \
    sysstat \
    iotop \
    rsync \
    ngrep \
    tcpdump \
    atop \
    python-pip \
    curl \
    jq

# We don't want to upgrade them.
apt-mark hold kubeadm kubectl kubelet kubernetes-cni

apt-get -o Dpkg::Options::="--force-confold" upgrade -q -y --force-yes 
#install helm
curl https://storage.googleapis.com/kubernetes-helm/helm-${HELM_RELEASE_TAG}-linux-amd64.tar.gz | tar xz --strip 1 -C /usr/bin/

pip install --upgrade pip

systemctl enable docker
systemctl start docker

pip install awscli
pip install json2yaml

helm completion bash > /etc/bash_completion.d/helm
kubectl completion bash > /etc/bash_completion.d/kubectl

images=(
  "gcr.io/google_containers/kube-proxy-amd64:${KUBERNETES_RELEASE_TAG}"
  "gcr.io/google_containers/kube-apiserver-amd64:${KUBERNETES_RELEASE_TAG}"
  "gcr.io/google_containers/kube-scheduler-amd64:${KUBERNETES_RELEASE_TAG}"
  "gcr.io/google_containers/kube-controller-manager-amd64:${KUBERNETES_RELEASE_TAG}"
  "gcr.io/google_containers/etcd-amd64:${ETCD_RELEASE_TAG}"
  "gcr.io/google_containers/pause-amd64:3.0"
  "gcr.io/google_containers/k8s-dns-sidecar-amd64:${K8S_DNS_RELEASE_TAG}"
  "gcr.io/google_containers/k8s-dns-kube-dns-amd64:${K8S_DNS_RELEASE_TAG}"
  "gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64:${K8S_DNS_RELEASE_TAG}"
  "gcr.io/kubernetes-helm/tiller:${HELM_RELEASE_TAG}"
  "gcr.io/google_containers/kube-state-metrics:v1.1.0-rc.0"
  "bitnami/mariadb:10.1.28-r2"
  "grafana/grafana:latest"
  "traefik:1.4.1"
  "prom/prometheus:v1.8.0"
  "jimmidyson/configmap-reload:v0.1"
)

for i in "${images[@]}" ; do docker pull "${i}" ; done

# Weave network definition file
curl -s -q "https://raw.githubusercontent.com/banzaicloud/pipeline-cp-images/master/k8s/weave.yml" -o /etc/kubernetes/weave.yml


PRIVATEIP=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2017-04-02&format=text")
PUBLICIP=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-04-02&format=text")



kubeadm init --skip-preflight-checks --apiserver-advertise-address ${PRIVATEIP} --apiserver-cert-extra-sans ${PUBLICIP} ${PRIVATEIP}

kubectl apply -f /etc/kubernetes/weave.yml --kubeconfig /etc/kubernetes/admin.conf

sed -i -e 's|- --insecure-port=0|- --insecure-port=0\n    - --service-node-port-range=30-32767|' /etc/kubernetes/manifests/kube-apiserver.yaml

mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config

export KUBECONFIG=/root/.kube/config

until kubectl get po --all-namespaces
do
  sleep 5
  echo "Waiting...."
done

kubectl taint nodes $(hostname -s) node-role.kubernetes.io/master:NoSchedule-
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller

until helm list
do
  echo "Waiting...."
  kubectl get po --all-namespaces
  sleep 5
done

mkdir /opt/helm

cd /opt/helm
helm init -c
helm repo add banzaicloud-stable http://kubernetes-charts.banzaicloud.com
helm repo update
helm repo list
helm fetch banzaicloud-stable/pipeline-cp --untar

cd /opt/helm/pipeline-cp/
cp sample_values.json extra_values.json
cat extra_values.json | jq -r -M --arg jqsecret "${SECRET_ACCESS_KEY}" '.pipeline.awsSecretAccessKey|=$jqsecret' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqaccid "${ACCESS_KEY_ID}" '.pipeline.awsAccessKeyId|=$jqaccid' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqslackurl "${SLACK_WEBHOOK_URL}" '.pipeline.Slack.WebhookUrl|=$jqslackurl' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqslackchannel "${SLACK_CHANNEL}" '.pipeline.Slack.Channel|=$jqslackchannel' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqslackurl "${SLACK_WEBHOOK_URL}" '.prometheus.alertmanager.slack_api_url|=$jqslackurl' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqslackchannel "${SLACK_CHANNEL}" '.prometheus.alertmanager.slack_channel|=$jqslackchannel' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqsmtpaddr "${SMTP_SERVER_ADDRESS}" '.prometheus.alertmanager.smtp_address|=$jqsmtpaddr' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqsmtpuser "${SMTP_USERNAME}" '.prometheus.alertmanager.smtp_username|=$jqsmtpuser' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqsmtppass "${SMTP_PASSWORD}" '.prometheus.alertmanager.smtp_password|=$jqsmtppass' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqsmtpto "${SMTP_TO}" '.prometheus.alertmanager.smtp_to|=$jqsmtpto' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqsmtpfrom "${SMTP_FROM}" '.prometheus.alertmanager.smtp_from|=$jqsmtpfrom' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqprominguser "${PROM_ING_USER}" '.prometheus.ingress.user|=$jqprominguser' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqpromingpass "$(openssl passwd -apr1 \"$PROM_ING_PASS\")" '.prometheus.ingress.password|=$jqpromingpass' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqgrafanauser "${GRAFANA_USER}" '.grafana.server.adminUser|=$jqgrafanauser' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqgrafanapass "${GRAFANA_PASS}" '.grafana.server.adminPassword|=$jqgrafanapass' >  extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqgithuborgs "${GITHUB_ORGS}" '.drone.server.env.DRONE_ORGS|=$jqgithuborgs' >  extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqgithubclient "${GITHUB_CLIENT}" '.global.auth.clientid|=$jqgithubclient' >  extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqgithubsecret "${GITHUB_SECRET}" '.global.auth.clientsecret|=$jqgithubsecret' >  extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqpiplineimagetag "${PIPELINE_IMAGE_TAG}" '.pipeline.image.tag|=$jqpiplineimagetag' >  extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqpiplineazureclientid "${AZURE_CLIENT_ID}" '.pipeline.azureClientId|=$jqpiplineazureclientid' >  extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqpiplineazureclientsecret "${AZURE_CLIENT_SECRET}" '.pipeline.azureClientSecret|=$jqpiplineazureclientsecret' >  extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqpiplineazuresubscriptionid "${AZURE_SUBSCRIPTION_ID}" '.pipeline.azureSubscriptionId|=$jqpiplineazuresubscriptionid' >  extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqpiplineazuretenantid "${AZURE_TENANT_ID}" '.pipeline.azureTenantId|=$jqpiplineazuretenantid' >  extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqHelmRetryAttempt "${PIPELINE_HELM_RETRYATTEMPT}" '.pipeline.Helm.retryAttempt|=$jqHelmRetryAttempt' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | jq -r -M --arg jqHelmRetrySleepSeconds "${PIPELINE_HELM_RETRYSLEEPSECONDS}" '.pipeline.Helm.retrySleepSeconds|=$jqHelmRetrySleepSeconds' > extra_values.tmp && mv extra_values.tmp extra_values.json
cat extra_values.json | json2yaml >> extra_values.yaml
helm install . -f values.yaml -f extra_values.yaml --debug --wait --timeout 600
mkdir -p /opt/pipeline/.ssh
ssh-keygen -t rsa -b 4096 -f  /opt/pipeline/.ssh/id_rsa -N ""
