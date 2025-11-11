output "vpc_id" {
  value = aws_vpc.ex_vpc.id
}

output "vpc_cidr" {
  value = aws_vpc.ex_vpc.cidr_block
}

locals {
  public_subnet_ids = {
    for key, value in var.subnets :
    key => aws_subnet.ex_subnets[key].id if value % 10 == 0
  }

  web_subnet_ids = {
    for key, value in var.subnets :
    key => aws_subnet.ex_subnets[key].id if value % 10 == 1
  }

  db_subnet_ids = {
    for key, value in var.subnets :
    key => aws_subnet.ex_subnets[key].id if value % 10 == 2
  }
}
output "public_subnet_ids" {
  value = local.public_subnet_ids
}
output "web_subnet_ids" {
  value = local.web_subnet_ids
}
output "db_subnet_ids" {
  value = local.db_subnet_ids
}

output "subnets" {
  value = var.subnets
}