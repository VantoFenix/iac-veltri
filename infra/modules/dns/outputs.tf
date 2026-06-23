output "nameservers" {
  value       = aws_route53_zone.main.name_servers
  description = "Nameservers de la zona DNS. Deben configurarse en el registrador del dominio."
}

output "zone_id" {
  value       = aws_route53_zone.main.zone_id
  description = "ID de la zona Route 53."
}
