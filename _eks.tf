module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                          = local.cluster_name
  cluster_version                       = var.kubernetes_version
  cluster_endpoint_public_access        = var.cluster_endpoint_public_access
  cluster_endpoint_private_access       = var.cluster_endpoint_private_access
  cluster_enabled_log_types             = var.cluster_enabled_log_types
  cluster_service_ipv4_cidr             = var.cluster_service_ipv4_cidr
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  vpc_id                   = local.vpc_id
  subnet_ids               = local.private_subnet_ids
  control_plane_subnet_ids = local.private_subnet_ids

  enable_irsa = true

  eks_managed_node_groups = var.eks_managed_node_groups
  cluster_addons          = var.cluster_addons

  tags = local.tags
}
