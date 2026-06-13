module "network" {
  source     = "./modules/network"
  aws_region = var.aws_region
  proyecto   = var.proyecto
  ambiente   = var.ambiente
}

module "data" {
  source   = "./modules/data"
  proyecto = var.proyecto
  ambiente = var.ambiente
}

module "compute" {
  source   = "./modules/compute"
  proyecto = var.proyecto
  ambiente = var.ambiente
}

module "edge" {
  source   = "./modules/edge"
  proyecto = var.proyecto
  ambiente = var.ambiente
}