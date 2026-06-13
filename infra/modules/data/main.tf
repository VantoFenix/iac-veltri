resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "${var.proyecto}-${var.ambiente}-aurora-subnet-group"
  subnet_ids = var.private_subnets_data
  tags = { Name = "${var.proyecto}-${var.ambiente}-aurora-subnet-group", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.proyecto}-${var.ambiente}-redis-subnet-group"
  subnet_ids = var.private_subnets_data
  tags = { Name = "${var.proyecto}-${var.ambiente}-redis-subnet-group", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "aws_security_group" "data_sg" {
  name        = "${var.proyecto}-${var.ambiente}-data-sg"
  description = "Filtro estricto para Aurora y Redis. Solo permite acceso desde capa de computo."
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.security_group_compute_id]
  }
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.security_group_compute_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.proyecto}-${var.ambiente}-data-sg", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${var.proyecto}-${var.ambiente}-db-credentials"
  tags = { Name = "${var.proyecto}-${var.ambiente}-db-credentials", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result
    engine   = var.db_engine
    port     = 3306
  })
}