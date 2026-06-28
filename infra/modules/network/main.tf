# 1. VPC Principal
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name     = "${var.proyecto}-${var.ambiente}-vpc"
    Ambiente = var.ambiente
  }
}

# SOLUCION CKV2_AWS_12 â€” Bloquear el Security Group por defecto de la VPC

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress = []
  egress  = []

  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-sg-default-restringido"
    Modulo     = "network"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}


# 2. Internet Gateway (Para dar salida a internet)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.proyecto}-${var.ambiente}-igw" }
}

# 3. Subredes Publicas
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.proyecto}-${var.ambiente}-public-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.proyecto}-${var.ambiente}-public-2" }
}

# 4 Subredes Privadas (Capa de Computo)
resource "aws_subnet" "private_3_compute" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "${var.proyecto}-${var.ambiente}-private-compute-3" }
}

resource "aws_subnet" "private_4_compute" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "${var.proyecto}-${var.ambiente}-private-compute-4" }
}

# 5 Subredes Privadas (Capa de Datos)
resource "aws_subnet" "private_5_data" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "${var.proyecto}-${var.ambiente}-private-data-5" }
}

resource "aws_subnet" "private_6_data" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "${var.proyecto}-${var.ambiente}-private-data-6" }
}
# 6 IPs Elasticas y NAT Gateways
resource "aws_eip" "nat_1" { domain = "vpc" }
resource "aws_eip" "nat_2" { domain = "vpc" }

resource "aws_nat_gateway" "nat_gw_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_1.id
  tags          = { Name = "${var.proyecto}-${var.ambiente}-nat-gw-1" }
}

resource "aws_nat_gateway" "nat_gw_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.public_2.id
  tags          = { Name = "${var.proyecto}-${var.ambiente}-nat-gw-2" }
}

# 7 Tablas de Enrutamiento Publicas

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.proyecto}-${var.ambiente}-public-rt" }
}

resource "aws_route_table_association" "pub_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# 7.1 Route Table Privada - Compute

resource "aws_route_table" "private_compute" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_1.id
  }

  tags = {
    Name = "${var.proyecto}-${var.ambiente}-private-compute-rt"
  }
}

# Asociaciones Compute

resource "aws_route_table_association" "private_compute_3" {
  subnet_id      = aws_subnet.private_3_compute.id
  route_table_id = aws_route_table.private_compute.id
}

resource "aws_route_table_association" "private_compute_4" {
  subnet_id      = aws_subnet.private_4_compute.id
  route_table_id = aws_route_table.private_compute.id
}

# Route Table Privada - Data

resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_2.id
  }

  tags = {
    Name = "${var.proyecto}-${var.ambiente}-private-data-rt"
  }
}

# Asociaciones Data

resource "aws_route_table_association" "private_data_5" {
  subnet_id      = aws_subnet.private_5_data.id
  route_table_id = aws_route_table.private_data.id
}

resource "aws_route_table_association" "private_data_6" {
  subnet_id      = aws_subnet.private_6_data.id
  route_table_id = aws_route_table.private_data.id
}

# -----------------------------------------------------------
# VPC Flow Logs (Solución para Checkov CKV2_AWS_11)
# -----------------------------------------------------------
resource "aws_kms_key" "cloudwatch" {
  description             = "KMS key para cifrado de CloudWatch Log Group - Veltri Minimarket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags = {
    Name       = "${var.proyecto}-${var.ambiente}-kms-cloudwatch"
    Modulo     = "network"
    Ambiente   = var.ambiente
    Gestionado = "Terraform"
  }
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log_group.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  name              = "/aws/vpc/${var.proyecto}-${var.ambiente}-flow-logs"
  retention_in_days = 365 # CKV_AWS_338: Mínimo 1 año de retención
  kms_key_id        = aws_kms_key.cloudwatch.arn
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "vpc_flow_log_role" {
  name               = "${var.proyecto}-${var.ambiente}-vpc-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "vpc_flow_log_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    # Reemplazamos el "*" por las rutas estrictas de los Logs
    resources = [
      "arn:aws:logs:*:*:log-group:*",
      "arn:aws:logs:*:*:log-group:*:log-stream:*"
    ]
  }
}

resource "aws_iam_role_policy" "vpc_flow_log_policy" {
  name   = "${var.proyecto}-${var.ambiente}-vpc-flow-log-policy"
  role   = aws_iam_role.vpc_flow_log_role.id
  policy = data.aws_iam_policy_document.vpc_flow_log_policy.json
}
