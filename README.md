# Terraform AWS EKS GitLab Module

Reusable Terraform module that provisions a production-ready Amazon EKS cluster and deploys GitLab with the official GitLab Helm chart.

## Features

- Provisions EKS with configurable Kubernetes version, node groups, networking, and cluster settings.
- Supports managed VPC creation or existing VPC/subnets.
- Deploys GitLab through Terraform Helm provider and official `gitlab/gitlab` chart.
- Uses external PostgreSQL and S3-compatible object storage (no database/object-storage infrastructure provisioned by this module).
- Supports Kubernetes secret references for PostgreSQL and object-storage credentials.
- Supports IAM-based object storage authentication with IRSA.
- Supports optional AWS ElastiCache Redis provisioning and GitLab Redis wiring.
- Includes production-oriented defaults and customization inputs for ingress, TLS, scaling, and chart behavior.

## Module Structure

All Terraform files use the required `_*.tf` naming convention:

- [`_versions.tf`](_versions.tf)
- [`_data.tf`](_data.tf)
- [`_vpc.tf`](_vpc.tf)
- [`_eks.tf`](_eks.tf)
- [`_iam.tf`](_iam.tf)
- [`_security_groups.tf`](_security_groups.tf)
- [`_elasticache.tf`](_elasticache.tf)
- [`_kubernetes.tf`](_kubernetes.tf)
- [`_helm.tf`](_helm.tf)
- [`_locals.tf`](_locals.tf)
- [`_variables.tf`](_variables.tf)
- [`_outputs.tf`](_outputs.tf)

## 1. AWS Prerequisites

- AWS account and IAM permissions for EKS, VPC, IAM, EC2, and related dependencies.
- Route53/DNS setup for your GitLab domain.
- SSL/TLS certificates (or cert-manager integration if enabled).
- Terraform runner with network access to AWS APIs.
- For IAM-based object-storage access: IRSA enabled with policy permitting access to GitLab buckets.

## 2. PostgreSQL Prerequisites

Provide an externally managed PostgreSQL database (for example Amazon RDS/Aurora or self-managed PostgreSQL) with:

- Hostname
- Port (default `5432`)
- Database name
- Username
- Password via Kubernetes Secret or sensitive Terraform input

Module behavior:

- `postgresql_existing_secret_name` + `postgresql_existing_secret_key` can reference an existing secret.
- If `postgresql_password` is provided and no existing secret name is set, this module creates a secret in the GitLab namespace.

## 3. S3 Prerequisites

Provide externally managed S3-compatible object storage and buckets. This module does **not** create object storage resources.

Required inputs:

- Endpoint (optional for AWS S3, required for non-AWS compatible endpoints)
- Region
- Bucket names (`s3_buckets`)
- Authentication method:
  - IAM-based (`s3_use_iam_profile = true`, optionally with IRSA), or
  - Access key/secret key via existing secret or sensitive Terraform inputs.

Module behavior:

- `s3_existing_secret_name` + `s3_existing_secret_key` can reference an existing secret with GitLab object-store connection YAML.
- If existing secret is not provided, module can create one from sensitive inputs.

## 4. Required Terraform Variables

Core required variables:

- `gitlab_hostname`
- `postgresql_host`
- `postgresql_database`
- `postgresql_username`
- `s3_region`

And one of the secret strategies for each external dependency:

- PostgreSQL: `postgresql_existing_secret_name` **or** `postgresql_password`
- S3: `s3_existing_secret_name` **or** (`s3_use_iam_profile = true`) **or** (`s3_access_key` + `s3_secret_key`)

See [`_variables.tf`](_variables.tf) for complete input definitions and defaults.

## 5. Example Usage

A full example is provided in [`examples/basic`](examples/basic).

```hcl
module "gitlab_eks" {
  source = "../../"

  aws_region      = "us-east-1"
  name_prefix     = "gitlab-prod"
  gitlab_hostname = "gitlab.example.com"

  postgresql_host                 = "gitlab-db.example.internal"
  postgresql_database             = "gitlabhq_production"
  postgresql_username             = "gitlab"
  postgresql_existing_secret_name = "gitlab-postgres"

  s3_region               = "us-east-1"
  s3_existing_secret_name = "gitlab-object-storage"
}
```

