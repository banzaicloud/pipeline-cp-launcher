STACK_NAME ?=pipeline-controlplane-$(USER)
INSTANCE_NAME ?=$(STACK_NAME)

SLACK_URL ?=""
SLACK_CHANNEL ?=""
SMTP_SERVER_ADDRESS ?=""
SMTP_USERNAME ?=""
SMTP_PASSWORD ?=""
SMTP_TO ?=""
SMTP_FROM ?=""
TRUSTED_USER_CA_URL ?=""

ifeq ($(shell git describe --exact-match --tags 2>/dev/null || echo "branch"),branch)
	CHART_REPO ?= "http://kubernetes-charts.banzaicloud.com/branch/$(shell git rev-parse --abbrev-ref HEAD)"
	PIPELINE_HELM_BANZAIREPOSITORYURL ?= $(CHART_REPO)
else
	CHART_REPO ?= "http://kubernetes-charts.banzaicloud.com/release/$(shell git describe --exact-match --tags)"
	PIPELINE_HELM_BANZAIREPOSITORYURL ?= $(CHART_REPO)
endif

AZURE_RESOURCEGROUP ?=$(USER)_$(AZURE_LOCATION)

GCLOUD_ZONE ?= $(shell gcloud config get-value compute/zone)
GCLOUD_REGION ?= $(shell gcloud config get-value compute/region)
GCLOUD_PROJECT_ID ?= $(shell gcloud config get-value core/project)

VAULT_ROLE_ID ?= $(shell vault read -field role_id auth/approle/role/hostrole/role-id)
VAULT_SECRET_ID ?= $(shell vault write -f -field secret_id auth/approle/role/hostrole/secret-id)

UNAME_S := $(shell uname -s)
MINIKUBE_FLAGS :=
ifeq ($(UNAME_S),Darwin)
	MINIKUBE_FLAGS += --vm-driver hyperkit
endif

.DEFAULT_GOAL := list
.PHONY: list

.PHONY: _no-target-specified
_no-target-specified:
	$(error Please specify the target to make - `make list` shows targets.)

.PHONY: list
list:
	@$(MAKE) -pRrn : -f $(MAKEFILE_LIST) 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort

create-local: .check-env-pipeline
	-kubectl -n kube-system create serviceaccount tiller >/dev/null
	-kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller >/dev/null
	helm repo add banzaicloud-stable $(CHART_REPO)
	helm repo update
	helm init --upgrade --wait --service-account=tiller >/dev/null
	helm upgrade --install cp-launcher banzaicloud-stable/pipeline-cp \
		--set global.auth.clientid=$(GITHUB_CLIENT) \
		--set global.auth.clientsecret=$(GITHUB_SECRET) \
		--set prometheus.ingress.password=$(PROM_ING_PASS) \
		--set grafana.server.adminPassword=$(GRAFANA_PASS) \
		--set drone.server.env.DRONE_ORGS=$(GITHUB_ORGS) \
		--set drone.server.host=http://cp-launcher-drone \
		--set pipeline.image.tag=$(PIPELINE_IMAGE_TAG) \
		--set pipeline.helm.retryAttempt=$(PIPELINE_HELM_RETRYATTEMPT) \
		--set pipeline.helm.retrySleepSeconds=$(PIPELINE_HELM_RETRYSLEEPSECONDS) \
		--set pipeline.helm.banzaiRepositoryURL=$(PIPELINE_HELM_BANZAIREPOSITORYURL) \
		--timeout 9999

terminate-local:
	helm delete --purge cp-launcher
	kubectl delete secret bank-vaults

.create-minikube:
	minikube start --bootstrapper kubeadm --memory 4096 $(MINIKUBE_FLAGS)

create-minikube: .check-env-pipeline .create-minikube create-local
	@echo "GitHub Authorization callback URL: `minikube service --url cp-launcher-traefik | head -1`/auth/github/callback"
	@echo "Pipeline login: `minikube service --url cp-launcher-traefik | head -1`/auth/github/login"
	@echo "Grafana login: `minikube service --url cp-launcher-traefik | head -1`/grafana"
	@echo "Prometheus: `minikube service --url cp-launcher-traefik | head -1`/prometheus"

terminate-minikube:
	minikube delete

