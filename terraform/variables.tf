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
  description = "Postgres host the API connects to. The sidecar shares the task's network namespace, so this stays localhost."
  type        = string
  default     = "localhost"

  validation {
    condition     = length(var.db_host) > 0
    error_message = "db_host must not be empty. libpq reads an empty host as 'use a Unix socket', which no sidecar listens on. An unset TF_VAR_db_host in CI expands to \"\" and overrides this default, so pass nothing at all rather than an empty value."
  }
}

variable "postgres_image" {
  description = "Postgres image for the sidecar. ECR Public avoids Docker Hub pull limits."
  type        = string
  default     = "public.ecr.aws/docker/library/postgres:16-alpine"
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
  description = "Postgres password. Initialises the sidecar and is what the API authenticates with."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) > 0
    error_message = "db_password must not be empty; Postgres refuses to initialise without one."
  }
}
