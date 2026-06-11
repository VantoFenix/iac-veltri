variable "aws_region" {
  description = "Region principal de despliegue en AWS"
  type        = string
  default     = "eu-east-1"
}

variable "proyecto" {
  description = "Nombre raiz del proyecto para etiquetado"
  type        = string
  default     = "veltri"
}

variable "ambiente" {
  description = "Entorno de ejecucion (develop, staging, main)"
  type        = string
  default     = "dev" 
}