create-aws: .check-env-aws
	aws cloudformation create-stack \
		--template-body file://control-plane-cf.template \
		--stack-name $(STACK_NAME) \
		--parameters \
		ParameterKey=InstanceName,ParameterValue=$(INSTANCE_NAME) \
		ParameterKey=AccessKeyID,ParameterValue=$(AWS_ACCESS_KEY_ID) \
		ParameterKey=SecretAccessKey,ParameterValue=$(AWS_SECRET_ACCESS_KEY) \
		ParameterKey=ImageId,ParameterValue=$(IMAGE_ID) \
		ParameterKey=KeyName,ParameterValue=$(KEY_NAME) \
		ParameterKey=InstanceType,ParameterValue=$(AWS_INSTANCE_TYPE) \
		ParameterKey=SlackWebhookUrl,ParameterValue=$(SLACK_URL) \
		ParameterKey=SlackChannel,ParameterValue=$(SLACK_CHANNEL) \
		ParameterKey=SmtpServerAddress,ParameterValue=$(SMTP_SERVER_ADDRESS) \
		ParameterKey=SmtpUser,ParameterValue=$(SMTP_USERNAME) \
		ParameterKey=SmtpPassword,ParameterValue=$(SMTP_PASSWORD) \
		ParameterKey=SmtpTo,ParameterValue=$(SMTP_TO) \
		ParameterKey=SmtpFrom,ParameterValue=$(SMTP_FROM) \
		ParameterKey=PromIngPass,ParameterValue=$(PROM_ING_PASS) \
		ParameterKey=GrafanaPass,ParameterValue=$(GRAFANA_PASS) \
		ParameterKey=GithubOrgs,ParameterValue=$(GITHUB_ORGS) \
		ParameterKey=GithubClient,ParameterValue=$(GITHUB_CLIENT) \
		ParameterKey=GithubSecret,ParameterValue=$(GITHUB_SECRET) \
		ParameterKey=PipelineImageTag,ParameterValue=$(PIPELINE_IMAGE_TAG) \
		ParameterKey=HelmRetryAttempt,ParameterValue=$(PIPELINE_HELM_RETRYATTEMPT) \
		ParameterKey=HelmRetrySleepSeconds,ParameterValue=$(PIPELINE_HELM_RETRYSLEEPSECONDS) \
		ParameterKey=HelmBanzaiRepositoryURL,ParameterValue=$(PIPELINE_HELM_BANZAIREPOSITORYURL) \
		ParameterKey=TrustedUserCAURL,ParameterValue=$(TRUSTED_USER_CA_URL) \
		ParameterKey=VaultRoleID,ParameterValue=$(VAULT_ROLE_ID) \
		ParameterKey=VaultSecretID,ParameterValue=$(VAULT_SECRET_ID) \

terminate-aws:
	aws cloudformation delete-stack \
		--stack-name $(STACK_NAME)


.ARM_PARAMS := storageNamePrefix=$(AZURE_STORAGENAME_PREFIX) \
			storageAccountSKU=$(AZURE_STORAGEACCOUNT_SKU) \
			sshUserName=$(AZURE_SSH_USERNAME) \
			sshPublicKey="`cat $(AZURE_SSH_PUBLICKEY_PATH)`" \
			vmSize=$(AZURE_VM_SIZE) \
			vmNamePrefix=$(INSTANCE_NAME) \
			smtpServerAddress=$(SMTP_SERVER_ADDRESS) \
			smtpUser=$(SMTP_USERNAME) \
			smtpPassword=$(SMTP_PASSWORD) \
			smtpFrom=$(SMTP_FROM) \
			smtpFrom=$(SMTP_TO) \
			slackWebhookUrl=$(SLACK_URL) \
			slackChannel=$(SLACK_CHANNEL) \
			pipelineImageTag=$(PIPELINE_IMAGE_TAG) \
			promIngPass=$(PROM_ING_PASS) \
			grafanaPass=$(GRAFANA_PASS) \
			githubOrgs=$(GITHUB_ORGS) \
			githubClient=$(GITHUB_CLIENT) \
			githubSecret=$(GITHUB_SECRET) \
			azureClientId=$(AZURE_CLIENT_ID) \
			azureClientSecret=$(AZURE_CLIENT_SECRET) \
			azureSubscriptionId=$(AZURE_SUBSCRIPTION_ID) \
			azureTenantId=$(AZURE_TENANT_ID) \
			pipelineHelmRetryattempt=$(PIPELINE_HELM_RETRYATTEMPT) \
			pipelineHelmRetrysleepseconds=$(PIPELINE_HELM_RETRYSLEEPSECONDS) \
			trustedUserCaUrl=$(TRUSTED_USER_CA_URL) \
			vaultRoleId=$(VAULT_ROLE_ID) \
			vaultSecretId=$(VAULT_SECRET_ID) \
			banzaiRepositoryURL=$(PIPELINE_HELM_BANZAIREPOSITORYURL)

