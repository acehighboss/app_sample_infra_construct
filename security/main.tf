# 1. CloudTrail이 로그를 CloudWatch Logs로 보낼 수 있게 하는 IAM 역할
# 1-1. CloudTrail 서비스가 이 역할을 맡을 수 있도록 허용
data "aws_iam_policy_document" "cloudtrail_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

# 1-2. IAM 역할 생성
resource "aws_iam_role" "ex_cloudtrail_cw_role" {
  name_prefix        = "${var.env}-ct-cw-role-"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role.json
  tags = {
    Name = "${var.env}-cloudtrail-cw-role"
  }
}

# 1-3. CloudWatch Logs에 로그를 쓸 수 있는 권한 정책
data "aws_iam_policy_document" "cloudtrail_cw_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    # 리소스 ARN은 아래 aws_cloudwatch_log_group에서 동적으로 가져옵니다.
    resources = ["${aws_cloudwatch_log_group.ex_cw_log_group.arn}:*"]
  }
}

# 1-4. 위 권한 정책을 역할에 연결
resource "aws_iam_role_policy" "ex_cloudtrail_cw_policy" {
  name_prefix = "${var.env}-ct-cw-policy-"
  role        = aws_iam_role.ex_cloudtrail_cw_role.id
  policy      = data.aws_iam_policy_document.cloudtrail_cw_policy.json
}


# 2. CloudWatch Logs 그룹 생성 (CloudTrail 로그 연동용)
resource "aws_cloudwatch_log_group" "ex_cw_log_group" {
  name = "/aws/cloudtrail/${var.env}-trail-logs"

  # 로그 보존 기간 (예: 90일)
  retention_in_days = 90

  tags = {
    Name = "${var.env}-cloudtrail-log-group"
  }
}


# 3. CloudTrail 로그를 저장할 S3 버킷 생성
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "ex_cloudtrail_bucket" {
  # 버킷 이름은 전역에서 고유해야 하므로 계정 ID와 환경 이름을 조합합니다.
  bucket = "${var.env}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.env}-cloudtrail-bucket"
  }
}

