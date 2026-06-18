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

# SOLUCION CKV2_AWS_12 — Bloquear el Security Group por defecto de la VPC

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
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.proyecto}-${var.ambiente}-public-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
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
# 8 API Gateway (Punto de entrada regional)
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.proyecto}-${var.ambiente}-api"
  description = "API Gateway para el flujo dinamico"
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    create_before_destroy = true
  }
}