create-azure: .check-env-azure
	az group create --name $(AZURE_RESOURCEGROUP) --location $(AZURE_LOCATION)
	
	az group deployment create \
    	--name $(STACK_NAME) \
    	--resource-group $(AZURE_RESOURCEGROUP) \
    	--template-file control-plane-arm.json \
    	--parameters $(.ARM_PARAMS)


terminate-azure:
	az group delete --name $(AZURE_RESOURCEGROUP)

create-gcloud: .check-env-gcloud .gcloud_install_cp_chart
	@/bin/echo -n "Your Control Plane ip/host: "
	@kubectl get svc -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") .status.loadBalancer.ingress[].ip'

terminate-gcloud: .check-env-gcloud
	@gcloud container clusters delete $(STACK_NAME) --project $(GKE_PROJECT_ID)

.gcloud_create_k8s:
	@/bin/echo "Creating Control Plane:" $(STACK_NAME)
	@gcloud container clusters create $(STACK_NAME) \
		--cluster-version="1.9" \
		--num-nodes=1 \
		--zone $(GCLOUD_ZONE) \
		--no-enable-basic-auth \
		--project $(GKE_PROJECT_ID) \
		--machine-type=$(GKE_MACHINE_TYPE) 2>/dev/null
	@/bin/echo "---"

.gcloud_get_credential: .gcloud_create_k8s
	@gcloud container clusters get-credentials $(STACK_NAME) \
		--zone $(GCLOUD_ZONE) \
		--project $(GKE_PROJECT_ID) >/dev/null 2>&1 

.gcloud_install_helm_and_repo: .gcloud_get_credential
	@kubectl -n kube-system create serviceaccount tiller >/dev/null
	@kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller >/dev/null
	@helm init --service-account=tiller >/dev/null
	@/bin/echo -n "Installing Helm."
	@until false; do sleep 2; /bin/echo -n "."; helm list >/dev/null 2>&1 && /bin/echo "done" && break; done
	@helm repo add banzaicloud-stable $(CHART_REPO) > /dev/null

.gcloud_install_cp_chart: .gcloud_install_helm_and_repo
	@/bin/echo "Helm install banzaicloud-stable/pipeline-cp"
	@helm install banzaicloud-stable/pipeline-cp \
		--wait \
		--timeout 120 \
		--set=traefik.serviceType=LoadBalancer \
		--set=drone.server.env.DRONE_ORGS=$(GITHUB_ORGS) \
		--set=global.auth.clientid=$(GITHUB_CLIENT) \
		--set=global.auth.clientsecret=$(GITHUB_SECRET) \
		--set=pipeline.gkeCredentials.client_id=$(GKE_CLIENT_ID) \
		--set=pipeline.gkeCredentials.client_secret=$(GKE_CLIENT_SECRET) \
		--set=pipeline.gkeCredentials.refresh_token=$(GKE_REFRESH_TOKEN) \
		--set=pipeline.gkeCredentials.type=$(GKE_TYPE) \
		--set=prometheus.alertmanager.smtp_address=$(SMTP_SERVER_ADDRESS) \
		--set=prometheus.alertmanager.smtp_username=$(SMTP_USERNAME) \
		--set=prometheus.alertmanager.smtp_password=$(SMTP_PASSWORD) \
		--set=prometheus.alertmanager.smtp_from=$(SMTP_FROM) \
		--set=prometheus.alertmanager.smtp_to=$(SMTP_TO) \
		--set=prometheus.alertmanager.slack_api_url=$(SLACK_URL) \
		--set=prometheus.alertmanager.slack_channel=$(SLACK_CHANNEL) \
		--set=pipeline.image.tag=$(PIPELINE_IMAGE_TAG) \
		--set=prometheus.ingress.password=$(PROM_ING_PASS) \
		--set=grafana.server.adminPassword=$(GRAFANA_PASS) \
		--set=pipeline.helm.retryAttempt=$(PIPELINE_HELM_RETRYATTEMPT) \
		--set=pipeline.helm.retrySleepSeconds=$(PIPELINE_HELM_RETRYSLEEPSECONDS) \
		--set=pipeline.helm.banzaiRepositoryURL=$(PIPELINE_HELM_BANZAIREPOSITORYURL) \
		1>/dev/null

