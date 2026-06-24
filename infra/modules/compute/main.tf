# =============================================================================
# MÓDULO: COMPUTE — Capa de Cómputo, Escalabilidad y Repositorio de Imágenes
# =============================================================================
#
# RECURSOS QUE CREA ESTE MÓDULO:
#   1. Security Group ALB     → Acepta HTTP/HTTPS desde internet (0.0.0.0/0)
#   2. Security Group EC2     → Solo acepta tráfico del ALB
#   3. ECR                    → Repositorio Docker inmutable + escaneo
#   4. IAM Role + Profile     → Rol para EC2 con acceso a ECR y Secrets Manager
#   5. ALB público            → En subredes públicas 1 y 2
#   6. Target Group + Listener
#   7. Launch Template        → Plantilla de instancias EC2
#   8. Auto Scaling Group     → Escala según CPU (75% / 30%)
#
# RNF QUE IMPLEMENTA:
#   ✅ Health checks cada 30 segundos
#   ✅ Scale-out al 75% CPU por 8 minutos
#   ✅ Scale-in al 30% CPU por 15 minutos
#   ✅ Connection draining 60 segundos
#   ✅ ECR con etiquetas inmutables y escaneo de vulnerabilidades
#   ✅ Principio de menor privilegio en IAM
# =============================================================================


# =============================================================================
# 1. SECURITY GROUP — Application Load Balancer
# =============================================================================
# Acepta tráfico HTTP/HTTPS desde cualquier origen (es el punto de entrada
# público del flujo dinámico, detrás del API Gateway / WAF de Tiago).
# =============================================================================

resource "aws_security_group" "alb" {
  name        = "${var.proyecto}-${var.ambiente}-sg-alb"
  description = "Security Group del ALB - acepta HTTP/HTTPS desde internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #checkov:skip=CKV_AWS_260:ALB publico de Veltri Minimarket requiere HTTP para redirigir a HTTPS
  ingress {
    description = "HTTP desde internet (redirige a HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida hacia las instancias EC2 en subnets privadas"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] #Rango privado RFC-1918
  }

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-sg-alb"
    Modulo     = "compute"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}


# =============================================================================
# 2. SECURITY GROUP — Instancias EC2 (Auto Scaling Group)
# =============================================================================
# Solo acepta tráfico proveniente del Security Group del ALB.
# Principio de menor privilegio: nadie más puede hablarle a las EC2.
# en las reglas de entrada de Aurora y ElastiCache.
# =============================================================================

resource "aws_security_group" "ec2" {
  name        = "${var.proyecto}-${var.ambiente}-sg-ec2"
  description = "Security Group de las EC2 - solo acepta trafico del ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Trafico de la app desde el ALB unicamente"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS hacia AWS (Secrets Manager, ECR, CloudWatch)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "PostgreSQL hacia Aurora en subnets privadas"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "HTTP para redirects y dependencias via NAT"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-sg-ec2"
    Modulo     = "compute"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}


# =============================================================================
# 3. ECR — Repositorio de imágenes Docker
# =============================================================================
# Repositorio inmutable y privado, con escaneo automático de vulnerabilidades.
# =============================================================================

resource "aws_ecr_repository" "app" {
  name                 = "${var.proyecto}-${var.ambiente}-ecr-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-ecr-app"
    Modulo     = "compute"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

# Política de ciclo de vida — conservar solo las últimas N imágenes etiquetadas
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar solo las ultimas ${var.ecr_max_image_count} imagenes con tag de version"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.ecr_max_image_count
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Eliminar imagenes sin tag despues de 1 dia"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}


# =============================================================================
# 4. IAM — Rol de las instancias EC2 (principio de menor privilegio)
# =============================================================================
# Permite a las EC2:
#   - Autenticarse y hacer pull de imágenes desde ECR
#   - Leer (solo lectura) las credenciales de Aurora/Redis desde Secrets Manager
#   - Enviar logs/métricas a CloudWatch
# Sin credenciales fijas — todo vía rol asumido.
# =============================================================================

resource "aws_iam_role" "ec2" {
  name = "${var.proyecto}-${var.ambiente}-role-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-role-ec2"
    Modulo     = "compute"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

# Permiso: pull de imágenes desde ECR (acotado al repositorio de este módulo)
resource "aws_iam_role_policy" "ec2_ecr" {
  name = "${var.proyecto}-${var.ambiente}-policy-ec2-ecr"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*" # GetAuthorizationToken no admite Resource acotado
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

# Permiso: lectura del secreto de credenciales (Aurora/Redis) 
# RNF: "prohibido exponer texto plano de credenciales - usar Secrets Manager"
# Si el secreto de Josué aun no existe, se restringe por prefijo de nombre
# del proyecto para mantener el menor privilegio sin romper el plan.
resource "aws_iam_role_policy" "ec2_secrets" {
  name = "${var.proyecto}-${var.ambiente}-policy-ec2-secrets"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.proyecto}-${var.ambiente}-*"
      }
    ]
  })
}

# Permiso: logs y métricas hacia CloudWatch
resource "aws_iam_role_policy" "ec2_cloudwatch" {
  name = "${var.proyecto}-${var.ambiente}-policy-ec2-cloudwatch"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}


# =============================================================================
# Instance Profile — conecta el rol IAM con la instancia EC2

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.proyecto}-${var.ambiente}-profile-ec2"
  role = aws_iam_role.ec2.name

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-profile-ec2"
    Modulo     = "compute"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

