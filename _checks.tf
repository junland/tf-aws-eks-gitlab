check "existing_network_inputs" {
  assert {
    condition     = var.create_vpc || (var.vpc_id != null && length(var.private_subnet_ids) > 0)
    error_message = "When create_vpc is false, vpc_id and private_subnet_ids must be provided."
  }
}

check "created_network_inputs" {
  assert {
    condition = !var.create_vpc || (
      length(var.azs) == length(var.private_subnet_cidrs) &&
      length(var.azs) == length(var.public_subnet_cidrs)
    )
    error_message = "When create_vpc is true, azs, private_subnet_cidrs, and public_subnet_cidrs must have matching lengths."
  }
}

check "postgresql_secret_or_password" {
  assert {
    condition     = var.postgresql_existing_secret_name != null || var.postgresql_password != null
    error_message = "Provide postgresql_existing_secret_name or postgresql_password."
  }
}

check "s3_authentication_inputs" {
  assert {
    condition = var.s3_existing_secret_name != null || var.s3_use_iam_profile || (
      var.s3_access_key != null && var.s3_secret_key != null
    )
    error_message = "Provide s3_existing_secret_name, enable s3_use_iam_profile, or provide both s3_access_key and s3_secret_key."
  }
}

check "elasticache_cluster_count" {
  assert {
    condition     = !var.enable_elasticache || var.elasticache_num_cache_clusters == 1
    error_message = "When enable_elasticache is true, elasticache_num_cache_clusters must be set to 1 for this module's replication-group configuration."
  }
}

check "elasticache_snapshot_retention_limit" {
  assert {
    condition     = !var.enable_elasticache || var.elasticache_snapshot_retention_limit >= 0
    error_message = "When enable_elasticache is true, elasticache_snapshot_retention_limit must be 0 or greater."
  }
}

check "elasticache_replication_group_id" {
  assert {
    condition = !var.enable_elasticache || can(regex(
      "^[a-z](?:[a-z0-9-]{0,38}[a-z0-9])?$",
      local.elasticache_replication_group_id
    ))
    error_message = "ElastiCache replication group ID must start with a letter and contain only lowercase letters, digits, and hyphens."
  }
}
