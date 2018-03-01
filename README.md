# Pipeline control plane launcher on AWS

On AWS we use a Cloudformation template in order to provision a Pipeline control plane.

The control plane image (AMI) is currently published to one region, `eu-west-1` aka Ireland. When launching the control plane please pass the following *ImageId* `ami-c070c0b9`.

* For creating the control plane launcher through command line take a look at `.env.example` as a start to learn what environment variables are required by the `Makefile`.
* For creating the control plane launcher using Amazon Web Console please [follow](https://github.com/banzaicloud/pipeline/blob/master/docs/pipeline-howto.md#launch-pipeline-control-plane-on-aws) for details.

# Pipeline control plane launcher on Azure

On Azure we use an ARM template in order to provision a Pipeline control plane.

* For creating the control plane launcher through command line take a look at `.env.example` as a start to learn what environment variables are required by the `Makefile`. **Note**: Make sure to log in to Azure prior using the command line with `az login` !
* For further details please see [how to launch Pipeline control plane on Azure](https://github.com/banzaicloud/pipeline/blob/master/docs/pipeline-howto.md#launch-pipeline-control-plane-on-azure).
