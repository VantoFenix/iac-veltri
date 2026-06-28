# AÑADIDO PARA CKV2_AWS_64: data source para obtener el account ID de forma dinámica
data "aws_caller_identity" "current" {}

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-dns-zone"
    Modulo     = "dns"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

resource "aws_route53_record" "cdn" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cdn_domain_name
    zone_id                = var.cdn_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alb" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# AÑADIDO PARA CKV2_AWS_64: KMS key para DNSSEC con policy explícita
# La policy permite:
#   - Al root account administrar la llave (obligatorio en toda KMS key policy)
#   - Al servicio dnssec-route53.amazonaws.com usarla para firmar zonas DNS
resource "aws_kms_key" "dnssec" {
  description              = "KMS key para DNSSEC de Route53 - Veltri Minimarket"
  deletion_window_in_days  = 7
  enable_key_rotation      = false
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Permite al root account administrar completamente la llave (requerido)
        Sid    = "AllowRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        # Permite al servicio Route53 DNSSEC usar la llave para firmar
        Sid    = "AllowRoute53DNSSECService"
        Effect = "Allow"
        Principal = {
          Service = "dnssec-route53.amazonaws.com"
        }
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-kms-dnssec"
    Modulo     = "dns"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

resource "aws_route53_key_signing_key" "main" {
  hosted_zone_id             = aws_route53_zone.main.zone_id
  name                       = "${var.proyecto}-${var.ambiente}-ksk"
  key_management_service_arn = aws_kms_key.dnssec.arn
  status                     = "ACTIVE"
}

resource "aws_route53_hosted_zone_dnssec" "main" {
  hosted_zone_id = aws_route53_zone.main.zone_id
  depends_on     = [aws_route53_key_signing_key.main]
}

# -----------------------------------------------------------
# Route 53 Query Logging (Solución para CKV2_AWS_39, 158 y 338)
# -----------------------------------------------------------

# 1. KMS Key para encriptar los logs (Fix CKV_AWS_158)
resource "aws_kms_key" "r53_logs_kms_key" {
  description             = "KMS para encriptar CloudWatch Logs de Route 53"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DefaultAllow"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# 2. Grupo de logs en CloudWatch (Actualizado)
resource "aws_cloudwatch_log_group" "route53_query_logs" {
  name              = "/aws/route53/${var.domain_name}"
  retention_in_days = 365 # Fix CKV_AWS_338: Retención de al menos 1 año

  kms_key_id = aws_kms_key.r53_logs_kms_key.arn # Fix CKV_AWS_158: Encriptación con KMS

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-r53-logs"
    Modulo     = "dns"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

# 3. Política de recursos para permitir a Route 53 escribir logs
data "aws_iam_policy_document" "route53_query_logging_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/route53/*"]
    principals {
      identifiers = ["route53.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "route53_query_logging_policy" {
  policy_document = data.aws_iam_policy_document.route53_query_logging_policy.json
  policy_name     = "${var.proyecto}-${var.ambiente}-route53-query-logging-policy"
}

# 4. Activación de los logs en la zona DNS
resource "aws_route53_query_log" "main" {
  depends_on = [aws_cloudwatch_log_resource_policy.route53_query_logging_policy]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_query_logs.arn
  zone_id                  = aws_route53_zone.main.zone_id
}