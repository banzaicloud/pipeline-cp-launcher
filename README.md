# Deprecation Notice:

> This repository is now outdated please use follow the [documentation here](https://banzaicloud.com/docs/pipeline/quickstart/install-pipeline/) to install Pipeline with the [Banzai CLI](https://github.com/banzaicloud/banzai-cli).
 
## Pipeline Control Plane launcher

Pipeline control plane launcher is responsible for launching the components/services that form [Control Plane](https://github.com/banzaicloud/pipeline#control-plane) on one of the supported cloud providers.

### Pre-requisites

Before deploying `Control Plane` to any of the supported cloud providers the follwoing pre-requisites must be esured.

#### GitHub OAuth setup

`Pipeline` requires authentication through GitHub thus the appropriate OAuth application needs to be set up on GitHub.
Follow [these](https://github.com/banzaicloud/pipeline/blob/master/docs/github-app.md) instructions for details.

### Pipeline control plane launcher on AWS

For launching `Control Plane` on `AWS` check out details at [Control Plane on AWS](docs/control-plane-on-aws.md).

### Pipeline control plane launcher on Azure

For launching `Control Plane` on `Azure` check out details at see details at [Control Plane on Azure](docs/control-plane-on-azure.md).

### Pipeline control plane launcher on Google Cloud

For launching `Control Plane` on `Google Cloud` check out details at see details at [Control Plane on Google Cloud](docs/control-plane-on-gcloud.md).

### Pipeline control plane launcher on Minikube

For launching `Control Plane` on `Minikube` check out details at [Control Plane on Minikube](docs/control-plane-on-minikube.md).
