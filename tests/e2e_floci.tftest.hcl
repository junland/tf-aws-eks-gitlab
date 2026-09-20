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
  command = apply

  apply_options {
    target = [aws_vpc.this[0]]
  }

  assert {
    condition     = aws_vpc.this[0].id != ""
    error_message = "VPC should be created successfully against the Floci endpoint."
  }

  assert {
    condition     = data.aws_eks_cluster_auth.this.name == "floci-e2e"
    error_message = "aws_eks_cluster_auth data source should use overridden values in Floci tests."
  }

  assert {
    condition     = data.aws_eks_cluster_auth.this.token == "floci-e2e-token"
    error_message = "aws_eks_cluster_auth override token should be used in Floci tests."
  }
}

run "destroy_targeted_vpc" {
  command = apply

  apply_options {
    target = [aws_vpc.this[0]]
  }

  variables {
    create_vpc          = false
    vpc_id              = "vpc-cleanup-placeholder"
    private_subnet_ids  = ["subnet-cleanup-private"]
    public_subnet_ids   = ["subnet-cleanup-public"]
    deploy_gitlab       = false
    create_irsa_role    = false
    gitlab_hostname     = "gitlab.example.test"
    postgresql_host     = "postgres.example.test"
    postgresql_database = "gitlabhq_production"
    postgresql_username = "gitlab"
    s3_region           = "us-east-1"
  }

  assert {
    condition     = output.vpc_id == "vpc-cleanup-placeholder"
    error_message = "Cleanup run should switch to provided external network inputs."
  }
}
