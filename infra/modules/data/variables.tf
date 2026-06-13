variable "proyecto" {
  description = "Nombre del proyecto global"
  type        = string
}

variable "ambiente" {
  description = "Ambiente de despliegue (ej. dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC Core"
  type        = string
}

variable "private_subnets_data" {
  description = "Lista de IDs de las subredes privadas 5 y 6"
  type        = list(string)
}

variable "security_group_compute_id" {
  description = "ID del Security Group de la capa de cómputo (EC2)"
  type        = string
}

variable "db_engine" {
  description = "Motor de base de datos para Aurora"
  type        = string
  default     = "aurora-mysql"
}

variable "db_engine_version" {
  description = "Versión del motor de base de datos"
  type        = string
  default     = "8.0.mysql_aurora.3.04.1"
}

variable "db_instance_class" {
  description = "Clase de instancia para Aurora"
  type        = string
  default     = "db.t3.medium"
}

variable "redis_node_type" {
  description = "Tipo de nodo para ElastiCache Redis"
  type        = string
  default     = "cache.t3.micro"
}