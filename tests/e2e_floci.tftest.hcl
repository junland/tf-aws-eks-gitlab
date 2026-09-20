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
      id    = "floci-e2e"
      name  = "floci-e2e"
      token = "floci-e2e-token"
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
}

mock_provider "helm" {}

mock_provider "kubernetes" {}

variables {
  aws_region = "us-east-1"

  name_prefix = "floci-e2e"

  create_vpc         = true
  enable_nat_gateway = false
  azs                = ["us-east-1a"]

  private_subnet_cidrs = [
    "10.0.1.0/24",
  ]
  public_subnet_cidrs = [
    "10.0.101.0/24",
  ]

  deploy_gitlab    = false
  create_irsa_role = false

  gitlab_hostname                 = "gitlab.example.test"
  postgresql_host                 = "postgres.example.test"
  postgresql_database             = "gitlabhq_production"
  postgresql_username             = "gitlab"
  postgresql_existing_secret_name = "gitlab-postgres"
  s3_region                       = "us-east-1"
  s3_existing_secret_name         = "gitlab-object-storage"
}

override_data {
  target = data.aws_eks_cluster_auth.this

  values = {
    id    = "floci-e2e"
    name  = "floci-e2e"
    token = "floci-e2e-token"
  }
}

run "apply_vpc_against_floci" {
  command = plan

  assert {
    condition     = length(aws_vpc.this) == 1
    error_message = "VPC should be planned when create_vpc is enabled."
  }

}

run "plan_with_external_network_inputs" {
  command = plan

  variables {
    aws_region = "us-east-1"

    name_prefix = "floci-e2e"

    create_vpc         = false
    enable_nat_gateway = false
    azs                = ["us-east-1a"]

    private_subnet_cidrs = [
      "10.0.1.0/24",
    ]
    public_subnet_cidrs = [
      "10.0.101.0/24",
    ]

    vpc_id             = "vpc-cleanup-placeholder"
    private_subnet_ids = ["subnet-cleanup-private"]
    public_subnet_ids  = ["subnet-cleanup-public"]

    deploy_gitlab    = false
    create_irsa_role = false

    gitlab_hostname                 = "gitlab.example.test"
    postgresql_host                 = "postgres.example.test"
    postgresql_database             = "gitlabhq_production"
    postgresql_username             = "gitlab"
    postgresql_existing_secret_name = "gitlab-postgres"
    s3_region                       = "us-east-1"
    s3_existing_secret_name         = "gitlab-object-storage"
  }

  assert {
    condition     = output.vpc_id == "vpc-cleanup-placeholder"
    error_message = "Plan run should switch to provided external network inputs."
  }

  assert {
    condition     = length(aws_vpc.this) == 0
    error_message = "When create_vpc is false, no managed aws_vpc resource should be present."
  }

}

run "cleanup_targeted_vpc" {
  command = plan

  variables {
    aws_region = "us-east-1"

    name_prefix = "floci-e2e"

    create_vpc         = false
    enable_nat_gateway = false
    azs                = ["us-east-1a"]

    private_subnet_cidrs = [
      "10.0.1.0/24",
    ]
    public_subnet_cidrs = [
      "10.0.101.0/24",
    ]

    vpc_id             = "vpc-cleanup-placeholder"
    private_subnet_ids = ["subnet-cleanup-private"]
    public_subnet_ids  = ["subnet-cleanup-public"]

    deploy_gitlab    = false
    create_irsa_role = false

    gitlab_hostname                 = "gitlab.example.test"
    postgresql_host                 = "postgres.example.test"
    postgresql_database             = "gitlabhq_production"
    postgresql_username             = "gitlab"
    postgresql_existing_secret_name = "gitlab-postgres"
    s3_region                       = "us-east-1"
    s3_existing_secret_name         = "gitlab-object-storage"
  }

  assert {
    condition     = length(aws_vpc.this) == 0
    error_message = "Cleanup run should remove managed aws_vpc resources."
  }
}
