variable "db_username" {
  type = string
}
variable "db_password" {
  type = string
}

# PS C:\terraform\workspace\09_file_division> $env:TF_VAR_db_username = "admin"
# PS C:\terraform\workspace\09_file_division> $env:TF_VAR_db_password = "mariaPassw0rd"