.check-env-azure: .check-env-pipeline
ifndef AZURE_LOCATION
	$(error AZURE_LOCATION is undefined)
endif

ifndef AZURE_RESOURCEGROUP
	$(error AZURE_RESOURCEGROUP is undefined)
endif

ifndef AZURE_STORAGEACCOUNT_SKU
	$(error AZURE_STORAGEACCOUNT_SKU is undefined)
endif

ifndef AZURE_STORAGENAME_PREFIX
	$(error AZURE_STORAGENAME_PREFIX is undefined)
endif

ifndef AZURE_SSH_USERNAME
	$(error AZURE_SSH_USERNAME is undefined)
endif

ifndef AZURE_SSH_PUBLICKEY_PATH
	$(error AZURE_SSH_PUBLICKEY_PATH is undefined)
endif

ifndef AZURE_VM_SIZE
	$(error AZURE_VM_SIZE is undefined)
endif

ifndef AZURE_CLIENT_ID
	$(error AZURE_CLIENT_ID is undefined)
endif

ifndef AZURE_CLIENT_SECRET
	$(error AZURE_CLIENT_SECRET is undefined)
endif

ifndef AZURE_SUBSCRIPTION_ID
	$(error AZURE_SUBSCRIPTION_ID is undefined)
endif

ifndef AZURE_TENANT_ID
	$(error AZURE_TENANT_ID is undefined)
endif

.check-env-aws: .check-env-pipeline

ifndef AWS_ACCESS_KEY_ID
	$(error AWS_ACCESS_KEY_ID is undefined)
endif

ifndef AWS_SECRET_ACCESS_KEY
	$(error AWS_SECRET_ACCESS_KEY is undefined)
endif

ifndef KEY_NAME
	$(error KEY_NAME is undefined)
endif

ifndef IMAGE_ID
	$(error IMAGE_ID is undefined)
endif


.check-env-gcloud: .check-env-pipeline

ifndef GKE_CLIENT_ID
	$(error GKE_CLIENT_ID is undefined)
endif

ifndef GKE_CLIENT_SECRET
	$(error GKE_CLIENT_SECRET is undefined)
endif

ifndef GKE_REFRESH_TOKEN
	$(error GKE_REFRESH_TOKEN is undefined)
endif

ifndef GKE_TYPE
	$(error GKE_TYPE is undefined)
endif

ifndef GKE_PROJECT_ID
	$(eval GKE_PROJECT_ID += $(GCLOUD_PROJECT_ID))
endif

.check-env-pipeline:

ifndef PIPELINE_IMAGE_TAG
	$(error PIPELINE_IMAGE_TAG is undefined)
endif

ifndef PROM_ING_PASS
	$(error PROM_ING_PASS is undefined)
endif

ifndef GRAFANA_PASS
	$(error GRAFANA_PASS is undefined)
endif

ifndef GITHUB_ORGS
	$(error GITHUB_ORGS is undefined)
endif

ifndef GITHUB_CLIENT
	$(error GITHUB_CLIENT is undefined)
endif

ifndef GITHUB_SECRET
	$(error GITHUB_SECRET is undefined)
endif

validate-aws-cf:
	aws cloudformation validate-template --template-body file://control-plane-cf.template

validate-azure-arm:
	az group deployment validate --resource-group $(AZURE_RESOURCEGROUP) --template-file control-plane-arm.json --parameters $(.ARM_PARAMS)

dev-generate-user-data-for-arm:
	./scripts/generate_arm_user_data.sh