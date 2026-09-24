output "cluster_name" {
  value = module.gitlab_eks.cluster_name
}

output "gitlab_namespace" {
  value = module.gitlab_eks.gitlab_namespace
}

output "object_storage_secret_name" {
  value = module.gitlab_eks.object_storage_secret_name
}

output "rds_cluster_endpoint" {
  value = module.gitlab_eks.rds_cluster_endpoint
}

output "s3_bucket_ids" {
  value = module.gitlab_eks.s3_bucket_ids
}
