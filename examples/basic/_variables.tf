variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "gitlab_domain" {
  type = string
}

variable "postgresql_host" {
  type = string
}

variable "postgresql_database" {
  type = string
}

variable "postgresql_username" {
  type = string
}

variable "postgresql_existing_secret_name" {
  type = string
}

variable "s3_region" {
  type = string
}

variable "s3_existing_secret_name" {
  type = string
}
