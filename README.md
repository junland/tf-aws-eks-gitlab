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
- This module provisions a single-node ElastiCache topology (no replica/failover configuration)
- This module supports `elasticache_snapshot_retention_limit = 0` only for the current topology

Key inputs:

- `enable_elasticache`
- `elasticache_node_type`
- `elasticache_engine_version`
- `elasticache_subnet_group_name` (optional reuse)
- `elasticache_security_group_ids` (optional additional groups attached alongside module-managed ElastiCache security group)
- `elasticache_allowed_cidrs` (optional additional ingress CIDRs)
- `elasticache_transit_encryption_enabled` (switches GitLab Redis connection to TLS/`rediss` while using the configured Redis listener port)
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

## Terraform Docs

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.100.0, < 6.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.17.0, < 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.2.1, < 4.0.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.2.1 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.4.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eks_addon.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_elasticache_replication_group.gitlab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.gitlab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.gitlab_irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.gitlab_irsa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.elasticache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.gitlab_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_security_group_egress_rule.elasticache_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.gitlab_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.elasticache_from_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.elasticache_from_eks_nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.gitlab_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.gitlab_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [helm_release.gitlab](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.gitlab](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.object_storage](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.postgresql](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster_auth.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy_document.eks_cluster_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.eks_node_group_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.gitlab_irsa_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.gitlab_irsa_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [tls_certificate.eks_oidc](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region where resources are deployed | `string` | `"us-east-1"` | no |
| <a name="input_azs"></a> [azs](#input\_azs) | Availability zones for subnets when create\_vpc is true | `list(string)` | <pre>[<br/>  "us-east-1a",<br/>  "us-east-1b",<br/>  "us-east-1c"<br/>]</pre> | no |
| <a name="input_cluster_addons"></a> [cluster\_addons](#input\_cluster\_addons) | EKS cluster add-ons used to create aws\_eks\_addon resources | <pre>map(object({<br/>    addon_version               = optional(string)<br/>    configuration_values        = optional(string)<br/>    preserve                    = optional(bool)<br/>    resolve_conflicts           = optional(string)<br/>    resolve_conflicts_on_create = optional(string)<br/>    resolve_conflicts_on_update = optional(string)<br/>    service_account_role_arn    = optional(string)<br/>  }))</pre> | <pre>{<br/>  "coredns": {},<br/>  "eks-pod-identity-agent": {},<br/>  "kube-proxy": {},<br/>  "vpc-cni": {}<br/>}</pre> | no |
| <a name="input_cluster_enabled_log_types"></a> [cluster\_enabled\_log\_types](#input\_cluster\_enabled\_log\_types) | EKS control plane logs to enable | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_cluster_endpoint_private_access"></a> [cluster\_endpoint\_private\_access](#input\_cluster\_endpoint\_private\_access) | Whether the EKS API endpoint is privately accessible | `bool` | `true` | no |
| <a name="input_cluster_endpoint_public_access"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | Whether the EKS API endpoint is publicly accessible | `bool` | `true` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name. If null, generated from name\_prefix | `string` | `null` | no |
| <a name="input_cluster_service_ipv4_cidr"></a> [cluster\_service\_ipv4\_cidr](#input\_cluster\_service\_ipv4\_cidr) | CIDR block for Kubernetes service IPs | `string` | `null` | no |
| <a name="input_create_gitlab_security_group"></a> [create\_gitlab\_security\_group](#input\_create\_gitlab\_security\_group) | Create dedicated security group and attach it to GitLab load balancer | `bool` | `false` | no |
| <a name="input_create_irsa_role"></a> [create\_irsa\_role](#input\_create\_irsa\_role) | Create an IAM role for service account access to object storage | `bool` | `true` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Whether this module should create the VPC and subnets | `bool` | `true` | no |
| <a name="input_deploy_gitlab"></a> [deploy\_gitlab](#input\_deploy\_gitlab) | Whether to deploy GitLab Helm release | `bool` | `true` | no |
| <a name="input_eks_managed_node_groups"></a> [eks\_managed\_node\_groups](#input\_eks\_managed\_node\_groups) | Managed node group configuration used to create aws\_eks\_node\_group resources | <pre>map(object({<br/>    instance_types             = optional(list(string))<br/>    ami_type                   = optional(string)<br/>    min_size                   = optional(number)<br/>    desired_size               = optional(number)<br/>    max_size                   = optional(number)<br/>    capacity_type              = optional(string)<br/>    disk_size                  = optional(number)<br/>    labels                     = optional(map(string))<br/>    release_version            = optional(string)<br/>    version                    = optional(string)<br/>    max_unavailable            = optional(number)<br/>    max_unavailable_percentage = optional(number)<br/>  }))</pre> | <pre>{<br/>  "default": {<br/>    "ami_type": "AL2023_x86_64_STANDARD",<br/>    "capacity_type": "ON_DEMAND",<br/>    "desired_size": 3,<br/>    "disk_size": 100,<br/>    "instance_types": [<br/>      "m6i.large"<br/>    ],<br/>    "max_size": 6,<br/>    "min_size": 2<br/>  }<br/>}</pre> | no |
| <a name="input_elasticache_allowed_cidrs"></a> [elasticache\_allowed\_cidrs](#input\_elasticache\_allowed\_cidrs) | Additional CIDRs allowed to connect to ElastiCache Redis | `list(string)` | `[]` | no |
| <a name="input_elasticache_apply_immediately"></a> [elasticache\_apply\_immediately](#input\_elasticache\_apply\_immediately) | Apply ElastiCache modifications immediately | `bool` | `true` | no |
| <a name="input_elasticache_at_rest_encryption_enabled"></a> [elasticache\_at\_rest\_encryption\_enabled](#input\_elasticache\_at\_rest\_encryption\_enabled) | Enable at-rest encryption for ElastiCache | `bool` | `true` | no |
| <a name="input_elasticache_auth_token"></a> [elasticache\_auth\_token](#input\_elasticache\_auth\_token) | Auth token for ElastiCache Redis (currently unsupported by this module and must remain null) | `string` | `null` | no |
| <a name="input_elasticache_engine_version"></a> [elasticache\_engine\_version](#input\_elasticache\_engine\_version) | ElastiCache Redis engine version | `string` | `"7.1"` | no |
| <a name="input_elasticache_maintenance_window"></a> [elasticache\_maintenance\_window](#input\_elasticache\_maintenance\_window) | Preferred maintenance window for ElastiCache (for example sun:05:00-sun:06:00) | `string` | `null` | no |
| <a name="input_elasticache_node_type"></a> [elasticache\_node\_type](#input\_elasticache\_node\_type) | ElastiCache node type for Redis | `string` | `"cache.t4g.small"` | no |
| <a name="input_elasticache_parameter_group_name"></a> [elasticache\_parameter\_group\_name](#input\_elasticache\_parameter\_group\_name) | Optional ElastiCache parameter group name | `string` | `null` | no |
| <a name="input_elasticache_port"></a> [elasticache\_port](#input\_elasticache\_port) | Redis port for ElastiCache and GitLab external Redis connection | `number` | `6379` | no |
| <a name="input_elasticache_replication_group_id"></a> [elasticache\_replication\_group\_id](#input\_elasticache\_replication\_group\_id) | Replication group ID for ElastiCache. If null, generated from cluster name | `string` | `null` | no |
| <a name="input_elasticache_security_group_ids"></a> [elasticache\_security\_group\_ids](#input\_elasticache\_security\_group\_ids) | Additional security group IDs attached to ElastiCache alongside the module-managed security group | `list(string)` | `[]` | no |
| <a name="input_elasticache_snapshot_retention_limit"></a> [elasticache\_snapshot\_retention\_limit](#input\_elasticache\_snapshot\_retention\_limit) | Number of days to retain ElastiCache snapshots (currently only 0 is supported) | `number` | `0` | no |
| <a name="input_elasticache_subnet_group_name"></a> [elasticache\_subnet\_group\_name](#input\_elasticache\_subnet\_group\_name) | Existing ElastiCache subnet group name. If null, module creates one | `string` | `null` | no |
| <a name="input_elasticache_transit_encryption_enabled"></a> [elasticache\_transit\_encryption\_enabled](#input\_elasticache\_transit\_encryption\_enabled) | Enable in-transit encryption for ElastiCache | `bool` | `false` | no |
| <a name="input_enable_cluster_creator_admin_permissions"></a> [enable\_cluster\_creator\_admin\_permissions](#input\_enable\_cluster\_creator\_admin\_permissions) | Grant cluster-admin permissions to the Terraform caller | `bool` | `true` | no |
| <a name="input_enable_elasticache"></a> [enable\_elasticache](#input\_enable\_elasticache) | Create and configure an ElastiCache Redis replication group for GitLab | `bool` | `false` | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Whether to enable NAT gateway(s) when create\_vpc is true | `bool` | `true` | no |
| <a name="input_gitlab_chart_version"></a> [gitlab\_chart\_version](#input\_gitlab\_chart\_version) | GitLab Helm chart version | `string` | `"8.4.1"` | no |
| <a name="input_gitlab_configure_cert_manager"></a> [gitlab\_configure\_cert\_manager](#input\_gitlab\_configure\_cert\_manager) | Whether GitLab chart should configure cert-manager integration | `bool` | `false` | no |
| <a name="input_gitlab_create_namespace"></a> [gitlab\_create\_namespace](#input\_gitlab\_create\_namespace) | Whether the module should create the GitLab namespace | `bool` | `true` | no |
| <a name="input_gitlab_edition"></a> [gitlab\_edition](#input\_gitlab\_edition) | GitLab edition (ce or ee) | `string` | `"ce"` | no |
| <a name="input_gitlab_enable_registry"></a> [gitlab\_enable\_registry](#input\_gitlab\_enable\_registry) | Enable GitLab container registry | `bool` | `true` | no |
| <a name="input_gitlab_extra_values"></a> [gitlab\_extra\_values](#input\_gitlab\_extra\_values) | Additional raw YAML values merged after module-managed values | `list(string)` | `[]` | no |
| <a name="input_gitlab_helm_atomic"></a> [gitlab\_helm\_atomic](#input\_gitlab\_helm\_atomic) | Enable atomic Helm upgrades/installs | `bool` | `true` | no |
| <a name="input_gitlab_helm_max_history"></a> [gitlab\_helm\_max\_history](#input\_gitlab\_helm\_max\_history) | Maximum Helm revision history | `number` | `10` | no |
| <a name="input_gitlab_helm_timeout"></a> [gitlab\_helm\_timeout](#input\_gitlab\_helm\_timeout) | GitLab Helm timeout in seconds | `number` | `1800` | no |
| <a name="input_gitlab_hostname"></a> [gitlab\_hostname](#input\_gitlab\_hostname) | Base domain for GitLab hostnames | `string` | n/a | yes |
| <a name="input_gitlab_ingress_annotations"></a> [gitlab\_ingress\_annotations](#input\_gitlab\_ingress\_annotations) | Additional ingress annotations for GitLab | `map(string)` | `{}` | no |
| <a name="input_gitlab_ingress_cidrs"></a> [gitlab\_ingress\_cidrs](#input\_gitlab\_ingress\_cidrs) | Allowed CIDRs for GitLab ingress load balancer | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_gitlab_ingress_class"></a> [gitlab\_ingress\_class](#input\_gitlab\_ingress\_class) | Ingress class used by GitLab | `string` | `"nginx"` | no |
| <a name="input_gitlab_install_certmanager"></a> [gitlab\_install\_certmanager](#input\_gitlab\_install\_certmanager) | Install bundled cert-manager from chart | `bool` | `false` | no |
| <a name="input_gitlab_install_nginx_ingress"></a> [gitlab\_install\_nginx\_ingress](#input\_gitlab\_install\_nginx\_ingress) | Install bundled nginx-ingress from chart | `bool` | `true` | no |
| <a name="input_gitlab_install_prometheus"></a> [gitlab\_install\_prometheus](#input\_gitlab\_install\_prometheus) | Install Prometheus stack from the chart | `bool` | `false` | no |
| <a name="input_gitlab_install_runner"></a> [gitlab\_install\_runner](#input\_gitlab\_install\_runner) | Install GitLab Runner with the chart | `bool` | `false` | no |
| <a name="input_gitlab_irsa_role_arn"></a> [gitlab\_irsa\_role\_arn](#input\_gitlab\_irsa\_role\_arn) | Existing IRSA role ARN to use for GitLab service accounts | `string` | `null` | no |
| <a name="input_gitlab_namespace"></a> [gitlab\_namespace](#input\_gitlab\_namespace) | Kubernetes namespace for GitLab | `string` | `"gitlab"` | no |
| <a name="input_gitlab_release_name"></a> [gitlab\_release\_name](#input\_gitlab\_release\_name) | Helm release name for GitLab | `string` | `"gitlab"` | no |
| <a name="input_gitlab_service_account_annotations"></a> [gitlab\_service\_account\_annotations](#input\_gitlab\_service\_account\_annotations) | Additional annotations to apply to GitLab service accounts | `map(string)` | `{}` | no |
| <a name="input_gitlab_service_annotations"></a> [gitlab\_service\_annotations](#input\_gitlab\_service\_annotations) | Service annotations for nginx-ingress controller | `map(string)` | `{}` | no |
| <a name="input_gitlab_service_type"></a> [gitlab\_service\_type](#input\_gitlab\_service\_type) | Service type for nginx-ingress controller | `string` | `"LoadBalancer"` | no |
| <a name="input_gitlab_sidekiq_max_replicas"></a> [gitlab\_sidekiq\_max\_replicas](#input\_gitlab\_sidekiq\_max\_replicas) | Maximum Sidekiq replicas | `number` | `10` | no |
| <a name="input_gitlab_sidekiq_min_replicas"></a> [gitlab\_sidekiq\_min\_replicas](#input\_gitlab\_sidekiq\_min\_replicas) | Minimum Sidekiq replicas | `number` | `2` | no |
| <a name="input_gitlab_ssh_hostname"></a> [gitlab\_ssh\_hostname](#input\_gitlab\_ssh\_hostname) | SSH hostname for GitLab Shell; if null, a default is generated | `string` | `null` | no |
| <a name="input_gitlab_tls_enabled"></a> [gitlab\_tls\_enabled](#input\_gitlab\_tls\_enabled) | Enable TLS in GitLab ingress | `bool` | `true` | no |
| <a name="input_gitlab_tls_secret_name"></a> [gitlab\_tls\_secret\_name](#input\_gitlab\_tls\_secret\_name) | TLS secret name used by GitLab ingress | `string` | `null` | no |
| <a name="input_gitlab_webservice_max_replicas"></a> [gitlab\_webservice\_max\_replicas](#input\_gitlab\_webservice\_max\_replicas) | Maximum webservice replicas | `number` | `10` | no |
| <a name="input_gitlab_webservice_min_replicas"></a> [gitlab\_webservice\_min\_replicas](#input\_gitlab\_webservice\_min\_replicas) | Minimum webservice replicas | `number` | `2` | no |
| <a name="input_irsa_policy_json"></a> [irsa\_policy\_json](#input\_irsa\_policy\_json) | Custom IAM policy JSON for the IRSA role. If null, module creates scoped S3 access policy | `string` | `null` | no |
| <a name="input_irsa_role_name"></a> [irsa\_role\_name](#input\_irsa\_role\_name) | Name for the optional IRSA role | `string` | `null` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version for EKS | `string` | `"1.30"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix used for naming AWS and Kubernetes resources | `string` | `"gitlab"` | no |
| <a name="input_one_nat_gateway_per_az"></a> [one\_nat\_gateway\_per\_az](#input\_one\_nat\_gateway\_per\_az) | Use one NAT gateway per availability zone | `bool` | `false` | no |
| <a name="input_postgresql_database"></a> [postgresql\_database](#input\_postgresql\_database) | External PostgreSQL database name | `string` | n/a | yes |
| <a name="input_postgresql_existing_secret_key"></a> [postgresql\_existing\_secret\_key](#input\_postgresql\_existing\_secret\_key) | Key in Kubernetes secret containing PostgreSQL password | `string` | `"password"` | no |
| <a name="input_postgresql_existing_secret_name"></a> [postgresql\_existing\_secret\_name](#input\_postgresql\_existing\_secret\_name) | Existing Kubernetes secret name with PostgreSQL password | `string` | `null` | no |
| <a name="input_postgresql_host"></a> [postgresql\_host](#input\_postgresql\_host) | External PostgreSQL host | `string` | n/a | yes |
| <a name="input_postgresql_password"></a> [postgresql\_password](#input\_postgresql\_password) | External PostgreSQL password (used only when creating a Kubernetes secret) | `string` | `null` | no |
| <a name="input_postgresql_port"></a> [postgresql\_port](#input\_postgresql\_port) | External PostgreSQL port | `number` | `5432` | no |
| <a name="input_postgresql_username"></a> [postgresql\_username](#input\_postgresql\_username) | External PostgreSQL username | `string` | n/a | yes |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | Private subnet CIDRs when create\_vpc is true | `list(string)` | <pre>[<br/>  "10.0.1.0/24",<br/>  "10.0.2.0/24",<br/>  "10.0.3.0/24"<br/>]</pre> | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Existing private subnet IDs when create\_vpc is false | `list(string)` | `[]` | no |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | Public subnet CIDRs when create\_vpc is true | `list(string)` | <pre>[<br/>  "10.0.101.0/24",<br/>  "10.0.102.0/24",<br/>  "10.0.103.0/24"<br/>]</pre> | no |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Existing public subnet IDs when create\_vpc is false | `list(string)` | `[]` | no |
| <a name="input_s3_access_key"></a> [s3\_access\_key](#input\_s3\_access\_key) | S3 access key (used only when creating a Kubernetes secret and IAM profile auth is disabled) | `string` | `null` | no |
| <a name="input_s3_buckets"></a> [s3\_buckets](#input\_s3\_buckets) | GitLab object storage bucket names | <pre>object({<br/>    artifacts        = optional(string)<br/>    uploads          = optional(string)<br/>    packages         = optional(string)<br/>    lfs              = optional(string)<br/>    terraform_state  = optional(string)<br/>    dependency_proxy = optional(string)<br/>    ci_secure_files  = optional(string)<br/>    external_diffs   = optional(string)<br/>    backups          = optional(string)<br/>    tmp              = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_s3_endpoint"></a> [s3\_endpoint](#input\_s3\_endpoint) | Custom S3 endpoint URL for S3-compatible object storage | `string` | `null` | no |
| <a name="input_s3_existing_secret_key"></a> [s3\_existing\_secret\_key](#input\_s3\_existing\_secret\_key) | Key in Kubernetes secret containing object storage connection YAML | `string` | `"connection"` | no |
| <a name="input_s3_existing_secret_name"></a> [s3\_existing\_secret\_name](#input\_s3\_existing\_secret\_name) | Existing Kubernetes secret with object storage connection YAML | `string` | `null` | no |
| <a name="input_s3_force_path_style"></a> [s3\_force\_path\_style](#input\_s3\_force\_path\_style) | Use path-style S3 requests | `bool` | `true` | no |
| <a name="input_s3_region"></a> [s3\_region](#input\_s3\_region) | S3 object storage region | `string` | n/a | yes |
| <a name="input_s3_secret_key"></a> [s3\_secret\_key](#input\_s3\_secret\_key) | S3 secret key (used only when creating a Kubernetes secret and IAM profile auth is disabled) | `string` | `null` | no |
| <a name="input_s3_use_iam_profile"></a> [s3\_use\_iam\_profile](#input\_s3\_use\_iam\_profile) | Use IAM role credentials from pod identity instead of static access keys | `bool` | `true` | no |
| <a name="input_single_nat_gateway"></a> [single\_nat\_gateway](#input\_single\_nat\_gateway) | Use a single shared NAT gateway when create\_vpc is true | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to AWS resources | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | VPC CIDR block when create\_vpc is true | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC ID when create\_vpc is false | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | EKS cluster endpoint |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | EKS cluster name |
| <a name="output_cluster_oidc_provider_arn"></a> [cluster\_oidc\_provider\_arn](#output\_cluster\_oidc\_provider\_arn) | OIDC provider ARN associated with the cluster |
| <a name="output_elasticache_primary_endpoint_address"></a> [elasticache\_primary\_endpoint\_address](#output\_elasticache\_primary\_endpoint\_address) | Primary endpoint address for ElastiCache Redis when enabled |
| <a name="output_elasticache_replication_group_id"></a> [elasticache\_replication\_group\_id](#output\_elasticache\_replication\_group\_id) | ElastiCache replication group ID when enabled |
| <a name="output_elasticache_transit_encryption_enabled"></a> [elasticache\_transit\_encryption\_enabled](#output\_elasticache\_transit\_encryption\_enabled) | Whether ElastiCache transit encryption is enabled |
| <a name="output_gitlab_irsa_role_arn"></a> [gitlab\_irsa\_role\_arn](#output\_gitlab\_irsa\_role\_arn) | IRSA role ARN used by GitLab service accounts |
| <a name="output_gitlab_namespace"></a> [gitlab\_namespace](#output\_gitlab\_namespace) | GitLab namespace |
| <a name="output_gitlab_redis_auth_enabled"></a> [gitlab\_redis\_auth\_enabled](#output\_gitlab\_redis\_auth\_enabled) | Whether Redis auth is enabled in GitLab chart values for external Redis |
| <a name="output_gitlab_redis_chart_install"></a> [gitlab\_redis\_chart\_install](#output\_gitlab\_redis\_chart\_install) | Whether bundled Redis remains enabled in the GitLab chart values |
| <a name="output_gitlab_redis_external_host_configured"></a> [gitlab\_redis\_external\_host\_configured](#output\_gitlab\_redis\_external\_host\_configured) | Whether external Redis host is configured in GitLab chart values |
| <a name="output_gitlab_redis_external_port"></a> [gitlab\_redis\_external\_port](#output\_gitlab\_redis\_external\_port) | Configured external Redis port in GitLab chart values |
| <a name="output_gitlab_redis_external_rediss_enabled"></a> [gitlab\_redis\_external\_rediss\_enabled](#output\_gitlab\_redis\_external\_rediss\_enabled) | Whether rediss/TLS is enabled for external Redis in GitLab chart values |
| <a name="output_gitlab_redis_external_scheme"></a> [gitlab\_redis\_external\_scheme](#output\_gitlab\_redis\_external\_scheme) | Configured external Redis scheme in GitLab chart values |
| <a name="output_gitlab_release_name"></a> [gitlab\_release\_name](#output\_gitlab\_release\_name) | GitLab Helm release name |
| <a name="output_object_storage_secret_name"></a> [object\_storage\_secret\_name](#output\_object\_storage\_secret\_name) | Kubernetes secret name for object storage connection |
| <a name="output_postgresql_secret_name"></a> [postgresql\_secret\_name](#output\_postgresql\_secret\_name) | Kubernetes secret name for PostgreSQL credentials |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Private subnet IDs used by the cluster |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | Public subnet IDs used by the cluster |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID used by the cluster |
<!-- END_TF_DOCS -->
