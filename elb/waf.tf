resource "aws_wafv2_web_acl" "ex_waf" {
  # 이름은 elb/variables.tf 에 이미 정의된 var.env 변수를 사용합니다.
  name  = "${var.env}-waf-acl"
  
  # ALB에 연결하는 WAF는 반드시 "REGIONAL" 이어야 합니다.
  scope = "REGIONAL"

  # 기본 정책: 규칙에 걸리지 않는 모든 트래픽은 '허용'합니다.
  default_action {
    allow {}
  }

  # 규칙 1: SQL Injection (SQLi) 공격을 차단합니다.
  rule {
    name     = "AWS-Managed-SQLi-Rule"
    priority = 10 # 규칙 실행 우선순위 (낮을수록 먼저 실행)

    override_action {
      none {} # 규칙 그룹의 기본 동작(차단)을 따름
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        # AWS 관리형 SQL Injection 전용 규칙 그룹
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.env}-waf-sqli"
      sampled_requests_enabled   = true
    }
  }

  # 규칙 2: XSS 및 기타 일반적인 공격을 차단합니다.
  rule {
    name     = "AWS-Managed-Common-Rule"
    priority = 20

    override_action {
      none {} # 규칙 그룹의 기본 동작(차단)을 따름
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        # AWS 관리형 공용 규칙 (XSS, 악성 입력 등을 포함)
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.env}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  # 모니터링 및 로깅을 위한 설정
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.env}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.env}-waf-acl"
  }
}