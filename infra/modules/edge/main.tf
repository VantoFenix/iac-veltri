# ---------------------------------------------------------
# AWS WAFv2 Web ACL (Scope CLOUDFRONT)
# ---------------------------------------------------------
resource "aws_wafv2_web_acl" "edge_waf" {
  name        = "${var.proyecto}-${var.ambiente}-waf"
  description = "WAF para la capa de borde (CloudFront)"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${var.proyecto}-${var.ambiente}-waf"
    sampled_requests_enabled   = false
  }
}

# ---------------------------------------------------------
# S3 Bucket Dummy Origin (para CloudFront)
# ---------------------------------------------------------
resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "edge_origin" {
  bucket = "${var.proyecto}-${var.ambiente}-cf-origin-${random_id.bucket_id.hex}"
}

locals {
  s3_origin_id = "S3Origin-${aws_s3_bucket.edge_origin.id}"
}

# ---------------------------------------------------------
# CloudFront Distribution
# ---------------------------------------------------------
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.edge_origin.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  web_acl_id = aws_wafv2_web_acl.edge_waf.arn

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# ---------------------------------------------------------
# SQS Queue (Procesamiento asíncrono)
# ---------------------------------------------------------
resource "aws_sqs_queue" "async_queue" {
  name = "${var.proyecto}-${var.ambiente}-async-queue"
}

# ---------------------------------------------------------
# Lambda Function (Procesamiento en borde / backend asíncrono)
# ---------------------------------------------------------
data "archive_file" "dummy_lambda" {
  type        = "zip"
  output_path = "${path.module}/dummy_lambda.zip"
  source {
    content  = "def lambda_handler(event, context):\n    return {'statusCode': 200, 'body': 'Hola desde la Capa Edge'}"
    filename = "index.py"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.proyecto}-${var.ambiente}-edge-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_lambda_function" "edge_processor" {
  filename         = data.archive_file.dummy_lambda.output_path
  function_name    = "${var.proyecto}-${var.ambiente}-edge-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.dummy_lambda.output_base64sha256
}
