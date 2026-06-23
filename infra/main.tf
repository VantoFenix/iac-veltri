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

module "dns" {
  source = "./modules/dns"

  proyecto    = var.proyecto
  ambiente    = var.ambiente
  domain_name = var.domain_name 

  cdn_domain_name    = module.edge.cloudfront_domain_name
  cdn_hosted_zone_id = module.edge.cloudfront_hosted_zone_id

  alb_dns_name = module.compute.alb_dns_name
  alb_zone_id  = module.compute.alb_zone_id
}