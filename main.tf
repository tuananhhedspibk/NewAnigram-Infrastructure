locals {
  region               = "ap-northeast-1"
  app_name             = "newanigram"
  

  alb_name                 = "newanigram-alb"
  alb_allow_cidr_block     = ["0.0.0.0/0"]
  alb_health_check_path    = "/"

  alb_deregistration_delay = "300"
}

terraform {
  backend "s3" {
    bucket  = "tfstate-newanigram"
    region  = "ap-northeast-1"
    key     = "terraform.tfstate"
    encrypt = true
    profile = "tuananh"
  }
}

provider "aws" {
  region  = "ap-northeast-1"
  profile = "tuananh"
}

module "network" {
  source                   = "./network"

  app_name                 = local.app_name
  vpc_cidr                 = "10.0.0.0/16"
  availability_zones       = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnets_cidr      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr     = ["10.0.10.0/24"]
  target_health_check_port = 80
  target_health_check_path = "/healthcheck"
}