# 3-1. S3 버킷 정책 (CloudTrail 서비스가 버킷에 로그를 쓸 수 있도록 허용)
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetBucketAcl"]
    effect    = "Allow"
    resources = [aws_s3_bucket.ex_cloudtrail_bucket.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    actions = ["s3:PutObject"]
    effect  = "Allow"
    # 로그 파일에 대한 경로 설정 (계정 ID로 시작)
    resources = ["${aws_s3_bucket.ex_cloudtrail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

# 3-2. 버킷에 정책 적용
resource "aws_s3_bucket_policy" "ex_cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.ex_cloudtrail_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}


# 4. CloudTrail 생성 (S3 및 CloudWatch Logs 연결)
resource "aws_cloudtrail" "ex_trail" {
  name                       = "${var.env}-main-trail"
  s3_bucket_name             = aws_s3_bucket.ex_cloudtrail_bucket.id
  
  # 모든 리전의 활동을 기록 (프로젝트 목표에 부합)
  is_multi_region_trail      = true
  include_global_service_events = true

  # CloudWatch Logs 연동 설정
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.ex_cw_log_group.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.ex_cloudtrail_cw_role.arn

  # S3 버킷 정책과 CW Logs 역할이 먼저 생성되어야 함
  depends_on = [
    aws_s3_bucket_policy.ex_cloudtrail_bucket_policy,
    aws_iam_role_policy.ex_cloudtrail_cw_policy
  ]

  tags = {
    Name = "${var.env}-main-trail"
  }
}

# 5. GuardDuty 활성화 (계정 위협 탐지)
resource "aws_guardduty_detector" "ex_detector" {
  enable = true

  tags = {
    Name = "${var.env}-guardduty-detector"
  }
}

# 6. AWS Config - IAM Role (Config가 리소스 정보를 읽을 수 있도록 허용)
# 6-1. Config 서비스가 맡을 수 있는 역할 정책
data "aws_iam_policy_document" "config_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

# 6-2. IAM 역할 생성
resource "aws_iam_role" "ex_config_role" {
  name_prefix        = "${var.env}-config-role-"
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json
  tags = {
    Name = "${var.env}-config-role"
  }
}

# 6-3. AWS 관리형 Config 정책을 역할에 연결
resource "aws_iam_role_policy_attachment" "ex_config_policy_attach" {
  role       = aws_iam_role.ex_config_role.name
  # AWS_ConfigRole 관리형 정책은 Config 서비스가 필요한 모든 권한을 포함합니다.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}


# 7. AWS Config - S3 Bucket (설정 기록 및 스냅샷 저장용)
resource "aws_s3_bucket" "ex_config_bucket" {
  # 버킷 이름은 전역에서 고유해야 합니다.
  bucket = "${var.env}-config-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.env}-config-bucket"
  }
}

# 7-1. Config 서비스가 이 S3 버킷에 로그를 쓸 수 있도록 하는 정책
data "aws_iam_policy_document" "config_s3_policy" {
  # 이 정책은 IAM 역할이 먼저 존재해야 함
  depends_on = [aws_iam_role.ex_config_role]

  statement {
    actions = ["s3:GetBucketAcl", "s3:ListBucket"]
    effect    = "Allow"
    resources = [aws_s3_bucket.ex_config_bucket.arn]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
  statement {
    actions = ["s3:PutObject"]
    effect  = "Allow"
    # Config가 저장할 경로를 지정
    resources = ["${aws_s3_bucket.ex_config_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

# 7-2. S3 버킷에 정책 적용
resource "aws_s3_bucket_policy" "ex_config_bucket_policy" {
  bucket = aws_s3_bucket.ex_config_bucket.id
  policy = data.aws_iam_policy_document.config_s3_policy.json
}


# 8. AWS Config - Configuration Recorder (무엇을 기록할지 설정)
resource "aws_config_configuration_recorder" "ex_recorder" {
  name     = "${var.env}-recorder"
  role_arn = aws_iam_role.ex_config_role.arn

  recording_group {
    # 모든 지원되는 리소스 유형을 기록합니다.
    all_supported                 = true
    # IAM과 같은 글로벌 리소스도 포함합니다.
    include_global_resource_types = true
  }

  # IAM 역할이 먼저 연결되어야 함
  depends_on = [aws_iam_role_policy_attachment.ex_config_policy_attach]
}


# 9. AWS Config - Delivery Channel (어디로 전송할지 설정)
resource "aws_config_delivery_channel" "ex_channel" {
  name           = "${var.env}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.ex_config_bucket.name

  # 레코더와 S3 버킷 정책이 먼저 생성되어야 함
  depends_on = [
    aws_config_configuration_recorder.ex_recorder,
    aws_s3_bucket_policy.ex_config_bucket_policy
  ]
}


# 10. AWS Config - Managed Rules (보안 규정 설정)
# 10-1. S3 버킷 Public Read 금지 (사용자 요청)
resource "aws_config_config_rule" "s3_public_read" {
  name = "s3-bucket-public-read-prohibited"

  # AWS 관리형 규칙(Managed Rule) 사용
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  # Config 설정이 완료된 후 적용
  depends_on = [aws_config_delivery_channel.ex_channel]
}

# 10-2. S3 버킷 Public Write 금지 (추천 규칙)
resource "aws_config_config_rule" "s3_public_write" {
  name = "s3-bucket-public-write-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }

  depends_on = [aws_config_delivery_channel.ex_channel]
}

# 10-3. Security Group 인바운드 0.0.0.0/0 (전체 오픈) 제한 (추천 규칙)
resource "aws_config_config_rule" "restricted_common_ports" {
  name = "restricted-common-ports"
  
  source {
    owner = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED" # SSH 외 다른 포트도 확인 가능 (아래 파라미터 참조)
  }

  # (선택) 특정 포트(예: 22, 3389)가 0.0.0.0/0으로 열려 있는지 확인
  # input_parameters = jsonencode({
  #   "blockedPort1": "22",
  #   "blockedPort2": "3389"
  # })

  # 이 규칙은 보안 그룹 리소스에만 적용
  scope {
    compliance_resource_types = ["AWS::EC2::SecurityGroup"]
  }

  depends_on = [aws_config_delivery_channel.ex_channel]
}

# 11. AWS Security Hub 활성화 (통합 보안 대시보드)
resource "aws_securityhub_account" "ex_securityhub" {
  # 이 리소스 하나로 Security Hub가 활성화됩니다.
  # 활성화되면 자동으로 GuardDuty, Config, WAF 등의
  # 탐지 결과를 가져오기 시작합니다.
  
  # 참고: GuardDuty와 Config가 이 리소스보다 먼저 활성화되어 있어야
  # Security Hub가 즉시 데이터를 가져올 수 있습니다. (현재 코드가 그 상태)
}

# 12. Security Hub - 보안 표준 구독 (필수)
# AWS Foundational Security Best Practices 표준을 구독합니다.
# 이 표준을 구독해야 Config 규칙과 연동된 보안 점검이 시작됩니다.
resource "aws_securityhub_standards_subscription" "ex_foundational_best_practices" {
  
  # AWS 기본 보안 모범 사례 표준(ARN)
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"

  # Security Hub 계정이 먼저 활성화되어야 함
  depends_on = [aws_securityhub_account.ex_securityhub]
}

# 13. (참고) 현재 리전 정보를 가져오기 위한 data source
# 위 'standards_arn'을 동적으로 구성하기 위해 파일 상단에 추가 (권장)
# (만약 파일 상단에 이미 'data "aws_caller_identity"' 등이 있다면 그 근처에 추가하세요)
data "aws_region" "current" {}

# 14. SNS Topic (보안 알림 전용)
# GuardDuty, Security Hub 등의 알림을 이곳으로 보냅니다.
resource "aws_sns_topic" "ex_security_alerts" {
  name = "${var.env}-security-alerts-topic"
  tags = {
    Name = "${var.env}-security-alerts-topic"
  }
}

# 14-1. SNS Topic - Email 구독
# 1단계에서 추가한 변수(var.notification_email)를 사용합니다.
resource "aws_sns_topic_subscription" "ex_email_subscription" {
  topic_arn = aws_sns_topic.ex_security_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# 15. EventBridge Rule (GuardDuty '심각' 등급 탐지)
# GuardDuty가 '심각' 등급(7.0~8.9)의 위협을 탐지하면 이벤트를 발생시킵니다.
resource "aws_cloudwatch_event_rule" "ex_guardduty_high_severity_rule" {
  name        = "${var.env}-guardduty-high-severity-rule"
  description = "GuardDuty 'High' severity findings"

  # JSON 형식의 이벤트 패턴
  event_pattern = jsonencode({
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"],
    "detail": {
      # GuardDuty의 '심각' 등급은 숫자 7.0 에서 8.9 사이입니다.
      "severity": [
        { "numeric": [">=", 7.0, "<=", 8.9] }
      ]
    }
  })

  tags = {
    Name = "${var.env}-gd-high-sev-rule"
  }
}

# 16. SNS Topic - 리소스 정책
# EventBridge 서비스(events.amazonaws.com)가 이 SNS 토픽에
# 메시지를 'Publish'(게시)할 수 있도록 허용하는 정책입니다.
data "aws_iam_policy_document" "ex_sns_topic_policy_doc" {
  statement {
    actions   = ["sns:Publish"]
    effect    = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    # 이 SNS 토픽(ex_security_alerts)에 대해서만 허용
    resources = [aws_sns_topic.ex_security_alerts.arn]
    # 이 EventBridge 규칙(ex_guardduty_high_severity_rule)으로부터의 요청만 허용
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.ex_guardduty_high_severity_rule.arn]
    }
  }
}

# 16-1. SNS 토픽에 위 정책(16번) 적용
resource "aws_sns_topic_policy" "ex_sns_policy" {
  arn    = aws_sns_topic.ex_security_alerts.arn
  policy = data.aws_iam_policy_document.ex_sns_topic_policy_doc.json
}


# 17. EventBridge Target (규칙과 SNS 토픽 연결)
# 15번 규칙(GuardDuty '심각' 탐지)이 발생하면
# 14번 SNS 토픽(ex_security_alerts)으로 알림을 보냅니다.
resource "aws_cloudwatch_event_target" "ex_sns_target" {
  rule      = aws_cloudwatch_event_rule.ex_guardduty_high_severity_rule.name
  target_id = "${var.env}-sns-target"
  arn       = aws_sns_topic.ex_security_alerts.arn
}