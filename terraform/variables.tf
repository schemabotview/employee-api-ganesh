variable "region" {
  default = "eu-west-2"
}

variable "app_name" {
  default = "employee-api-ganesh"
}
variable "db_host" {}
variable "db_name" {}
variable "db_user" {}

variable "db_password" {
  sensitive = true
}

variable "desired_count" {
  default = 1
}