output "cloudfront_url" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "URL de la distribucion CloudFront"
}

output "sqs_queue_url" {
  value       = aws_sqs_queue.async_queue.url
  description = "URL de la cola SQS"
}

output "sqs_queue_arn" {
  value       = aws_sqs_queue.async_queue.arn
  description = "ARN de la cola SQS"
}

output "lambda_function_arn" {
  value       = aws_lambda_function.edge_processor.arn
  description = "ARN de la funcion Lambda"
}

output "waf_web_acl_id" {
  value       = aws_wafv2_web_acl.edge_waf.id
  description = "ID de la Web ACL del WAF"
}
