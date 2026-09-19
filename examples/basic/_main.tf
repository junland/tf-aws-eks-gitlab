module "gitlab_eks" {
  source = "../../"

  aws_region      = var.aws_region
  name_prefix     = "gitlab-prod"
  cluster_name    = "gitlab-prod-eks"
  gitlab_hostname = var.gitlab_domain

  kubernetes_version = "1.36"

  eks_managed_node_groups = {
    general = {
      instance_types = ["m6i.xlarge"]
      min_size       = 3
      desired_size   = 3
      max_size       = 10
      capacity_type  = "ON_DEMAND"
      disk_size      = 120
    }
  }

  postgresql_host                 = var.postgresql_host
  postgresql_database             = var.postgresql_database
  postgresql_username             = var.postgresql_username
  postgresql_existing_secret_name = var.postgresql_existing_secret_name

  s3_region               = var.s3_region
  s3_existing_secret_name = var.s3_existing_secret_name

  s3_buckets = {
    artifacts        = "gitlab-prod-artifacts"
    uploads          = "gitlab-prod-uploads"
    packages         = "gitlab-prod-packages"
    lfs              = "gitlab-prod-lfs"
    terraform_state  = "gitlab-prod-terraform-state"
    dependency_proxy = "gitlab-prod-dependency-proxy"
    ci_secure_files  = "gitlab-prod-secure-files"
    external_diffs   = "gitlab-prod-external-diffs"
    backups          = "gitlab-prod-backups"
    tmp              = "gitlab-prod-tmp"
  }

  gitlab_ingress_annotations = {
    "kubernetes.io/ingress.class" = "nginx"
  }

  tags = {
    environment = "production"
    workload    = "gitlab"
  }
}
