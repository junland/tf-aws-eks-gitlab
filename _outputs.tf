output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN associated with the cluster"
  value       = aws_iam_openid_connect_provider.this.arn
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

output "elasticache_replication_group_id" {
  description = "ElastiCache replication group ID"
  value       = local.elasticache_replication_group_id
}

output "elasticache_primary_endpoint_address" {
  description = "Primary endpoint address for ElastiCache Redis"
  value       = aws_elasticache_replication_group.gitlab.primary_endpoint_address
}

output "elasticache_transit_encryption_enabled" {
  description = "Whether ElastiCache transit encryption is enabled"
  value       = aws_elasticache_replication_group.gitlab.transit_encryption_enabled
}

output "gitlab_redis_chart_install" {
  description = "Whether bundled Redis remains enabled in the GitLab chart values"
  value       = local.gitlab_helm_values.redis.install
}

output "gitlab_redis_external_host_configured" {
  description = "Whether external Redis host is configured in GitLab chart values"
  value       = can(local.gitlab_helm_values.global.redis.host)
}

output "gitlab_redis_external_port" {
  description = "Configured external Redis port in GitLab chart values"
  value       = try(local.gitlab_helm_values.global.redis.port, null)
}

output "gitlab_redis_external_scheme" {
  description = "Configured external Redis scheme in GitLab chart values"
  value       = try(local.gitlab_helm_values.global.redis.scheme, null)
}

output "gitlab_redis_external_rediss_enabled" {
  description = "Whether rediss/TLS is enabled for external Redis in GitLab chart values"
  value       = try(local.gitlab_helm_values.global.redis.rediss, null)
}

output "gitlab_redis_auth_enabled" {
  description = "Whether Redis auth is enabled in GitLab chart values for external Redis"
  value       = try(local.gitlab_helm_values.global.redis.auth.enabled, null)
}
