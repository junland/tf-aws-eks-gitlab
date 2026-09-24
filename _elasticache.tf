resource "aws_elasticache_subnet_group" "gitlab" {
  count = var.elasticache_subnet_group_name == null ? 1 : 0

  name       = "${local.elasticache_replication_group_id}-subnets"
  subnet_ids = local.private_subnet_ids

  tags = merge(local.tags, {
    Name = "${local.elasticache_replication_group_id}-subnets"
  })
}

resource "aws_security_group" "elasticache" {
  name        = "${local.elasticache_replication_group_id}-sg"
  description = "Security group for GitLab ElastiCache"
  vpc_id      = local.vpc_id

  tags = merge(local.tags, {
    Name = "${local.elasticache_replication_group_id}-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_from_eks_nodes" {
  security_group_id            = aws_security_group.elasticache.id
  referenced_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  from_port                    = local.elasticache_connection_port
  to_port                      = local.elasticache_connection_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_from_cidr" {
  for_each = toset(var.elasticache_allowed_cidrs)

  security_group_id = aws_security_group.elasticache.id
  cidr_ipv4         = each.value
  from_port         = local.elasticache_connection_port
  to_port           = local.elasticache_connection_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "elasticache_all" {
  security_group_id = aws_security_group.elasticache.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_elasticache_replication_group" "gitlab" {
  replication_group_id = local.elasticache_replication_group_id
  description          = "GitLab Redis for ${local.cluster_name}"
  engine               = "redis"
  engine_version       = var.elasticache_engine_version
  node_type            = var.elasticache_node_type
  # Current module support is intentionally scoped to a single-node topology.
  num_cache_clusters         = 1
  port                       = local.elasticache_connection_port
  parameter_group_name       = var.elasticache_parameter_group_name
  subnet_group_name          = local.elasticache_subnet_group_name
  security_group_ids         = local.elasticache_security_group_ids
  automatic_failover_enabled = false
  multi_az_enabled           = false
  at_rest_encryption_enabled = var.elasticache_at_rest_encryption_enabled
  transit_encryption_enabled = var.elasticache_transit_encryption_enabled
  apply_immediately          = var.elasticache_apply_immediately
  maintenance_window         = var.elasticache_maintenance_window
  snapshot_retention_limit   = var.elasticache_snapshot_retention_limit

  tags = merge(local.tags, {
    Name = local.elasticache_replication_group_id
  })
}

moved {
  from = aws_security_group.elasticache[0]
  to   = aws_security_group.elasticache
}

moved {
  from = aws_vpc_security_group_ingress_rule.elasticache_from_eks_nodes[0]
  to   = aws_vpc_security_group_ingress_rule.elasticache_from_eks_nodes
}

moved {
  from = aws_vpc_security_group_egress_rule.elasticache_all[0]
  to   = aws_vpc_security_group_egress_rule.elasticache_all
}

moved {
  from = aws_elasticache_replication_group.gitlab[0]
  to   = aws_elasticache_replication_group.gitlab
}
