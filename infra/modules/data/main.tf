resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "${var.proyecto}-${var.ambiente}-aurora-subnet-group"
  subnet_ids = var.private_subnets_data
  tags       = { Name = "${var.proyecto}-${var.ambiente}-aurora-subnet-group", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.proyecto}-${var.ambiente}-redis-subnet-group"
  subnet_ids = var.private_subnets_data
  tags       = { Name = "${var.proyecto}-${var.ambiente}-redis-subnet-group", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "aws_security_group" "data_sg" {
  name        = "${var.proyecto}-${var.ambiente}-data-sg"
  description = "Filtro estricto para Aurora y Redis. Solo permite acceso desde capa de computo."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Acceso a Aurora desde la capa de computo"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.security_group_compute_id]
  }
  ingress {
    description     = "Acceso a Redis desde la capa de computo"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.security_group_compute_id]
  }
  egress {
    description     = "Salida restringida al Security Group de computo"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [var.security_group_compute_id]
  }
  tags = { Name = "${var.proyecto}-${var.ambiente}-data-sg", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "aws_kms_key" "secrets_key" {
  description             = "Llave KMS administrada por el cliente para cifrar los secretos de la base de datos"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = { Name = "${var.proyecto}-${var.ambiente}-kms-secrets", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  #checkov:skip=BC_AWS_2_57:Rotacion automatica requiere Lambda dedicada con acceso VPC y permisos IAM especificos,
   identificado como mejora fuera del alcance del modulo data en esta entrega
  name                    = "${var.proyecto}-${var.ambiente}-db-creds-v2"
  recovery_window_in_days = 0

  kms_key_id              = aws_kms_key.secrets_key.id

  tags                    = { Name = "${var.proyecto}-${var.ambiente}-db-creds-v2", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result
    engine   = var.db_engine
    port     = 3306
  })
}

resource "aws_kms_key" "rds_key" {
  description             = "Llave KMS administrada por el cliente para cifrar el cluster RDS"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = { Name = "${var.proyecto}-${var.ambiente}-kms-rds", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier                  = "${var.proyecto}-${var.ambiente}-aurora-cluster"
  engine                              = var.db_engine
  engine_version                      = var.db_engine_version
  master_username                     = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string)["username"]
  master_password                     = jsondecode(aws_secretsmanager_secret_version.db_credentials_version.secret_string)["password"]
  db_subnet_group_name                = aws_db_subnet_group.aurora_subnet_group.name
  vpc_security_group_ids              = [aws_security_group.data_sg.id]
  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.rds_key.arn
  skip_final_snapshot                 = true
  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["audit", "error", "general", "slowquery"]
  deletion_protection                 = true
  copy_tags_to_snapshot               = true
  tags                                = { Name = "${var.proyecto}-${var.ambiente}-aurora-cluster", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }

  lifecycle {
    ignore_changes = [engine_version]
  }
}

resource "aws_rds_cluster_instance" "aurora_instances" {
  count                           = 2
  identifier                      = "${var.proyecto}-${var.ambiente}-aurora-instance-${count.index + 1}"
  cluster_identifier              = aws_rds_cluster.aurora_cluster.id
  instance_class                  = var.db_instance_class
  engine                          = aws_rds_cluster.aurora_cluster.engine
  engine_version                  = aws_rds_cluster.aurora_cluster.engine_version
  db_subnet_group_name            = aws_db_subnet_group.aurora_subnet_group.name
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds_key.arn
  auto_minor_version_upgrade      = true
  monitoring_interval             = 60
  tags                            = { Name = "${var.proyecto}-${var.ambiente}-aurora-instance-${count.index + 1}", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }

  lifecycle {
    ignore_changes = [engine_version]
  }
}

resource "aws_backup_vault" "aurora_vault" {
  name = "${var.proyecto}-${var.ambiente}-backup-vault"
  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-backup-vault"
    Modulo     = "data"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

resource "aws_backup_plan" "aurora_backup" {
  name = "${var.proyecto}-${var.ambiente}-backup-plan"

  rule {
    rule_name         = "backup-diario-aurora"
    target_vault_name = aws_backup_vault.aurora_vault.name
    schedule          = "cron(0 3 * * ? *)"  # todos los dias a las 3am UTC
  }

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-backup-plan"
    Modulo     = "data"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

resource "aws_backup_selection" "aurora_backup_selection" {
  iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSBackupDefaultServiceRole"
  name         = "${var.proyecto}-${var.ambiente}-backup-selection"
  plan_id      = aws_backup_plan.aurora_backup.id

  resources = [
    aws_rds_cluster.aurora_cluster.arn
  ]
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "redis" {
  description             = "KMS key para cifrado de Redis ElastiCache - Veltri Minimarket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-kms-redis"
    Modulo     = "data"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

resource "aws_elasticache_replication_group" "redis_cluster" {
  replication_group_id       = "${var.proyecto}-${var.ambiente}-redis"
  description                = "Cluster de Redis"
  node_type                  = var.redis_node_type
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids         = [aws_security_group.data_sg.id]
  automatic_failover_enabled = true
  num_cache_clusters         = 2
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result
  kms_key_id                 = aws_kms_key.redis.arn
  tags                       = { Name = "${var.proyecto}-${var.ambiente}-redis", Modulo = "data", Ambiente = var.ambiente, Gestionado = "Terraform" }
}

resource "random_password" "redis_auth_token" {
  length  = 32
  special = false  # ElastiCache no acepta algunos caracteres especiales
}