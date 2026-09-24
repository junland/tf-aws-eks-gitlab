resource "random_password" "rds" {
  count = var.enable_rds && var.rds_master_password == null ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}:?"
}

resource "aws_db_subnet_group" "gitlab" {
  count = var.enable_rds && var.rds_subnet_group_name == null ? 1 : 0

  name       = "${local.rds_cluster_identifier}-subnets"
  subnet_ids = local.private_subnet_ids

  tags = merge(local.tags, {
    Name = "${local.rds_cluster_identifier}-subnets"
  })
}

resource "aws_security_group" "rds" {
  count = var.enable_rds ? 1 : 0

  name        = "${local.rds_cluster_identifier}-sg"
  description = "Security group for GitLab RDS"
  vpc_id      = local.vpc_id

  tags = merge(local.tags, {
    Name = "${local.rds_cluster_identifier}-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_nodes" {
  count = var.enable_rds ? 1 : 0

  security_group_id            = aws_security_group.rds[0].id
  referenced_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_cidr" {
  for_each = var.enable_rds ? toset(var.rds_allowed_cidrs) : toset([])

  security_group_id = aws_security_group.rds[0].id
  cidr_ipv4         = each.value
  from_port         = var.rds_port
  to_port           = var.rds_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "rds_all" {
  count = var.enable_rds ? 1 : 0

  security_group_id = aws_security_group.rds[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_rds_cluster" "gitlab" {
  count = var.enable_rds ? 1 : 0

  cluster_identifier           = local.rds_cluster_identifier
  engine                       = "aurora-postgresql"
  engine_version               = var.rds_engine_version
  database_name                = var.rds_database_name
  master_username              = var.rds_master_username
  master_password              = local.postgresql_password
  port                         = var.rds_port
  db_subnet_group_name         = local.rds_subnet_group_name
  vpc_security_group_ids       = local.rds_security_group_ids
  backup_retention_period      = var.rds_backup_retention_period
  preferred_backup_window      = var.rds_preferred_backup_window
  preferred_maintenance_window = var.rds_preferred_maintenance_window
  apply_immediately            = var.rds_apply_immediately
  storage_encrypted            = var.rds_storage_encrypted
  deletion_protection          = var.rds_deletion_protection
  skip_final_snapshot          = var.rds_skip_final_snapshot

  tags = merge(local.tags, {
    Name = local.rds_cluster_identifier
  })
}

resource "aws_rds_cluster_instance" "gitlab" {
  count = var.enable_rds ? var.rds_instance_count : 0

  identifier         = "${local.rds_cluster_identifier}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.gitlab[0].id
  instance_class     = var.rds_instance_class
  engine             = aws_rds_cluster.gitlab[0].engine
  engine_version     = aws_rds_cluster.gitlab[0].engine_version
  apply_immediately  = var.rds_apply_immediately

  tags = merge(local.tags, {
    Name = "${local.rds_cluster_identifier}-${count.index + 1}"
  })
}
