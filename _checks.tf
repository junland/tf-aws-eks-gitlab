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

check "eks_managed_node_group_supported_fields" {
  assert {
    condition = alltrue([
      for node_group in values(var.eks_managed_node_groups) : alltrue([
        for key in keys(node_group) : contains([
          "ami_type",
          "capacity_type",
          "disk_size",
          "instance_types",
          "labels",
          "release_version",
          "version",
          "min_size",
          "desired_size",
          "max_size",
          "max_unavailable",
          "max_unavailable_percentage"
        ], key)
      ])
    ])
    error_message = format(
      "eks_managed_node_groups contains unsupported keys for the native aws_eks_node_group implementation: %s. Supported keys: ami_type, capacity_type, disk_size, instance_types, labels, release_version, version, min_size, desired_size, max_size, max_unavailable, max_unavailable_percentage.",
      join(", ", flatten([
        for node_group_name, node_group in var.eks_managed_node_groups : [
          for key in keys(node_group) : "${node_group_name}.${key}" if !contains([
            "ami_type",
            "capacity_type",
            "disk_size",
            "instance_types",
            "labels",
            "release_version",
            "version",
            "min_size",
            "desired_size",
            "max_size",
            "max_unavailable",
            "max_unavailable_percentage"
          ], key)
        ]
      ]))
    )
  }
}

check "cluster_addons_supported_fields" {
  assert {
    condition = alltrue([
      for addon in values(var.cluster_addons) : alltrue([
        for key in keys(addon) : contains([
          "addon_version",
          "configuration_values",
          "preserve",
          "resolve_conflicts",
          "resolve_conflicts_on_create",
          "resolve_conflicts_on_update",
          "service_account_role_arn"
        ], key)
      ])
    ])
    error_message = format(
      "cluster_addons contains unsupported keys for the native aws_eks_addon implementation: %s. Supported keys: addon_version, configuration_values, preserve, resolve_conflicts, resolve_conflicts_on_create, resolve_conflicts_on_update, service_account_role_arn.",
      join(", ", flatten([
        for addon_name, addon in var.cluster_addons : [
          for key in keys(addon) : "${addon_name}.${key}" if !contains([
            "addon_version",
            "configuration_values",
            "preserve",
            "resolve_conflicts",
            "resolve_conflicts_on_create",
            "resolve_conflicts_on_update",
            "service_account_role_arn"
          ], key)
        ]
      ]))
    )
  }
}

check "cluster_encryption_inputs" {
  assert {
    condition     = var.enable_cluster_encryption || var.cluster_encryption_key_arn == null
    error_message = "Do not set cluster_encryption_key_arn unless enable_cluster_encryption is true."
  }
}

check "elasticache_snapshot_retention_limit" {
  assert {
    condition     = var.elasticache_snapshot_retention_limit == 0
    error_message = "elasticache_snapshot_retention_limit must be 0 for the currently supported single-node topology."
  }
}

check "elasticache_replication_group_id" {
  assert {
    condition     = length(regexall("^[a-z](?:[a-z0-9-]{0,38}[a-z0-9])?$", local.elasticache_replication_group_id)) > 0
    error_message = "ElastiCache replication group ID is normalized to 1-40 lowercase letters, digits, and hyphens, must start with a letter, and must not end with a hyphen."
  }
}

check "elasticache_auth_token_unsupported" {
  assert {
    condition     = var.elasticache_auth_token == null
    error_message = "This module currently supports unauthenticated ElastiCache Redis only; set elasticache_auth_token to null."
  }
}
