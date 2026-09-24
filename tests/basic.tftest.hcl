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

  mock_resource "aws_eks_cluster" {
    defaults = {
      identity = [{
        oidc = [{
          issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/terraform-test"
        }]
      }]
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/87654321-4321-4321-4321-210987654321"
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

mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [{
        sha1_fingerprint = "0123456789abcdef0123456789abcdef01234567"
      }]
    }
  }
}

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
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API_AND_CONFIG_MAP"
    error_message = "The EKS cluster should use the API-backed authentication mode instead of the deprecated CONFIG_MAP-only mode."
  }

  assert {
    condition     = length(aws_eks_cluster.this.encryption_config) == 0
    error_message = "The EKS cluster should not enable secret envelope encryption unless the feature is explicitly configured."
  }

  assert {
    condition     = length(aws_kms_key.eks_secrets) == 0
    error_message = "The module should not create an EKS encryption key unless secret envelope encryption is enabled."
  }

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
    condition     = output.gitlab_redis_external_port == 6379
    error_message = "External Redis port should default to 6379 for the module-managed ElastiCache instance."
  }

  assert {
    condition     = contains(keys(local.gitlab_helm_values.global.redis), "host")
    error_message = "External Redis host should be configured to the module-managed ElastiCache endpoint."
  }

  assert {
    condition     = output.gitlab_redis_chart_install == false
    error_message = "Bundled Redis should stay disabled because the module always manages ElastiCache."
  }
}

run "plan_with_module_managed_cluster_encryption" {
  command = plan

  variables {
    enable_cluster_encryption = true
  }

  assert {
    condition     = length(aws_eks_cluster.this.encryption_config) == 1 && length(aws_eks_cluster.this.encryption_config[0].resources) == 1 && contains(tolist(aws_eks_cluster.this.encryption_config[0].resources), "secrets")
    error_message = "The EKS cluster should require envelope encryption for Kubernetes secrets when encryption is enabled."
  }

  assert {
    condition     = length(aws_kms_key.eks_secrets) == 1
    error_message = "The module should create a dedicated KMS key for EKS secret encryption when encryption is enabled without an existing KMS key."
  }
}

run "apply_with_module_managed_cluster_encryption" {
  command = apply

  variables {
    enable_cluster_encryption = true
    create_irsa_role          = false
  }

  assert {
    condition     = aws_eks_cluster.this.encryption_config[0].provider[0].key_arn == aws_kms_key.eks_secrets[0].arn
    error_message = "The EKS cluster should use the module-managed KMS key when encryption is enabled without an existing key ARN."
  }
}

run "plan_with_existing_cluster_encryption_key" {
  command = plan

  variables {
    enable_cluster_encryption = true
    cluster_encryption_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = length(aws_kms_key.eks_secrets) == 0
    error_message = "The module should not create an EKS encryption key when an existing KMS key ARN is provided."
  }

  assert {
    condition     = aws_eks_cluster.this.encryption_config[0].provider[0].key_arn == var.cluster_encryption_key_arn
    error_message = "The EKS cluster should use the provided KMS key ARN for secret envelope encryption."
  }
}

run "fails_with_cluster_encryption_key_without_enablement" {
  command = plan

  variables {
    cluster_encryption_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }

  expect_failures = [check.cluster_encryption_inputs]
}

run "fails_with_empty_cluster_encryption_key_arn" {
  command = plan

  variables {
    enable_cluster_encryption = true
    cluster_encryption_key_arn = ""
  }

  expect_failures = [var.cluster_encryption_key_arn]
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
    error_message = "Bundled Redis should be disabled because the module always manages ElastiCache."
  }

  assert {
    condition     = output.gitlab_redis_external_port == 6379
    error_message = "External Redis port should default to 6379 for the module-managed ElastiCache instance."
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
