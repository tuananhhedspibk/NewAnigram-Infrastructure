locals {
  region               = "ap-northeast-1"
  app_name             = "newanigram"

  db_database          = "newanigram"
  db_username          = "newanigram"
  db_password          = "password"
  db_port              = 3306

  vpc_cidr             = "10.0.0.0/16"
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
  vpc_cidr                 = local.vpc_cidr
  availability_zones       = ["ap-northeast-1a", "ap-northeast-1c"]
  public_subnets_cidr      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr     = ["10.0.10.0/24"]
  target_health_check_port = 80
  target_health_check_path = "/healthcheck"
}

module "proxy" {
  source    = "./proxy"
  app_name  = local.app_name
  vpc_id    = module.network.vpc_id
  subnet_id = module.network.public_subnet_ids[0]
}

module "rds" {
  source               = "./rds"

  app_name             = local.app_name
  vpc_id               = module.network.vpc_id
  vpc_cidr             = local.vpc_cidr
  subnet_ids           = module.network.private_subnet_ids

  proxy_security_group = module.proxu.security_group_id

  port                 = local.db_port
  master_username      = local.db_username
  master_password      = local.db_password
  database_name        = local.db_database
}

module "ecs_cluster" {
  source   = "./ecs_cluster"
  app_name = var.app_name
}

module "ecs_api" {
  source = "./ecs_api"

  app_name = var.app_name

  db_host = module.rds.endpoint
}

resource "aws_ssm_parameter" "rds_database" {
  name = "/rds/newanigram/host"
  type = "String"
  value = local.db_database
}
