resource "aws_security_group" "gitlab_ingress" {
  count = var.deploy_gitlab && var.create_gitlab_security_group ? 1 : 0

  name        = "${local.cluster_name}-gitlab-ingress"
  description = "Ingress security group for GitLab load balancer"
  vpc_id      = local.vpc_id

  tags = merge(local.tags, {
    Name = "${local.cluster_name}-gitlab-ingress"
  })
}

resource "aws_vpc_security_group_ingress_rule" "gitlab_http" {
  for_each = var.deploy_gitlab && var.create_gitlab_security_group ? toset(var.gitlab_ingress_cidrs) : toset([])

  security_group_id = aws_security_group.gitlab_ingress[0].id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "gitlab_https" {
  for_each = var.deploy_gitlab && var.create_gitlab_security_group ? toset(var.gitlab_ingress_cidrs) : toset([])

  security_group_id = aws_security_group.gitlab_ingress[0].id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "gitlab_all" {
  count = var.deploy_gitlab && var.create_gitlab_security_group ? 1 : 0

  security_group_id = aws_security_group.gitlab_ingress[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
