# =============================================================================
# VARIABLES: Módulo Compute
# =============================================================================
#
# Las primeras 5 variables (proyecto, ambiente, aws_region, vpc_id,
# public_subnets, private_subnets_compute) son inyectadas por el
# orquestador infra/main.tf desde infra/variables.tf y desde los
# outputs del modulo network de Bruno.
#
# Las demas variables tienen defaults para no quemar valores en main.tf
# (cero hardcoding) pero pueden sobreescribirse desde infra/main.tf.
# =============================================================================

# -----------------------------------------------------------------------------
# Variables globales (vienen de infra/variables.tf)
# -----------------------------------------------------------------------------

variable "proyecto" {
  description = "Nombre raiz del proyecto para etiquetado. Viene de infra/variables.tf"
  type        = string
}

variable "ambiente" {
  description = "Entorno de ejecucion (dev/staging/main). Viene de infra/variables.tf"
  type        = string
}

variable "aws_region" {
  description = "Region de despliegue en AWS."
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Variables del nucleo de red (vienen de module.network)
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID de la VPC principal. Viene de module.network.vpc_id"
  type        = string
}

variable "public_subnets" {
  description = "IDs de las subredes publicas 1 y 2. Viene de module.network.public_subnets. Aqui vive el ALB publico."
  type        = list(string)
}

variable "private_subnets_compute" {
  description = "IDs de las subredes privadas 3 y 4. Viene de module.network.private_subnets_compute. Aqui vive el Auto Scaling Group."
  type        = list(string)
}

# -----------------------------------------------------------------------------
# Configuracion de la aplicacion
# -----------------------------------------------------------------------------

variable "app_port" {
  description = "Puerto donde escucha la aplicacion (Django/Gunicorn) dentro de la EC2."
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "Ruta usada por el Target Group para verificar la salud de las instancias cada 30 segundos."
  type        = string
  default     = "/health"
}

# -----------------------------------------------------------------------------
# Secrets Manager — nombre del secreto gestionado por el modulo data (Josue)
# -----------------------------------------------------------------------------

variable "db_secret_name_suffix" {
  description = "Sufijo del nombre del secreto de credenciales de BD creado por el modulo data. El nombre final sera [proyecto]-[ambiente]-[sufijo]."
  type        = string
  default     = "db-creds-v2"
}
# -----------------------------------------------------------------------------
# Configuracion de instancias EC2
# -----------------------------------------------------------------------------

variable "ami_id" {
  description = "ID de la Golden AMI generada por Packer. Si se deja vacio, usa Amazon Linux 2023 base automaticamente."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Tipo de instancia EC2 para el Auto Scaling Group."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Tamaño en GB del disco raiz de cada instancia EC2."
  type        = number
  default     = 20
}

# -----------------------------------------------------------------------------
# Configuracion del Auto Scaling Group
# -----------------------------------------------------------------------------

variable "asg_min_size" {
  description = "Numero minimo de instancias siempre activas."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Numero maximo de instancias permitidas al escalar."
  type        = number
  default     = 6
}

variable "asg_desired_capacity" {
  description = "Numero deseado de instancias al desplegar."
  type        = number
  default     = 2
}

variable "scale_out_cpu_threshold" {
  description = "Porcentaje de CPU promedio que dispara el aprovisionamiento de nuevas instancias."
  type        = number
  default     = 75
}

variable "scale_in_cpu_threshold" {
  description = "Porcentaje de CPU promedio por debajo del cual se retiran instancias (evaluado durante 15 minutos)."
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# Otras configuraciones
# -----------------------------------------------------------------------------

variable "ecr_max_image_count" {
  description = "Cantidad maxima de imagenes con tag de version a conservar en ECR."
  type        = number
  default     = 10
}

variable "enable_deletion_protection" {
  description = "Si es true, evita que el ALB se elimine accidentalmente. Usar true en main/produccion."
  type        = bool
  default     = false
}

variable "waf_arn" {
  description = "ARN del WAF creado en el modulo edge para proteger el ALB publico."
  type        = string
}
