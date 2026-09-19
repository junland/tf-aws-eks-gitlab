output "cluster_name" {
  value = module.gitlab_eks.cluster_name
}

output "gitlab_namespace" {
  value = module.gitlab_eks.gitlab_namespace
}

output "object_storage_secret_name" {
  value = module.gitlab_eks.object_storage_secret_name
}
