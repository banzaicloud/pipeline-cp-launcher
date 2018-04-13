# Hosting Pipeline Control Plane on Minikube

Follow the steps below for hosting `Pipeline Control Plane` on `Minikube`.
On `Minikube` we use a your local machine in order to provision a Pipeline control plane.

## Pre-requisites

1. [Minikube](https://github.com/kubernetes/minikube/releases) installation
    - [Hyperkit](https://github.com/kubernetes/minikube/blob/master/docs/drivers.md#hyperkit-driver) installation on OSX
2. [Helm](https://github.com/kubernetes/helm/blob/master/docs/install.md) installation

## Command line

For creating the control plane launcher through command line take a look at `.env.example` as a start to learn what environment variables are required by the `Makefile`. _Note_ the makefile uses `minikube` and `helm` which needs to be installed first if not available on the machine.

* deploy - `make create-minikube`
* delete - `make terminate-minikube`

## Deployment end points

Check the output section of of the make command for the endpoints where the deployed services can be reached:

* GitHub Authorization callback URL - The URL that you should paste into the GitHub OAuth application setup page.
* Pipeline login - the endpoint for the Pipelne login page
* Grafana - the endpoint for Grafana
* PrometheusServer - the endpoint for [federated](https://banzaicloud.com/blog/prometheus-federation/) Prometheus server.
