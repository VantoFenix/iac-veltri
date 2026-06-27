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