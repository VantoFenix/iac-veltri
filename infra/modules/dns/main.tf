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