### Configures replication according to https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration
### IMPORTANT! replication across regions might result in costs

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"      
    }
  }
}

variable "source-bucket" {
  type = any
  description = "primary S3 bucket"
}

variable "destination-buckets" {
  type = list(any)
  description = "failover S3 buckets"
}


# Define replication policy and attach to role

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "replication" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [var.source-bucket.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${var.source-bucket.arn}/*"]
  }

  dynamic "statement" {
    for_each = var.destination-buckets
    content {
      effect = "Allow"

      actions = [
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags",
      ]

      resources = ["${statement.value.arn}/*"]
    }
  }
}

resource "aws_iam_role" "replication" {
  name = "role-${var.source-bucket.bucket}-replication"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_policy" "replication" {
  name = "policy-${var.source-bucket.bucket}-replication"
  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_iam_role_policy_attachment" "replication" {
  role = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}


# Define replication rules (one for each destination bucket)

resource "aws_s3_bucket_replication_configuration" "replication" {  
  role   = aws_iam_role.replication.arn
  bucket = var.source-bucket.id

  dynamic "rule" {
    for_each = var.destination-buckets
    content {
      id = "${rule.value.bucket}-replication"
      status = "Enabled"
      destination {
        bucket = rule.value.arn
      }
    }
  }
}