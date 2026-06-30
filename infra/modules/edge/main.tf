
# AWS WAFv2 Web ACL (Scope CLOUDFRONT)

resource "aws_wafv2_web_acl" "edge_waf" {
  name        = "${var.proyecto}-${var.ambiente}-waf"
  description = "WAF para la capa de borde CloudFront"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommon"
    priority = 1

  
    override_action {
      none {}
    }
  
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.proyecto}-${var.ambiente}-waf-common-rules"
      sampled_requests_enabled   = true
    }
  }
  
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.proyecto}-${var.ambiente}-waf-bad-inputs"
      sampled_requests_enabled   = true
    }
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
# 1. Generador de IDs únicos para los nombres de buckets
resource "random_id" "bucket_id" {
  byte_length = 4
}

# 2. Bucket de Origen
resource "aws_s3_bucket" "edge_origin" {
  bucket = "${var.proyecto}-${var.ambiente}-cf-origin-${random_id.bucket_id.hex}"
}

# 2.1 Bucket de Failover
resource "aws_s3_bucket" "edge_origin_failover" {
  bucket = "${var.proyecto}-${var.ambiente}-cf-failover-${random_id.bucket_id.hex}"
}

# 3. Encriptación KMS para el Origen (REQUERIDO POR CHECKOV)
resource "aws_s3_bucket_server_side_encryption_configuration" "edge_origin_encryption" {
  bucket = aws_s3_bucket.edge_origin.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "edge_origin_failover_encryption" {
  bucket = aws_s3_bucket.edge_origin_failover.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

# 4. Versionamiento para el Origen (REQUERIDO POR CHECKOV)
resource "aws_s3_bucket_versioning" "edge_origin_versioning" {
  bucket = aws_s3_bucket.edge_origin.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "edge_origin_failover_versioning" {
  bucket = aws_s3_bucket.edge_origin_failover.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 5. Bucket de Logs
resource "aws_s3_bucket" "cf_logs" {
  bucket = "${var.proyecto}-${var.ambiente}-cf-logs-${random_id.bucket_id.hex}"
}

# 6. Encriptación KMS para Logs (REQUERIDO POR CHECKOV)
resource "aws_s3_bucket_server_side_encryption_configuration" "cf_logs_encryption" {
  bucket = aws_s3_bucket.cf_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

# 7. Versionamiento para Logs (REQUERIDO POR CHECKOV)
resource "aws_s3_bucket_versioning" "cf_logs_versioning" {
  bucket = aws_s3_bucket.cf_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 8. Local para identificar el origen en CloudFront
locals {
  s3_origin_id          = "S3Origin-${aws_s3_bucket.edge_origin.id}"
  s3_failover_origin_id = "S3OriginFailover-${aws_s3_bucket.edge_origin_failover.id}"
}

# CloudFront Distribution

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.proyecto}-${var.ambiente}-oac"
  description                       = "Acceso seguro desde CloudFront hacia S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# TU DISTRIBUCIÓN ACTUALIZADA

resource "aws_cloudfront_distribution" "cdn" {
  # checkov:skip=CKV_AWS_174: Se usa el certificado por defecto de CloudFront por no contar con un dominio personalizado para el proyecto.
  origin {
    domain_name              = aws_s3_bucket.edge_origin.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id # ✅ FIX: Aquí se enlaza la seguridad
  }

  origin {
    domain_name              = aws_s3_bucket.edge_origin_failover.bucket_regional_domain_name
    origin_id                = local.s3_failover_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  origin_group {
    origin_id = "failover-group"

    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }

    member {
      origin_id = local.s3_origin_id
    }

    member {
      origin_id = local.s3_failover_origin_id
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  web_acl_id = aws_wafv2_web_acl.edge_waf.arn

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cf_logs.bucket_domain_name
    prefix          = "cf-logs/"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "failover-group"

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
      restriction_type = "whitelist"
      locations        = ["PE"] 
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# SQS Queue (Procesamiento asíncrono)

resource "aws_sqs_queue" "async_queue_dlq" {
  name                      = "${var.proyecto}-${var.ambiente}-async-queue-dlq"
  message_retention_seconds = 1209600 # 14 dias
  
  # --- Habilitar encriptación para resolver CKV_AWS_27 ---
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "async_queue" {
  name                       = "${var.proyecto}-${var.ambiente}-async-queue"
  message_retention_seconds  = 86400 # 1 dia
  visibility_timeout_seconds = 300   # 5 minutos
  
  # --- Habilitar encriptación para resolver CKV_AWS_27 ---
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.async_queue_dlq.arn
    maxReceiveCount     = 3
  })
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

# ---------------------------------------------------------
# API Gateway (REST API con integración HTTP_PROXY hacia el ALB)
# ---------------------------------------------------------
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.proyecto}-${var.ambiente}-api"
  description = "API Gateway regional apuntando al Application Load Balancer"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "alb_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "POST"

  # Usamos HTTP en el puerto 80 ya que el ALB público escucha allí y hace forward al Target Group
  uri = "http://${var.alb_dns_name}/{proxy}"
}

resource "aws_api_gateway_deployment" "api_deploy" {
  depends_on  = [aws_api_gateway_integration.alb_proxy]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.ambiente
}

# Crear grupo de logs en CloudWatch para el WAF
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-${var.proyecto}-${var.ambiente}"
  retention_in_days = 30 # Ajusta según tu necesidad de retención
}

#  Habilitar el logging del WAF hacia el grupo de logs
resource "aws_wafv2_web_acl_logging_configuration" "edge_waf_logging" {
  resource_arn            = aws_wafv2_web_acl.edge_waf.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
}
