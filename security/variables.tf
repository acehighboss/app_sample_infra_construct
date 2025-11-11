variable "env" {
  type = string
}

variable "notification_email" {
  type        = string
  description = "GuardDuty 등 보안 알림을 수신할 기본 이메일 주소"
  
  # 기본값을 설정하거나, dev/main.tf 에서 주입할 수 있습니다.
  # 여기서는 비워두고 dev/main.tf 에서 값을 받도록 하겠습니다.
  # default = "your-email@example.com"
}
