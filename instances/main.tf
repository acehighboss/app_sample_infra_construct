resource "aws_security_group" "ex_bastion_sg" {
  vpc_id = var.vpc_id
  name   = "${var.env}-bastion-sg"
  tags = {
    "Name" = "${var.env}-bastion-sg"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "ex_web_sg" {
  vpc_id = var.vpc_id
  name   = "${var.env}-web-sg"
  tags = {
    "Name" = "${var.env}-web-sg"
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.elb_sg_id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "ex_rds_sg" {
  vpc_id = var.vpc_id
  name   = "${var.env}-db-sg"
  tags = {
    "Name" = "${var.env}-db-sg"
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ex_web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ex_bastion_ec2" {
  tags = {
    "Name" = "${var.env}-bastion-ec2"
  }

  ami           = "ami-00e73adb2e2c80366" # Ubuntu24 AMI 
  instance_type = "t3.micro"
  key_name      = "CPN_key"

  subnet_id              = var.public_subnet_ids["public-30"]
  vpc_security_group_ids = [aws_security_group.ex_bastion_sg.id]
}

resource "aws_instance" "ex_web_ec2" {
  tags = {
    "Name" = "${var.env}-web-ec2"
  }

  ami           = "ami-00e73adb2e2c80366" # Ubuntu24 AMI 
  instance_type = "t3.micro"
  key_name      = "cpn_web"

  subnet_id              = var.web_subnet_ids["private-11"]
  vpc_security_group_ids = [aws_security_group.ex_web_sg.id]

  user_data = templatefile("${path.module}/app_install.tpl", {
    DB_ADDRESS  = aws_db_instance.ex_rds.address,
    DB_USERNAME = var.db_username,
    DB_PASSWORD = var.db_password,
  })
}
resource "terraform_data" "web_file_transfer" {
  triggers_replace = aws_instance.ex_web_ec2.private_ip

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/cpn_web.pem")
    host        = aws_instance.ex_web_ec2.private_ip

    bastion_user        = "ubuntu"
    bastion_private_key = file("~/.ssh/CPN_key.pem")
    bastion_host        = aws_instance.ex_bastion_ec2.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "until [ -d /home/ubuntu/my-app/views/ ]; do",
      " echo 'preparing file transfer...'",
      " sleep 10",
      "done",
      "echo 'file transfer ready'"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/sampleApp/server.js"
    destination = "/home/ubuntu/my-app/server.js"
  }
  provisioner "file" {
    source      = "${path.module}/sampleApp/db-setup.js"
    destination = "/home/ubuntu/my-app/db-setup.js"
  }
  provisioner "file" {
    source      = "${path.module}/sampleApp/package.json"
    destination = "/home/ubuntu/my-app/package.json"
  }
  provisioner "file" {
    source      = "${path.module}/sampleApp/views/index.ejs"
    destination = "/home/ubuntu/my-app/views/index.ejs"
  }
}

resource "aws_db_instance" "ex_rds" {
  allocated_storage      = 10
  db_name                = "myappdb"
  engine                 = "mariadb"
  engine_version         = "11.4.5"
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = true
  parameter_group_name   = "default.mariadb11.4"
  identifier             = "${var.env}-rds"
  vpc_security_group_ids = [aws_security_group.ex_rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.ex_private_sg_group.id
  availability_zone      = data.aws_availability_zones.ex_az_names.names[0]
}

resource "aws_db_subnet_group" "ex_private_sg_group" {
  name       = "${var.env}-private-sg-group"
  subnet_ids = toset(values(var.db_subnet_ids))
}
