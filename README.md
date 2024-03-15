# Static Website Hosting Project for AWS S3 and CloudFront

Complete Terraform project to deploy an AWS cloud infrastructure for hosting a static website


**Documentation is work in progress and will be finished after receiving feedback for phase 2**


## Components

- 2-3 S3 buckets for storage, failover and logging
- CloudFront distribution for low latency public access
- Optionally manages website content or configures replication between S3 buckets


## Requirements

- Create AWS account
  - Install and configure AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
  
- Install Terraform: https://developer.hashicorp.com/terraform/install


## Usage

First set variables in "terraform.tfvars".

Then run

```commandline
terraform init
```

followed by

```commandline
terraform apply
```

and confirm the plan with

```commandline
yes
```


### Disclaimer

**No** part of the app or its documentation was created by or with the help of artificial intelligence.
