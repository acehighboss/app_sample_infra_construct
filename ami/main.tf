resource "terraform_data" "web_server_check" {
  triggers_replace = var.web_instance.private_ip

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/cpn_web.pem")
    host        = var.web_instance.private_ip

    bastion_user        = "ubuntu"
    bastion_private_key = file("~/.ssh/CPN_key.pem")
    bastion_host        = var.bastion_public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "until curl -fs -o /dev/null localhost:3000; do",
      " echo 'waiting for Server creation...'",
      " sleep 10",
      "done",
      "echo 'WEB Server is ready'"
    ]
  }
}

resource "aws_ec2_instance_state" "web_stop" {
  instance_id = var.web_instance.id
  state       = "stopped"
  depends_on  = [terraform_data.web_server_check]
}

resource "aws_ami_from_instance" "ex_web_ami" {
  name               = "${var.env}-web-ami"
  source_instance_id = var.web_instance.id

  tags = {
    Name = "${var.env}-web-ami"
  }
  # web 정지 후 ami 생성 개시
  depends_on = [aws_ec2_instance_state.web_stop]
}
