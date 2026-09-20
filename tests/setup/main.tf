variable "name_prefix" {
  description = "Prefix used for generated test prerequisite names."
  type        = string
  default     = "floci-e2e"
}

locals {
  postgresql = {
    host     = "127.0.0.1"
    port     = 5432
    database = "gitlabhq_production"
    username = "gitlab"
  }

  s3 = {
    region   = "us-east-1"
    endpoint = "http://127.0.0.1:9000"
    buckets = {
      artifacts        = "${var.name_prefix}-gitlab-artifacts"
      uploads          = "${var.name_prefix}-gitlab-uploads"
      packages         = "${var.name_prefix}-gitlab-packages"
      lfs              = "${var.name_prefix}-gitlab-lfs"
      terraform_state  = "${var.name_prefix}-gitlab-terraform-state"
      dependency_proxy = "${var.name_prefix}-gitlab-dependency-proxy"
      ci_secure_files  = "${var.name_prefix}-gitlab-secure-files"
      external_diffs   = "${var.name_prefix}-gitlab-external-diffs"
      backups          = "${var.name_prefix}-gitlab-backups"
      tmp              = "${var.name_prefix}-gitlab-tmp"
    }
  }
}
