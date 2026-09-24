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

  enable_rds         = true
  enable_elasticache = true
  enable_s3_buckets  = true

  rds_instance_class = "db.r6g.large"
  s3_region          = var.aws_region

  gitlab_ingress_annotations = {
    "kubernetes.io/ingress.class" = "nginx"
  }

  tags = {
    environment = "production"
    workload    = "gitlab"
  }
}
