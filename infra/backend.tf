terraform {
  backend "s3" {
    bucket  = "veltri-minimarket-tfstate-v2"
    key     = "estado/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}