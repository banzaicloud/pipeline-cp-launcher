# Pipeline control plane launcher on AWS

This is an AWS Cloudformation template in order to provision a Pipeline control plane.

The control plane image (AMI) is currently published to one region, `eu-west-1` aka Ireland. When launching the control plane please pass the following *ImageId* `ami-c070c0b9`.

The template is accessible from the [following](https://s3-eu-west-1.amazonaws.com/cf-templates-grr4ysncvcdl-eu-west-1/2018026em9-new.templatee93ate9mob7) location.

In case of using the `Makefile` use the `.env.example` as a start.

# Pipeline control plane launcher on Azure

Please see [how to luanch pipeline control plane on Azure](https://github.com/banzaicloud/pipeline/blob/0.2.0/docs/pipeline-howto.md#launch-pipeline-control-plane-on-azure) for details.
