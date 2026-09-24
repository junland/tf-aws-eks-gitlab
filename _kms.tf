resource "aws_kms_key" "eks_secrets" {
  count = var.enable_cluster_encryption && var.cluster_encryption_key_arn == null ? 1 : 0

  description         = "EKS secret encryption key for ${local.cluster_name}"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.eks_secrets_encryption.json
  tags                = local.tags
}
