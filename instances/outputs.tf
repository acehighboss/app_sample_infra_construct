output "web_instance" {
  value = aws_instance.ex_web_ec2
}

output "bastion_public_ip" {
  value = aws_instance.ex_bastion_ec2.public_ip
}

output "web_sg_id" {
  value = aws_security_group.ex_web_sg.id
}