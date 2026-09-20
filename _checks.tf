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
    error_message = "eks_managed_node_groups contains unsupported keys for the native aws_eks_node_group implementation."
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
          "resolve_conflicts_on_create",
          "resolve_conflicts_on_update",
          "service_account_role_arn"
        ], key)
      ])
    ])
    error_message = "cluster_addons contains unsupported keys for the native aws_eks_addon implementation."
  }
}
