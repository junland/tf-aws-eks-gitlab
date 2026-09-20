resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  enabled_cluster_log_types = var.cluster_enabled_log_types

  vpc_config {
    subnet_ids              = local.private_subnet_ids
    endpoint_public_access  = var.cluster_endpoint_public_access
    endpoint_private_access = var.cluster_endpoint_private_access
  }

  access_config {
    bootstrap_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  }

  dynamic "kubernetes_network_config" {
    for_each = var.cluster_service_ipv4_cidr != null ? [var.cluster_service_ipv4_cidr] : []

    content {
      service_ipv4_cidr = kubernetes_network_config.value
    }
  }

  tags = local.tags

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_eks_node_group" "this" {
  for_each = var.eks_managed_node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = local.private_subnet_ids

  ami_type        = lookup(each.value, "ami_type", null)
  capacity_type   = lookup(each.value, "capacity_type", null)
  disk_size       = lookup(each.value, "disk_size", null)
  instance_types  = lookup(each.value, "instance_types", null)
  labels          = lookup(each.value, "labels", null)
  release_version = lookup(each.value, "release_version", null)
  version         = lookup(each.value, "version", null)

  scaling_config {
    min_size     = lookup(each.value, "min_size", 1)
    desired_size = lookup(each.value, "desired_size", lookup(each.value, "min_size", 1))
    max_size     = lookup(each.value, "max_size", lookup(each.value, "desired_size", lookup(each.value, "min_size", 1)))
  }

  dynamic "update_config" {
    for_each = lookup(each.value, "max_unavailable", null) != null || lookup(each.value, "max_unavailable_percentage", null) != null ? [each.value] : []

    content {
      max_unavailable            = lookup(update_config.value, "max_unavailable", null)
      max_unavailable_percentage = lookup(update_config.value, "max_unavailable_percentage", null)
    }
  }

  tags = local.tags

  depends_on = [aws_iam_role_policy_attachment.eks_node_group]
}

resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.key

  addon_version               = lookup(each.value, "addon_version", null)
  configuration_values        = lookup(each.value, "configuration_values", null)
  preserve                    = lookup(each.value, "preserve", null)
  resolve_conflicts_on_create = lookup(each.value, "resolve_conflicts_on_create", lookup(each.value, "resolve_conflicts", null))
  resolve_conflicts_on_update = lookup(each.value, "resolve_conflicts_on_update", lookup(each.value, "resolve_conflicts", null))
  service_account_role_arn    = lookup(each.value, "service_account_role_arn", null)

  tags = local.tags

  depends_on = [aws_eks_node_group.this]
}
