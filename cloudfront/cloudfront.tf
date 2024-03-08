### CloudFront configuration for origin group

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"      
    }
  }
}

variable "origins" {
  type = list(string)
  description = "list of S3 bucket endpoints"
}

locals {
  indexed_origins = {for i, origin in var.origins: "S3_${i}" => origin}
}

variable "enable-logging" {
  type = any
  default = true
  description = "creates an S3 bucket for standard logging"
}

variable "index-document" {
  type = string
  default = "index.html"
  description = "name of the index document"
}


# S3 bucket for logging

resource "aws_s3_bucket" "logs" {
  count = var.enable-logging ? 1 : 0

  bucket = "${split(".", var.origins[0])[0]}-logging"

  force_destroy = true
  tags = {
    Purpose = "CloudFront logging"
  }
}

# Allow the creation of ACLs (CloudFront will automatically create an ACL when enabling logging)
resource "aws_s3_bucket_public_access_block" "access" {
  count = var.enable-logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  block_public_policy = true
  block_public_acls = false
}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  count = var.enable-logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}


# Distribution

data "aws_cloudfront_cache_policy" "cache_policy" {
  #recommended predefined caching policy for S3
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_origin_access_control" "origin_access_control" {
  #predefined S3 access control
  name                              = "Access Control Policy for ${split(".", var.origins[0])[0]}"  
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "distribution" {

  depends_on = [aws_s3_bucket_public_access_block.access, aws_s3_bucket_ownership_controls.ownership]

  dynamic "origin" {
    for_each = local.indexed_origins
    content {
      origin_id = origin.key
      domain_name = origin.value
      origin_access_control_id = aws_cloudfront_origin_access_control.origin_access_control.id      
    }
  }
  
  origin_group {
    origin_id = "S3-group"

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }

    dynamic "member" {
      for_each = local.indexed_origins
      content {
        origin_id = member.key
      }
    }
  }

  enabled = true
  default_root_object = var.index-document

  dynamic "logging_config" {
    for_each = var.enable-logging ? [1] : []

    content {    
      include_cookies = false
      bucket = aws_s3_bucket.logs[0].bucket_regional_domain_name
      prefix = "logs/"
    }
  }

  default_cache_behavior {

    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]

    target_origin_id = "S3-group"
    cache_policy_id = data.aws_cloudfront_cache_policy.cache_policy.id

    #only allows https for the public facing CloudFront endpoint
    viewer_protocol_policy = "https-only"    
    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

   viewer_certificate {    
     #uses AWS wildcard SSL certificate for *.cloudfront.net
     cloudfront_default_certificate = true
  }
}


#Outputs
output "distribution" {
    value = aws_cloudfront_distribution.distribution
}