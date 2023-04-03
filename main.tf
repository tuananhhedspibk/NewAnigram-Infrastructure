locals {
  region               = "ap-northeast-1"
  app_name             = "newanigram"
  vpc_cidr             = "10.0.0.0/16"
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr = ["10.0.10.0/24"]
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
  source              = "./network"

  region              = local.region
  app_name            = local.app_name
  vpc_cidr            = local.vpc_cidr
  public_subnets_cidr = local.public_subnets_cidr
  private_subnet_cidr = local.private_subnets_cidr
}
