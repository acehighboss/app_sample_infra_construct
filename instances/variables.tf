variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = map(string)
}
variable "web_subnet_ids" {
  type = map(string)
}
variable "db_subnet_ids" {
  type = map(string)
}

variable "elb_sg_id" {
  type = string
}

variable "env" {
  type = string
}

# variable "iam_instance_profile_id" {
#   type = string
# }

# variable "s3_object_id" {
#   type = string
# }

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
}