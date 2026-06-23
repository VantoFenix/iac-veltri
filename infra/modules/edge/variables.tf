variable "proyecto" {
  description = "Nombre raiz del proyecto para etiquetado"
  type        = string
}

variable "ambiente" {
  description = "Entorno de ejecucion (develop, staging, main)"
  type        = string
}
variable "vpc_id" {
  description = "ID de la VPC inyectada por el orquestador."
  type        = string
}

variable "private_subnets_compute" {
  description = "IDs de las subredes privadas inyectadas por el orquestador."
  type        = list(string)
}

variable "alb_dns_name" {
  description = "DNS Name del Application Load Balancer para integrarlo con el API Gateway."
  type        = string
}