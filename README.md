# Static Website Hosting Project for AWS S3 and CloudFront

A complete Terraform project to deploy an AWS cloud infrastructure for hosting a static website.


## Components

- 2-3 S3 buckets for storage, failover and logging
- CloudFront distribution for low latency public access
- Optionally manages website content or configures replication between S3 buckets


## Setup

- Create an AWS account: 
  https://aws.amazon.com
- Install and configure the AWS CLI:
  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html 
- Install Terraform: 
  https://developer.hashicorp.com/terraform/install

## Variables

- bucket-name:  name of the website S3 buckets
   Note that this has to be globally unique (i.e., for any S3 bucket of any user worldwide)
   
- primary-region: region for primary S3 bucket
   This should be close to where you expect the majority of website visitors to come from
   
- failover-region: region for failover S3 bucket
   This should not be too close to your primary region
   
- enable-replication: enable replication between S3 buckets
   Note that this creates a lot of S3 requests and might thereby incur additional costs
   
- enable-cloudfront-logging: enable standard logging of the CloudFront distribution
   This will create an additional S3 bucket in the US East (N. Virginia) region to put the logs
   
- index-document: name of the index document for the website
  
   
## Usage

Download the release or clone the GitHub repository.

Decide how you want to manage the website content:
- You can set "enable-replication" to "false" and delete the content of the "website/content" folder, to manage both the primary and failover bucket by yourself.
- You can set "enable-replication" to "false" and put your website content into the "website/content" folder, to have Terraform upload it to the buckets. Whenever you want to update the content, just run the project again.
- Or you can set "enable-replication" to "true", which will make Terraform ignore the "website/content" folder, but you will only have to manage the primary bucket.

Set the variables according to your specific needs in terraform.tfvars.

Then navigate to the root folder of the project and run

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

## Result

If there is no problem during the deployment, Terraform should output the URL to your newly published website in the end, similar to:
```
Outputs:

URL = "https://2m65749kf915.cloudfront.net"
```
Note that the website will be configured to allow https requests only.

If the website cannot be browsed immediately, simply try again after a while, as the CloudFront distribution can take up to 15 minutes to be operational.


## Common problems

Not all regions are activated by default for a new AWS account.

If only your failover bucket gets created and the primary bucket deployment runs into an error, you have most likely chosen a value for "bucket-name" that someone else has already taken. You should come up with a more unique name in this case.

## Additional failover buckets

If you want to employ more than one failover bucket, you have to duplicate the "failover-region" variable, "failover" provider as well as the "failover-website" module in main.tf, e.g.
```
variable "failover-region-2" {
  type = string
  description = "region for failover S3 bucket 2"
}
provider "aws" {
  alias = "failover-2"
  region = var.failover-region-2
}
module "failover-website-2" {
  source = "./website"

  providers = { aws = aws.failover-2 }

  name = "${var.bucket-name}-failover-2"
  enable-versioning = var.enable-replication
  upload-content = var.enable-replication ? false : true
}
```
and then amend the three commented lines further down, e.g.
```
depends_on = [module.primary-website.versioning, module.failover-website.versioning, module.failover-website-2.versioning] #add additional failover versioning here
...
destination-buckets = [module.failover-website.bucket, module.failover-website-2.bucket] #add additional failover buckets here
...
origins = [module.primary-website.bucket.bucket_regional_domain_name, module.failover-website.bucket.bucket_regional_domain_name, module.failover-website-2.bucket.bucket_regional_domain_name] #add additional failover bucket endpoints here
```

No changes in the modules have to be made.

### Disclaimer

**No** part of the app or its documentation was created by or with the help of artificial intelligence.
