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
