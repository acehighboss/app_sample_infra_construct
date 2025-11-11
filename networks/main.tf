resource "aws_vpc" "ex_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "${var.env}-vpc"
  }
}

resource "aws_subnet" "ex_subnets" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.ex_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.ex_vpc.cidr_block, 8, each.value)
  map_public_ip_on_launch = each.value % 10 == 0 ? true : false
  availability_zone       = data.aws_availability_zones.ex_az_names.names[floor(each.value / 10 - 1)]

  tags = {
    Name = "${var.env}-${each.key}"
  }
}

resource "aws_internet_gateway" "ex_igw" {
  vpc_id = aws_vpc.ex_vpc.id

  tags = {
    Name = "${var.env}-igw"
  }
}

resource "aws_route_table" "ex_public_rt" {
  vpc_id = aws_vpc.ex_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ex_igw.id
  }

  tags = {
    Name = "${var.env}-public-rt"
  }
}
resource "aws_route_table_association" "ex_public_rt_ass" {
  for_each = {
    for key, subnet in aws_subnet.ex_subnets :
    key => subnet.id if subnet.map_public_ip_on_launch == true
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.ex_public_rt.id
}

resource "aws_route_table" "ex_private_rt" {
  vpc_id = aws_vpc.ex_vpc.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.ex_nat.primary_network_interface_id
  }

  tags = {
    Name = "${var.env}-private-rt"
  }
}
resource "aws_route_table_association" "ex_private_rt_ass" {
  for_each = {
    for key, subnet in aws_subnet.ex_subnets :
    key => subnet.id if subnet.map_public_ip_on_launch == false
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.ex_private_rt.id
}

resource "aws_security_group" "ex_nat_sg" {
  vpc_id      = aws_vpc.ex_vpc.id
  name        = "${var.env}-nat-sg"
  description = "NAT Service"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-nat-sg"
  }
}

resource "aws_instance" "ex_nat" {
  ami           = "ami-0eb63419e063fe627"
  instance_type = "t3.micro"
  key_name      = "CPN_key"

  subnet_id              = aws_subnet.ex_subnets["public-10"].id
  vpc_security_group_ids = [aws_security_group.ex_nat_sg.id]

  source_dest_check = false

  user_data = file("${path.module}/nat-setting.sh")

  tags = {
    Name = "${var.env}-nat"
  }
}
