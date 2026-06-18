output "estado_core" {
  value       = "Infraestructura base de Veltri inicializada correctamente"
  description = "Mensaje de confirmacion de despliegue exitoso"
}

output "edge_cloudfront_url" {
  value       = module.edge.cloudfront_url
  description = "URL de la distribucion CloudFront"
}

output "edge_sqs_queue_url" {
  value       = module.edge.sqs_queue_url
  description = "URL de la cola SQS"
}

output "edge_sqs_queue_arn" {
  value       = module.edge.sqs_queue_arn
  description = "ARN de la cola SQS"
}

output "edge_lambda_function_arn" {
  value       = module.edge.lambda_function_arn
  description = "ARN de la funcion Lambda en la capa Edge"
}

output "edge_waf_web_acl_id" {
  value       = module.edge.waf_web_acl_id
  description = "ID del Web ACL de WAF"
}