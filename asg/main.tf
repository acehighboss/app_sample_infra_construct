resource "aws_launch_template" "ex_web_lt" {
  name          = "${var.env}-web-lt"
  image_id      = var.ami_id
  instance_type = "t3.micro"
  key_name      = "cpn_web"

  vpc_security_group_ids = [var.web_sg_id]

  tags = {
    Name = "${var.env}-web-lt"
  }
}


resource "aws_autoscaling_group" "ex_asg" {
  name                  = "${var.env}-asg"
  max_size              = 4
  min_size              = 2
  desired_capacity      = 2
  desired_capacity_type = "units"

  vpc_zone_identifier = toset(values(var.web_subnet_ids))
  target_group_arns   = [var.target_group_arn]

  health_check_type = "ELB"

  default_instance_warmup = 300

  metrics_granularity = "1Minute"

  launch_template {
    id      = aws_launch_template.ex_web_lt.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "ex_asg_policy" {
  name                   = "${var.env}-asg-policy"
  autoscaling_group_name = aws_autoscaling_group.ex_asg.id
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 30.0
  }
}
