# Pipeline control plane launcher

This is an AWS Cloudformation template in order to provision a Pipeline control plane.

The control plane image (AMI) is currently published to one region, `eu-west-1` aka Ireland. When launching the control plane please pass the following *ImageId* `ami-c070c0b9`.

The template is accessible from the [following](https://s3-eu-west-1.amazonaws.com/cf-templates-grr4ysncvcdl-eu-west-1/2017338aEC-new.template6z1wxm2h6cb) location.

In case of using the `Makefile` use the `.env.example` as a start.
