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