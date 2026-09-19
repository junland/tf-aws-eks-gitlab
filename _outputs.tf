output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN associated with the cluster"
  value       = module.eks.oidc_provider_arn
}

output "vpc_id" {
  description = "VPC ID used by the cluster"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by the cluster"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by the cluster"
  value       = local.public_subnet_ids
}

output "gitlab_namespace" {
  description = "GitLab namespace"
  value       = var.gitlab_namespace
}

output "gitlab_release_name" {
  description = "GitLab Helm release name"
  value       = var.gitlab_release_name
}

output "gitlab_irsa_role_arn" {
  description = "IRSA role ARN used by GitLab service accounts"
  value       = local.manage_irsa_role ? aws_iam_role.gitlab_irsa[0].arn : var.gitlab_irsa_role_arn
}

output "postgresql_secret_name" {
  description = "Kubernetes secret name for PostgreSQL credentials"
  value       = local.postgresql_secret_name
}

output "object_storage_secret_name" {
  description = "Kubernetes secret name for object storage connection"
  value       = local.object_storage_secret_name
}
