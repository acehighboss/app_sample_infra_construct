variable "vpc_cidr" {
  type = string
}

variable "env" {
  type = string
}

variable "subnets" {
  type = map(any)
  default = {
    public-10  = 10
    private-11 = 11
    private-12 = 12
    public-30  = 30
    private-31 = 31
    private-32 = 32
  }
}