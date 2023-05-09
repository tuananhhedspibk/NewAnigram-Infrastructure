locals {
  region               = "ap-northeast-1"
  app_name             = "newanigram"

  db_database          = "newanigram"
  db_username          = "newanigram"
  db_password          = "password"
  db_port              = 3306

  vpc_cidr             = "10.0.0.0/16"

  ecs_security_group_name = "${local.app_name}-ecs-security-group"
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
  private_subnets_cidr     = ["10.0.10.0/24", "10.0.20.0/24"]
  target_health_check_port = 80
  target_health_check_path = "/v1/healthcheck"
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

  proxy_security_group = module.proxy.security_group_id

  port                 = local.db_port
  master_username      = local.db_username
  master_password      = local.db_password
  database_name        = local.db_database
}

module "ecs_cluster" {
  source   = "./ecs_cluster"
  app_name = local.app_name
}

module "ecs_api" {
  source              = "./ecs_api"

  app_name            = local.app_name
  
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids

  http_listener_arn   = module.network.http_listener_arn
  lb_target_group_arn = module.network.lb_target_group_arn
  security_group_name = local.ecs_security_group_name

  db_host             = module.rds.endpoint
  db_username         = local.db_username
  db_password         = local.db_password
  db_database_name    = local.db_database

  cluster_name        = module.ecs_cluster.cluster_name
}

resource "aws_ssm_parameter" "rds_database" {
  name  = "/rds/newanigram/database"
  type  = "String"
  value = local.db_database
}

resource "aws_ssm_parameter" "rds_username" {
  name  = "/rds/newanigram/username"
  type  = "String"
  value = local.db_username
}

resource "aws_ssm_parameter" "rds_password" {
  name  = "/rds/newanigram/password"
  type  = "SecureString"
  value = local.db_password
}

resource "aws_ssm_parameter" "rds_port" {
  name  = "/rds/newanigram/port"
  type  = "String"
  value = local.db_port
}
