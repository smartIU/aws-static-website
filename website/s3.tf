### Creates S3 bucket for hosting of static website

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "name" {
  type = string
  description = "name of the S3 bucket"
}

variable "enable-versioning" {
  type = bool
  description = "enable versioning for the S3 bucket"
}

variable "upload-content" {
  type = bool
  description = "upload content from 'content' folder to S3 bucket"
}


#Bucket
resource "aws_s3_bucket" "website" {
  bucket = var.name

  force_destroy = true
  tags = {
    Name = var.name
    Purpose = "static website"
  }
}


# Allow the creation of access policies and create one for CloudFront

resource "aws_s3_bucket_public_access_block" "access" {
  bucket = aws_s3_bucket.website.id
  block_public_policy = false
  block_public_acls = true
}

data "aws_iam_policy_document" "cloudfront" {
  statement {
    sid = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.website.arn}/*"]   
  }
}
  
resource "aws_s3_bucket_policy" "website-cloudfront-policy" {  
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.cloudfront.json
}


# Versioning - needed for replication
resource "aws_s3_bucket_versioning" "website-versioning" {
  count = var.enable-versioning ? 1 : 0

  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# automatically cleanup old versions
resource "aws_s3_bucket_lifecycle_configuration" "website-cleanup" {
  count = var.enable-versioning ? 1 : 0
  depends_on = [aws_s3_bucket_versioning.website-versioning]

  bucket = aws_s3_bucket.website.id

  rule {
    id = "cleanup"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}


# Upload static files with a module by https://registry.terraform.io/modules/apparentlymart/dir/template/latest
module "content" {
  source  = "apparentlymart/dir/template"
  
  count = var.upload-content ? 1 : 0
  
  base_dir = "${path.module}/content"
}

resource "aws_s3_object" "static_files" {
  for_each = var.upload-content ? module.content[0].files : {}

  bucket = aws_s3_bucket.website.id
  key = each.key
  content_type = each.value.content_type
  source  = each.value.source_path

  #needed for terraform to see updates to the source files
  etag = each.value.digests.md5
}


# Outputs
output "bucket" {
    value = aws_s3_bucket.website
}

output "versioning" {
    value = aws_s3_bucket_versioning.website-versioning
}