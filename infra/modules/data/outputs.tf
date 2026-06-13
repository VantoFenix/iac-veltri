output "aurora_cluster_endpoint" {
  description = "Endpoint de escritura principal de Aurora"
  value       = aws_rds_cluster.aurora_cluster.endpoint
}

output "aurora_reader_endpoint" {
  description = "Endpoint de lectura del clúster de Aurora"
  value       = aws_rds_cluster.aurora_cluster.reader_endpoint
}

output "redis_endpoint" {
  description = "Endpoint de conexión primaria a Redis"
  value       = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address
}

output "db_secrets_arn" {
  description = "ARN del Secreto seguro con las credenciales maestras"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "data_security_group_id" {
  description = "ID del Security Group de datos"
  value       = aws_security_group.data_sg.id
}