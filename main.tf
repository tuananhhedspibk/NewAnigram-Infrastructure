locals {
  region   = "ap-northeast-1"
  app_name = "newanigram"
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
  source   = "./network"

  region   = local.region
  app_name = local.app_name
}
