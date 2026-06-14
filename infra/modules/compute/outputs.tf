# =============================================================================
# OUTPUTS: Módulo Compute
# =============================================================================
#
# Valores que este modulo expone hacia infra/main.tf y hacia los demas
# modulos (data, edge) segun el manual de integracion.
# =============================================================================

# -----------------------------------------------------------------------------
# OBLIGATORIOS segun el manual de integracion
# -----------------------------------------------------------------------------

# Requerido por Josue (modulo data) para las reglas de entrada de
# Aurora (3306) y ElastiCache (6379): solo el SG de las EC2 puede conectarse.
output "security_group_compute_id" {
  description = "ID del Security Group de las instancias EC2. Josue lo usa para autorizar el acceso a Aurora/ElastiCache."
  value       = aws_security_group.ec2.id
}

# URL publica de salida del sistema (para el manifiesto info.md)
output "alb_dns_name" {
  description = "DNS publico del Application Load Balancer. Punto de entrada del flujo dinamico."
  value       = aws_lb.main.dns_name
}

# -----------------------------------------------------------------------------
# ADICIONALES — utiles para el pipeline CI/CD de Tiago y para info.md
# -----------------------------------------------------------------------------

output "ecr_repository_url" {
  description = "URL del repositorio ECR. Tiago lo usa en el pipeline docker-build-push.yml."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN del repositorio ECR."
  value       = aws_ecr_repository.app.arn
}

output "asg_name" {
  description = "Nombre del Auto Scaling Group. Util para el pipeline de despliegue (instance refresh)."
  value       = aws_autoscaling_group.app.name
}

output "target_group_arn" {
  description = "ARN del Target Group del ALB."
  value       = aws_lb_target_group.app.arn
}

output "launch_template_id" {
  description = "ID del Launch Template de las instancias EC2."
  value       = aws_launch_template.app.id
}

output "security_group_alb_id" {
  description = "ID del Security Group del ALB."
  value       = aws_security_group.alb.id
}

output "ec2_iam_role_arn" {
  description = "ARN del rol IAM de las instancias EC2 (principio de menor privilegio)."
  value       = aws_iam_role.ec2.arn
}
