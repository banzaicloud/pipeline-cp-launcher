STACK_NAME ?=pipeline-controlplane-$(USER)
INSTANCE_NAME ?=$(STACK_NAME)

SLACK_URL ?=""
SLACK_CHANNEL ?=""
SMTP_SERVER_ADDRESS ?=""
SMTP_USERNAME ?=""
SMTP_PASSWORD ?=""
SMTP_TO ?=""
SMTP_FROM ?=""

AZURE_RESOURCEGROUP ?=$(USER)_$(AZURE_LOCATION)

.DEFAULT_GOAL := list
.PHONY: list

.PHONY: _no-target-specified
_no-target-specified:
	$(error Please specify the target to make - `make list` shows targets.)

.PHONY: list
list:
	@$(MAKE) -pRrn : -f $(MAKEFILE_LIST) 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort

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
		ParameterKey=OAuthEnabled,ParameterValue=$(PIPELINE_OAUTH_ENABLED) \
		ParameterKey=PipelineIngPass,ParameterValue=$(PIPELINE_ING_PASS) \
		ParameterKey=PromIngPass,ParameterValue=$(PROM_ING_PASS) \
		ParameterKey=GithubOrgs,ParameterValue=$(GITHUB_ORGS) \
		ParameterKey=GithubClient,ParameterValue=$(GITHUB_CLIENT) \
		ParameterKey=GithubSecret,ParameterValue=$(GITHUB_SECRET) \
		ParameterKey=PipelineImageTag,ParameterValue=$(PIPELINE_IMAGE_TAG) \
		ParameterKey=AzureClientId,ParameterValue=$(AZURE_CLIENT_ID) \
		ParameterKey=AzureClientSecret,ParameterValue=$(AZURE_CLIENT_SECRET) \
		ParameterKey=AzureSubscriptionId,ParameterValue=$(AZURE_SUBSCRIPTION_ID) \
		ParameterKey=AzureTenantId,ParameterValue=$(AZURE_TENANT_ID) \
		ParameterKey=HelmRetryAttempt,ParameterValue=$(PIPELINE_HELM_RETRYATTEMPT) \
		ParameterKey=HelmRetrySleepSeconds,ParameterValue=$(PIPELINE_HELM_RETRYSLEEPSECONDS) \

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
			oauthEnabled=$(PIPELINE_OAUTH_ENABLED) \
			pipelineIngPass=$(PIPELINE_ING_PASS) \
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
			pipelineHelmRetrysleepseconds=$(PIPELINE_HELM_RETRYSLEEPSECONDS)

create-azure: .check-env-azure
	az group create --name $(AZURE_RESOURCEGROUP) --location $(AZURE_LOCATION)
	
	az group deployment create \
    	--name $(STACK_NAME) \
    	--resource-group $(AZURE_RESOURCEGROUP) \
    	--template-file control-plane-arm.json \
    	--parameters $(.ARM_PARAMS)


terminate-azure:
	az group delete --name $(AZURE_RESOURCEGROUP)

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


.check-env-pipeline:

ifndef PIPELINE_IMAGE_TAG
	$(error PIPELINE_IMAGE_TAG is undefined)
endif

ifndef PIPELINE_ING_PASS
	$(error PIPELINE_ING_PASS is undefined)
endif

ifndef PROM_ING_PASS
	$(error PROM_ING_PASS is undefined)
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