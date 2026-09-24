mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/terraform-test"
      id         = "123456789012"
      user_id    = "AIDATERRAFORMTEST"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      dns_suffix         = "amazonaws.com"
      id                 = "aws"
      partition          = "aws"
      reverse_dns_prefix = "com.amazonaws"
    }
  }

  mock_data "aws_eks_cluster_auth" {
    defaults = {
      id    = "terraform-test"
      name  = "unit-eks"
      token = "terraform-test-token"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      id            = "terraform-test-policy"
      json          = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
      minified_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      arn        = "arn:aws:iam::123456789012:role/terraform-test"
      id         = "terraform-test"
      issuer_arn = "arn:aws:iam::123456789012:role/terraform-test"
      issuer_id  = "AROATERRAFORMTEST"
      user_id    = "AROATERRAFORMTEST:terraform-test"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn  = "arn:aws:iam::123456789012:role/terraform-test"
      name = "terraform-test"
    }
  }

  mock_resource "aws_elasticache_replication_group" {
    defaults = {
      primary_endpoint_address = "redis.example.test"
    }
  }
}

mock_provider "helm" {}

mock_provider "kubernetes" {}

# Common global variables set across test runs
variables {
  cluster_name                    = "unit-eks"
  create_vpc                      = false
  deploy_gitlab                   = false
  vpc_id                          = "vpc-12345678"
  private_subnet_ids              = ["subnet-11111111", "subnet-22222222"]
  public_subnet_ids               = ["subnet-33333333", "subnet-44444444"]
  gitlab_hostname                 = "gitlab.example.com"
  postgresql_host                 = "postgres.example.internal"
  postgresql_database             = "gitlabhq_production"
  postgresql_username             = "gitlab"
  postgresql_existing_secret_name = "gitlab-postgres"
  s3_region                       = "us-east-1"
  s3_existing_secret_name         = "gitlab-object-storage"
}

run "plan_with_existing_network_and_secrets" {
  command = plan

  assert {
    condition     = output.gitlab_namespace == "gitlab"
    error_message = "The default GitLab namespace should remain gitlab."
  }

  assert {
    condition     = output.postgresql_secret_name == "gitlab-postgres"
    error_message = "The module should reuse the provided PostgreSQL secret name."
  }

  assert {
    condition     = output.object_storage_secret_name == "gitlab-object-storage"
    error_message = "The module should reuse the provided object storage secret name."
  }

  assert {
    condition     = output.gitlab_redis_external_host_configured
    error_message = "External Redis host should be configured from the module-managed ElastiCache instance."
  }

  assert {
    condition     = output.gitlab_redis_chart_install == false
    error_message = "Bundled Redis should stay disabled because the module always manages ElastiCache."
  }
}

run "plan_derives_secret_names_from_release_name" {
  command = plan

  variables {
    gitlab_release_name             = "gitlab-prod"
    postgresql_existing_secret_name = null
    postgresql_password             = "placeholder-password"
    s3_existing_secret_name         = null
    s3_use_iam_profile              = true
  }

  assert {
    condition     = output.postgresql_secret_name == "gitlab-prod-postgresql"
    error_message = "The PostgreSQL secret name should default from the release name."
  }

  assert {
    condition     = output.object_storage_secret_name == "gitlab-prod-object-storage"
    error_message = "The object storage secret name should default from the release name."
  }
}

run "fails_without_existing_network_inputs" {
  command = plan

  variables {
    vpc_id            = null
    public_subnet_ids = null
  }

  expect_failures = [check.existing_network_inputs]
}

run "fails_without_postgresql_credentials" {
  command = plan

  variables {
    postgresql_existing_secret_name = null
  }

  expect_failures = [check.postgresql_secret_or_password]
}

run "fails_without_s3_authentication" {
  command = plan

  variables {
    s3_existing_secret_name = null
    s3_use_iam_profile      = false
  }

  expect_failures = [check.s3_authentication_inputs]
}

run "plan_with_default_elasticache" {
  command = plan

  assert {
    condition     = output.elasticache_replication_group_id == "unit-eks-gitlab-redis"
    error_message = "The ElastiCache replication group ID should default from the cluster name."
  }

  assert {
    condition     = output.gitlab_redis_chart_install == false
    error_message = "Bundled Redis should be disabled when ElastiCache is enabled."
  }

  assert {
    condition     = output.gitlab_redis_external_port == 6379
    error_message = "External Redis port should default to 6379 when ElastiCache is enabled."
  }

  assert {
    condition     = output.gitlab_redis_external_scheme == "redis"
    error_message = "External Redis scheme should default to redis when transit encryption is disabled."
  }

  assert {
    condition     = output.gitlab_redis_auth_enabled == false
    error_message = "Redis auth should be disabled for unauthenticated ElastiCache mode."
  }
}

run "fails_with_invalid_elasticache_snapshot_retention_limit" {
  command = plan

  variables {
    elasticache_snapshot_retention_limit = -1
  }

  expect_failures = [check.elasticache_snapshot_retention_limit]
}

run "fails_with_unsupported_elasticache_snapshot_retention_limit" {
  command = plan

  variables {
    elasticache_snapshot_retention_limit = 1
  }

  expect_failures = [check.elasticache_snapshot_retention_limit]
}

run "normalizes_invalid_elasticache_replication_group_id" {
  command = plan

  variables {
    elasticache_replication_group_id = "1invalid-group"
  }

  assert {
    condition     = output.elasticache_replication_group_id == "a1invalid-group"
    error_message = "ElastiCache replication group ID should be normalized to start with a letter."
  }
}

run "normalizes_elasticache_replication_group_id_invalid_characters" {
  command = plan

  variables {
    elasticache_replication_group_id = "Prod Redis!!"
  }

  assert {
    condition     = output.elasticache_replication_group_id == "prod-redis"
    error_message = "ElastiCache replication group ID should normalize invalid characters to hyphens."
  }
}

run "normalizes_elasticache_replication_group_id_empty_result" {
  command = plan

  variables {
    elasticache_replication_group_id = "!!!"
  }

  assert {
    condition     = output.elasticache_replication_group_id == "a"
    error_message = "ElastiCache replication group ID should default to a when normalization would otherwise be empty."
  }
}

run "fails_when_elasticache_auth_token_is_set" {
  command = plan

  variables {
    elasticache_auth_token = "placeholder-token"
  }

  expect_failures = [check.elasticache_auth_token_unsupported]
}

run "plan_with_elasticache_tls_enabled" {
  command = plan

  variables {
    elasticache_transit_encryption_enabled = true
  }

  assert {
    condition     = output.gitlab_redis_external_scheme == "rediss"
    error_message = "External Redis scheme should be rediss when transit encryption is enabled."
  }

  assert {
    condition     = output.gitlab_redis_external_rediss_enabled
    error_message = "External Redis rediss flag should be true when transit encryption is enabled."
  }

  assert {
    condition     = output.gitlab_redis_external_port == 6379
    error_message = "External Redis port should remain on the configured ElastiCache listener port."
  }

  assert {
    condition     = output.elasticache_transit_encryption_enabled
    error_message = "ElastiCache replication group transit encryption should be enabled when requested."
  }

  assert {
    condition     = output.gitlab_redis_auth_enabled == false
    error_message = "Redis auth should remain disabled when ElastiCache TLS mode is enabled."
  }
}
