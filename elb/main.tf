resource "aws_security_group" "ex_lb_sg" {
  vpc_id      = var.vpc_id
  name        = "${var.env}-lb-sg"
  description = "load-balancer"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.env}-lb-sg"
  }
}

resource "aws_lb_target_group" "ex_lb_tg" {
  name     = "${var.env}-lb-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path = "/"
  }
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 300
  }

  tags = {
    Name = "${var.env}-lb-tg"
  }
}

resource "aws_lb" "ex_lb" {
  name               = "${var.env}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ex_lb_sg.id]
  subnets            = toset(values(var.public_subnet_ids))

  tags = {
    Name = "${var.env}-lb"
  }
}

resource "aws_lb_listener" "ex_lb_forward" {
  load_balancer_arn = aws_lb.ex_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ex_lb_tg.arn
  }
}

# WAF ACL(aws_wafv2_web_acl)과 기존 ALB(aws_lb)를 연결합니다.
resource "aws_wafv2_web_acl_association" "ex_waf_assoc" {
  
  # 연결할 리소스(ALB)의 ARN
  resource_arn = aws_lb.ex_lb.arn

  # 연결할 WAF ACL의 ARN
  web_acl_arn  = aws_wafv2_web_acl.ex_waf.arn
}
