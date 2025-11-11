terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "terraform-admin"
}

locals {
  env = "dev"
}

module "networks" {
  source   = "../networks"
  vpc_cidr = "10.0.0.0/16"
  env      = local.env
}

module "ELB" {
  source            = "../elb"
  env               = local.env
  vpc_id            = module.networks.vpc_id
  vpc_cidr          = module.networks.vpc_cidr
  public_subnet_ids = module.networks.public_subnet_ids
}

# module "S3" {
#   source = "../s3"
#   env    = local.env
# }

# module "IAM" {
#   source    = "../iam"
#   env       = local.env
#   bucket_id = module.S3.bucket_id
# }

module "AMI" {
  source            = "../ami"
  web_instance      = module.instances.web_instance
  bastion_public_ip = module.instances.bastion_public_ip
  env               = local.env
}

module "ASG" {
  source           = "../asg"
  env              = local.env
  web_subnet_ids   = module.networks.web_subnet_ids
  ami_id           = module.AMI.ami_id
  web_sg_id        = module.instances.web_sg_id
  target_group_arn = module.ELB.target_group_arn
}

module "instances" {
  source            = "../instances"
  vpc_id            = module.networks.vpc_id
  public_subnet_ids = module.networks.public_subnet_ids
  web_subnet_ids    = module.networks.web_subnet_ids
  db_subnet_ids     = module.networks.db_subnet_ids
  elb_sg_id         = module.ELB.elb_sg_id
  # iam_instance_profile_id = module.IAM.iam_instance_profile_id
  # s3_object_id            = module.S3.object_id

  db_username = var.db_username
  db_password = var.db_password
  env         = local.env
}

module "security" {
  source = "../security"
  env    = local.env
  # 아래 한 줄 추가 (본인 이메일로 변경)
  notification_email = "security-admin@example.com"
}
