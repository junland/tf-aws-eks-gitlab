data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_eks_cluster_auth" "this" {
  name       = aws_eks_cluster.this.name
  depends_on = [aws_eks_cluster.this]
}

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
