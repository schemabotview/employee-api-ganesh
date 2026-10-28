variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-2"
}

variable "app_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "employee-api-ganesh"
}

variable "allowed_cidr" {
  description = "CIDR allowed to reach the API on port 8000"
  type        = string
}

variable "desired_count" {
  description = "Number of Fargate tasks to run"
  type        = number
  default     = 1
}

variable "image_tag" {
  description = "ECR image tag the task definition should run"
  type        = string
  default     = "latest"
}

variable "db_host" {
  description = "Postgres host the deployed API connects to"
  type        = string
}

variable "db_name" {
  description = "Postgres database name"
  type        = string
  default     = "appdb"
}

variable "db_user" {
  description = "Postgres user"
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "Postgres password"
  type        = string
  sensitive   = true
}
