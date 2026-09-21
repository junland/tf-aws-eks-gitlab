resource "aws_iam_role" "eks_cluster" {
  name               = "${local.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  for_each = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSServicePolicy"
  ])

  role       = aws_iam_role.eks_cluster.name
  policy_arn = each.value
}

resource "aws_iam_role" "eks_node_group" {
  name               = "${local.cluster_name}-node-group-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_group_assume_role.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "eks_node_group" {
  for_each = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  ])

  role       = aws_iam_role.eks_node_group.name
  policy_arn = each.value
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[length(data.tls_certificate.eks_oidc.certificates) - 1].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = local.tags
}

resource "aws_iam_role" "gitlab_irsa" {
  count = local.manage_irsa_role ? 1 : 0

  name               = local.irsa_role_name
  assume_role_policy = data.aws_iam_policy_document.gitlab_irsa_assume_role[0].json
  tags               = local.tags
}

resource "aws_iam_role_policy" "gitlab_irsa" {
  count = local.manage_irsa_role ? 1 : 0

  name = "${local.irsa_role_name}-policy"
  role = aws_iam_role.gitlab_irsa[0].id

  policy = var.irsa_policy_json != null ? var.irsa_policy_json : data.aws_iam_policy_document.gitlab_irsa_s3[0].json
}
