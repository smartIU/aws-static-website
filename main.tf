### Defines the infrastructure for hosting a static website using S3 buckets and a CloudFront distribution

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "website-name" {
  type = string
  description = "name of website / S3 buckets"
}

variable "enable-replication" {
  type = bool
  default = false
  description = "enable replication between S3 buckets - Note that this might incur costs, and contents inside 'website/content' will not be managed by terraform"
}

variable "enable-cloudfront-logging" {
  type = bool
  default = true
  description = "enable standard logging of the CloudFront distribution - Note that this will create a separate S3 bucket"
}

variable "index-document" {
  type = string
  default = "index.html"
  description = "name of the index document for the website"
}


#Create primary and failover S3 buckets

#Because of a limitation in terraform (https://github.com/hashicorp/terraform/issues/24476) providers cannot be defined dynamically
#therefore the websites cannot be created with a for_each, and if you want another failover bucket you have to duplicate the code below

variable "primary-region" {
  type = string
  description = "region for primary S3 bucket"
}

variable "failover-region" {
  type = string
  description = "region for failover S3 bucket"
}


provider "aws" {
  alias = "primary"
  region = var.primary-region
}

provider "aws" {
  alias = "failover"
  region = var.failover-region
}


module "primary-website" {
  source = "./website"

  providers = { aws = aws.primary }

  name = var.website-name
  enable-versioning = var.enable-replication
  upload-content = var.enable-replication ? false : true
}

module "failover-website" {
  source = "./website"

  providers = { aws = aws.failover }

  name = "${var.website-name}-failover"
  enable-versioning = var.enable-replication
  upload-content = var.enable-replication ? false : true
}


# Enable replication

module "replication" {
  source = "./replication"

  count = var.enable-replication ? 1 : 0
  depends_on = [module.primary-website.versioning, module.failover-website.versioning] #add additional failover versioning here
}
  providers = { aws = aws.primary }
  
  source-bucket = module.primary-website.bucket
  destination-buckets = [module.failover-website.bucket] #add additional failover buckets here
}


# Configure CloudFront distribution

provider "aws" {
  alias  = "cloudfront"
  region = "us-east-1" #default CloudFront region independent of website regions - Do not change if you want to enable logging
}

module "cloudfront" {
  source = "./cloudfront"

  providers = { aws = aws.cloudfront }
  
  origins = [module.primary-website.bucket.bucket_regional_domain_name
           , module.failover-website.bucket.bucket_regional_domain_name] #add additional failover bucket endpoints here

  enable-logging = var.enable-cloudfront-logging
  index-document = var.index-document
}


#Outputs
output "URL" {
  value = "https://${module.cloudfront.distribution.domain_name}"
}