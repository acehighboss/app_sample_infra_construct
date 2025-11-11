output "target_group_arn" {
  value = aws_lb_target_group.ex_lb_tg.arn
}

output "ELB_dns" {
  value = aws_lb.ex_lb.dns_name
}

output "elb_sg_id" {
  value = aws_security_group.ex_lb_sg.id
}