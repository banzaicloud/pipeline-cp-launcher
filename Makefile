STACK_NAME ?=pipeline-controlplane-$(USER)
INSTANCE_NAME ?=$(STACK_NAME)

SLACK_URL ?=""
SLACK_CHANNEL ?=""
SMTP_SERVER_ADDRESS ?=""
SMTP_USERNAME ?=""
SMTP_PASSWORD ?=""
SMTP_TO ?=""
SMTP_FROM ?=""


.DEFAULT_GOAL := list
.PHONY: list

.PHONY: _no-target-specified
_no-target-specified:
	$(error Please specify the target to make - `make list` shows targets.)

.PHONY: list
list:
	@$(MAKE) -pRrn : -f $(MAKEFILE_LIST) 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | sort

create: .check-env
	aws cloudformation create-stack \
		--template-body file://control-plane.template \
		--stack-name $(STACK_NAME) \
		--parameters \
		ParameterKey=InstanceName,ParameterValue=$(INSTANCE_NAME) \
		ParameterKey=AccessKeyID,ParameterValue=$(AWS_ACCESS_KEY_ID) \
		ParameterKey=SecretAccessKey,ParameterValue=$(AWS_SECRET_ACCESS_KEY) \
		ParameterKey=ImageId,ParameterValue=$(IMAGE_ID) \
		ParameterKey=KeyName,ParameterValue=$(KEY_NAME) \
		ParameterKey=SlackWebhookUrl,ParameterValue=$(SLACK_URL) \
		ParameterKey=SlackChannel,ParameterValue=$(SLACK_CHANNEL) \
		ParameterKey=SmtpServerAddress,ParameterValue=$(SMTP_SERVER_ADDRESS) \
		ParameterKey=SmtpUser,ParameterValue=$(SMTP_USERNAME) \
		ParameterKey=SmtpPassword,ParameterValue=$(SMTP_PASSWORD) \
		ParameterKey=SmtpTo,ParameterValue=$(SMTP_TO) \
		ParameterKey=SmtpFrom,ParameterValue=$(SMTP_FROM) \
		ParameterKey=TraefikPass,ParameterValue=$(TRAEFIK_PASS) \
		ParameterKey=PipelineIngPass,ParameterValue=$(PIPELINE_ING_PASS) \
		ParameterKey=PromIngPass,ParameterValue=$(PROM_ING_PASS)

terminate: .check-env
	aws cloudformation delete-stack \
		--stack-name $(STACK_NAME)

.check-env:
 	ifndef AWS_ACCESS_KEY_ID
 		$(error AWS_ACCESS_KEY_ID is undefined)
 	endif
 	ifndef AWS_SECRET_ACCESS_KEY
 		$(error AWS_SECRET_ACCESS_KEY is undefined)
 	endif
 	ifndef IMAGE_ID
 		$(error IMAGE_ID is undefined)
 	endif
 	ifndef KEY_NAME
 		$(error KEY_NAME is undefined)
 	endif
 	ifndef TRAEFIK_PASS
 		$(error TRAEFIK_PASS is undefined)
 	endif
 	ifndef PIPELINE_ING_PASS
 		$(error PIPELINE_ING_PASS is undefined)
 	endif
 	ifndef PROM_ING_PASS
 		$(error PROM_ING_PASS is undefined)
 	endif

validate:
	aws cloudformation validate-template --template-body file://control-plane.template
