variable "env" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "web_subnet_ids" {
  type = map(string)
}

variable "web_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}