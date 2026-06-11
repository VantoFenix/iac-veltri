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