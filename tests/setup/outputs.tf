output "name_prefix" {
  description = "Effective test setup naming prefix."
  value       = var.name_prefix
}

output "postgresql" {
  description = "Local PostgreSQL integration test connection settings."
  value       = local.postgresql
}

output "s3" {
  description = "S3-compatible integration test settings and bucket names."
  value       = local.s3
}