## 6. GitLab Deployment and Configuration

GitLab is deployed using `helm_release` from the Helm provider against the EKS cluster.

The module configures:

- Official GitLab chart repository (`https://charts.gitlab.io`)
- External PostgreSQL (`postgresql.install = false`)
- External object storage (`minio.enabled = false`, object-store connection secret)
- Configurable ingress/TLS/service annotations
- Optional bundled components (`nginx-ingress`, `certmanager`, `prometheus`, `gitlab-runner`)
- Scaling controls for key components (`webservice`, `sidekiq`)

Additional chart overrides can be passed with `gitlab_extra_values`.

## 7. Optional ElastiCache Redis

Set `enable_elasticache = true` to provision an ElastiCache Redis replication group and configure GitLab to use it as external Redis.

Module behavior when enabled:

- Creates (or reuses) an ElastiCache subnet group
- Creates a dedicated ElastiCache security group and allows Redis access from EKS node security group
- Configures GitLab chart `global.redis.host`/`port`
- Disables bundled chart Redis (`redis.install = false`)

Current limitation:

- This module supports unauthenticated ElastiCache Redis only (`elasticache_auth_token` must remain `null`)

Key inputs:

- `enable_elasticache`
- `elasticache_node_type`
- `elasticache_engine_version`
- `elasticache_replica_count` (supported values `0` or `1`; default `1` enables failover/Multi-AZ behavior)
- `elasticache_subnet_group_name` (optional reuse)
- `elasticache_security_group_ids` (optional additional groups attached alongside module-managed ElastiCache security group)
- `elasticache_allowed_cidrs` (optional additional ingress CIDRs)
- `elasticache_transit_encryption_enabled` (switches GitLab Redis connection to TLS/`rediss` and port `6380`)
- `elasticache_auth_token` (must remain `null`; authenticated ElastiCache is not currently supported)

## 8. Secret Handling

Sensitive values are intended to be provided by pre-created Kubernetes secrets whenever possible.

Supported patterns:

1. **Preferred**: pass existing secret references (`postgresql_existing_secret_name`, `s3_existing_secret_name`).
2. **Alternative**: pass sensitive Terraform variables (`postgresql_password`, `s3_access_key`, `s3_secret_key`) and let module create Kubernetes secrets.
3. **IAM-based object storage**: use `s3_use_iam_profile = true` and map IAM permissions via IRSA role.

> Note: Terraform state may still contain sensitive values when raw credentials are provided as variable inputs.

## 9. Customization

You can customize:

- Cluster sizing and scaling via `eks_managed_node_groups`
- Kubernetes version via `kubernetes_version`
- Network model via `create_vpc`, existing `vpc_id`, and subnet inputs
- Load balancer exposure via `gitlab_ingress_cidrs`, service/ingress annotations
- TLS/cert-manager behavior via `gitlab_tls_*` and `gitlab_configure_cert_manager`
- GitLab chart behavior with `gitlab_extra_values`
- IAM integration via `create_irsa_role`, `gitlab_irsa_role_arn`, and `irsa_policy_json`
- Redis backing service via `enable_elasticache` and `elasticache_*` inputs

## 10. CI/CD Suitability

- All settings are variable-driven for non-interactive pipeline execution.
- No local-only dependencies are required.
- Secrets can be injected from external secret managers into Kubernetes secrets before `terraform apply`.
- Module outputs expose cluster/release wiring needed by downstream automation.

## 11. Testing

Native Terraform tests live in [`tests`](tests).

- [`tests/basic.tftest.hcl`](tests/basic.tftest.hcl) verifies key input validation checks and secret-name derivation behavior.
- The test suite uses mocked providers so it can run without live AWS, Kubernetes, or Helm credentials.

Run the suite from the repository root:

```bash
terraform init
terraform test
```

For a local AWS endpoint integration smoke test with Floci:

```bash
docker compose -f docker-compose.floci.yml up -d
bash tests/run-floci.sh
docker compose -f docker-compose.floci.yml down
```

The Floci test creates and destroys the module VPC only. EKS, Kubernetes, and Helm resources require a Kubernetes control plane and remain covered by the mocked Terraform tests.
