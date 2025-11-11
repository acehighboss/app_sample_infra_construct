output "ami_id" {
  value = aws_ami_from_instance.ex_web_ami.id
}