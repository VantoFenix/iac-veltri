terraform {
  backend "s3" {
    bucket  = "veltri-minimarket-tfstate" 
    key     = "estado/terraform.tfstate"
    region  = "eu-east-1"
    encrypt = true
  }
}