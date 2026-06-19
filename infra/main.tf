module "network" {
  source     = "./modules/network"
  aws_region = var.aws_region
  proyecto   = var.proyecto
  ambiente   = var.ambiente
}

module "compute" {
  source                  = "./modules/compute"
  proyecto                = var.proyecto
  ambiente                = var.ambiente
  aws_region              = var.aws_region
  
  vpc_id                  = module.network.vpc_id
  public_subnets          = module.network.public_subnets
  private_subnets_compute = module.network.private_subnets_compute
}

module "data" {
  source                    = "./modules/data"
  proyecto                  = var.proyecto
  ambiente                  = var.ambiente
  
  vpc_id                    = module.network.vpc_id
  private_subnets_data      = module.network.private_subnets_data
  security_group_compute_id = module.compute.security_group_compute_id
}

module "edge" {
  source                  = "./modules/edge"
  proyecto                = var.proyecto
  ambiente                = var.ambiente
  
  vpc_id                  = module.network.vpc_id
  private_subnets_compute = module.network.private_subnets_compute
}