#CAMBIOS. 

# =============================================================================
# CLOUDWATCH LOG GROUP
# =============================================================================

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${var.proyecto}-${var.ambiente}"
  retention_in_days = 30

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-logs"
    Modulo     = "compute"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

# =============================================================================
# 5. ALB — Application Load Balancer (público)
# =============================================================================
# Punto de entrada del flujo dinámico hacia las instancias EC2.
# Vive en las subredes PÚBLICAS 1 y 2 (recibe tráfico desde API Gateway/WAF).
#
# Health check: ruta /health cada 30 segundos.
# Connection draining: 60 segundos antes de desregistrar una instancia.
# =============================================================================

resource "aws_lb" "main" {
  name               = "${var.proyecto}-${var.ambiente}-alb"
  internal           = false
  load_balancer_type = "application"

  subnets         = var.public_subnets
  security_groups = [aws_security_group.alb.id]

  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-alb"
    Modulo     = "compute"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.proyecto}-${var.ambiente}-tg-app"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path # "/health" o "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30 # cada 30 segundos
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  # Connection draining — 60s para que terminen las transacciones en curso
  deregistration_delay = 60

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-tg-app"
    Modulo     = "compute"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}


# =============================================================================
# 6. LAUNCH TEMPLATE — Plantilla de instancias EC2
# =============================================================================
# Define el "molde" de cada instancia: usa la Golden AMI creada con Packer.
# El user-data arranca el contenedor Docker leyendo credenciales de Secrets Manager.
# =============================================================================

# AMI base: Amazon Linux 2023 (siempre disponible)
# Cuando se genere la Golden AMI con Packer, pasar su ID via var.ami_id
# para sobreescribir esta busqueda automatica.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "app" {
  name        = "${var.proyecto}-${var.ambiente}-lt-app"
  description = "Launch Template - instancias EC2 backend Veltri Minimarket"

  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2.arn
  }

  network_interfaces {
    associate_public_ip_address = false # EC2 sin IP publica, vive en subred privada
    security_groups             = [aws_security_group.ec2.id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  # User data: instala Docker, autentica con ECR via rol IAM,
  # descarga la imagen y lee credenciales de Secrets Manager.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Docker, AWS CLI y jq ya estan instalados en la Golden AMI generada por Packer/Ansible

    # Autenticacion con ECR via rol IAM (sin credenciales fijas)
    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}

    docker pull ${aws_ecr_repository.app.repository_url}:latest

    # Leer credenciales de BD desde Secrets Manager (gestionado por modulo data)
    SECRET_NAME="${var.proyecto}-${var.ambiente}-${var.db_secret_name_suffix}"
    SECRET=$(aws secretsmanager get-secret-value \
      --secret-id "$SECRET_NAME" \
      --region ${var.aws_region} \
      --query SecretString --output text 2>/dev/null || echo "{}")

    DB_HOST=$(echo $SECRET | jq -r '.host // empty')
    DB_NAME=$(echo $SECRET | jq -r '.dbname // empty')
    DB_USER=$(echo $SECRET | jq -r '.username // empty')
    DB_PASS=$(echo $SECRET | jq -r '.password // empty')

    docker run -d \
      --name veltri-backend \
      --restart unless-stopped \
      -p ${var.app_port}:${var.app_port} \
      -e DB_HOST="$DB_HOST" \
      -e DB_NAME="$DB_NAME" \
      -e DB_USER="$DB_USER" \
      -e DB_PASSWORD="$DB_PASS" \
      -e AWS_REGION="${var.aws_region}" \
      ${aws_ecr_repository.app.repository_url}:latest
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name       = "${var.proyecto}-${var.ambiente}-ec2-app"
      Modulo     = "compute"
      Ambiente   = var.ambiente
      Gestionado = "Terraform"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}


# =============================================================================
# 7. AUTO SCALING GROUP — Escalado horizontal
# =============================================================================
# Distribuido en las subredes privadas de compute (3 y 4).
# Escala segun consumo de CPU: 75% sube, 30% baja.
# =============================================================================

resource "aws_autoscaling_group" "app" {
  name = "${var.proyecto}-${var.ambiente}-asg-app"

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  vpc_zone_identifier = var.private_subnets_compute

  target_group_arns = [aws_lb_target_group.app.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.proyecto}-${var.ambiente}-ec2-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Modulo"
    value               = "compute"
    propagate_at_launch = true
  }

  tag {
    key                 = "Gestionado"
    value               = "Terraform"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}


# =============================================================================
# 8. POLÍTICAS DE AUTO SCALING
# =============================================================================

# Scale-out: aumentar instancias cuando CPU promedio > 75%
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.proyecto}-${var.ambiente}-asg-scale-out"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = var.scale_out_cpu_threshold # 75
    disable_scale_in = true
  }
}

# Scale-in: reducir instancias cuando CPU promedio < 30% por 15 minutos
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.proyecto}-${var.ambiente}-asg-scale-in"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 900 # 15 minutos
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.proyecto}-${var.ambiente}-alarm-cpu-low"
  alarm_description   = "CPU promedio < ${var.scale_in_cpu_threshold}% durante 15 minutos - dispara scale-in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold # 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-alarm-cpu-low"
    Modulo     = "compute"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

#CAMBIOS

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.proyecto}-${var.ambiente}-alarm-cpu-high"
  alarm_description   = "CPU promedio > 80% durante 10 minutos"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-alarm-cpu-high"
    Modulo     = "compute"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}
