variable "aws_region" {
  description = "AWS region where resources are deployed"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for naming AWS and Kubernetes resources"
  type        = string
  default     = "gitlab"
}

variable "cluster_name" {
  description = "EKS cluster name. If null, generated from name_prefix"
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.36"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly accessible"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Whether the EKS API endpoint is privately accessible"
  type        = bool
  default     = true
}

variable "cluster_enabled_log_types" {
  description = "EKS control plane logs to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_service_ipv4_cidr" {
  description = "CIDR block for Kubernetes service IPs"
  type        = string
  default     = null
}

variable "cluster_authentication_mode" {
  description = "Authentication mode for the EKS cluster access API"
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API", "API_AND_CONFIG_MAP"], var.cluster_authentication_mode)
    error_message = "cluster_authentication_mode must be API or API_AND_CONFIG_MAP."
  }
}

variable "enable_cluster_encryption" {
  description = "Whether to enable EKS secret envelope encryption"
  type        = bool
  default     = false
}

variable "cluster_encryption_key_arn" {
  description = "Existing KMS key ARN for EKS secret envelope encryption. If null and encryption is enabled, the module creates one."
  type        = string
  default     = null

  validation {
    condition = var.cluster_encryption_key_arn == null ? true : (
      trimspace(var.cluster_encryption_key_arn) == "" || can(regex(
        "^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/[0-9A-Fa-f-]+$",
        var.cluster_encryption_key_arn
      ))
    )
    error_message = "cluster_encryption_key_arn must be a valid KMS key ARN."
  }
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant cluster-admin permissions to the Terraform caller"
  type        = bool
  default     = true
}

variable "create_vpc" {
  description = "Whether this module should create the VPC and subnets"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "Existing VPC ID when create_vpc is false"
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "VPC CIDR block when create_vpc is true"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones for subnets when create_vpc is true"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs when create_vpc is true"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs when create_vpc is true"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "private_subnet_ids" {
  description = "Existing private subnet IDs when create_vpc is false"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Existing public subnet IDs when create_vpc is false"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Whether to enable NAT gateway(s) when create_vpc is true"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway when create_vpc is true"
  type        = bool
  default     = true
}

variable "one_nat_gateway_per_az" {
  description = "Use one NAT gateway per availability zone"
  type        = bool
  default     = false
}

variable "eks_managed_node_groups" {
  description = "Managed node group configuration used to create aws_eks_node_group resources"
  type = map(object({
    instance_types             = optional(list(string))
    ami_type                   = optional(string)
    min_size                   = optional(number)
    desired_size               = optional(number)
    max_size                   = optional(number)
    capacity_type              = optional(string)
    disk_size                  = optional(number)
    labels                     = optional(map(string))
    release_version            = optional(string)
    version                    = optional(string)
    max_unavailable            = optional(number)
    max_unavailable_percentage = optional(number)
  }))
  default = {
    default = {
      instance_types = ["m6i.large"]
      ami_type       = "AL2023_x86_64_STANDARD"
      min_size       = 2
      desired_size   = 3
      max_size       = 6
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
    }
  }
}

variable "cluster_addons" {
  description = "EKS cluster add-ons used to create aws_eks_addon resources"
  type = map(object({
    addon_version               = optional(string)
    configuration_values        = optional(string)
    preserve                    = optional(bool)
    resolve_conflicts           = optional(string)
    resolve_conflicts_on_create = optional(string)
    resolve_conflicts_on_update = optional(string)
    service_account_role_arn    = optional(string)
  }))
  default = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }
}

variable "deploy_gitlab" {
  description = "Whether to deploy GitLab Helm release"
  type        = bool
  default     = true
}

variable "gitlab_release_name" {
  description = "Helm release name for GitLab"
  type        = string
  default     = "gitlab"
}

variable "gitlab_namespace" {
  description = "Kubernetes namespace for GitLab"
  type        = string
  default     = "gitlab"
}

variable "gitlab_create_namespace" {
  description = "Whether the module should create the GitLab namespace"
  type        = bool
  default     = true
}

variable "gitlab_chart_version" {
  description = "GitLab Helm chart version"
  type        = string
  default     = "8.4.1"
}

variable "gitlab_hostname" {
  description = "Base domain for GitLab hostnames"
  type        = string
}

variable "gitlab_ssh_hostname" {
  description = "SSH hostname for GitLab Shell; if null, a default is generated"
  type        = string
  default     = null
}

variable "gitlab_ingress_class" {
  description = "Ingress class used by GitLab"
  type        = string
  default     = "nginx"
}

variable "gitlab_tls_enabled" {
  description = "Enable TLS in GitLab ingress"
  type        = bool
  default     = true
}

variable "gitlab_tls_secret_name" {
  description = "TLS secret name used by GitLab ingress"
  type        = string
  default     = null
}

variable "gitlab_configure_cert_manager" {
  description = "Whether GitLab chart should configure cert-manager integration"
  type        = bool
  default     = false
}

variable "gitlab_ingress_annotations" {
  description = "Additional ingress annotations for GitLab"
  type        = map(string)
  default     = {}
}

variable "gitlab_ingress_cidrs" {
  description = "Allowed CIDRs for GitLab ingress load balancer"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "gitlab_service_type" {
  description = "Service type for nginx-ingress controller"
  type        = string
  default     = "LoadBalancer"
}

variable "gitlab_service_annotations" {
  description = "Service annotations for nginx-ingress controller"
  type        = map(string)
  default     = {}
}

variable "create_gitlab_security_group" {
  description = "Create dedicated security group and attach it to GitLab load balancer"
  type        = bool
  default     = false
}

variable "gitlab_enable_registry" {
  description = "Enable GitLab container registry"
  type        = bool
  default     = true
}

variable "gitlab_install_runner" {
  description = "Install GitLab Runner with the chart"
  type        = bool
  default     = false
}

variable "gitlab_install_prometheus" {
  description = "Install Prometheus stack from the chart"
  type        = bool
  default     = false
}

variable "gitlab_install_nginx_ingress" {
  description = "Install bundled nginx-ingress from chart"
  type        = bool
  default     = true
}

variable "gitlab_install_certmanager" {
  description = "Install bundled cert-manager from chart"
  type        = bool
  default     = false
}

variable "gitlab_webservice_min_replicas" {
  description = "Minimum webservice replicas"
  type        = number
  default     = 2
}

variable "gitlab_webservice_max_replicas" {
  description = "Maximum webservice replicas"
  type        = number
  default     = 10
}

variable "gitlab_sidekiq_min_replicas" {
  description = "Minimum Sidekiq replicas"
  type        = number
  default     = 2
}

variable "gitlab_sidekiq_max_replicas" {
  description = "Maximum Sidekiq replicas"
  type        = number
  default     = 10
}

variable "gitlab_edition" {
  description = "GitLab edition (ce or ee)"
  type        = string
  default     = "ce"
}

variable "gitlab_helm_atomic" {
  description = "Enable atomic Helm upgrades/installs"
  type        = bool
  default     = true
}

variable "gitlab_helm_timeout" {
  description = "GitLab Helm timeout in seconds"
  type        = number
  default     = 1800
}

variable "gitlab_helm_max_history" {
  description = "Maximum Helm revision history"
  type        = number
  default     = 10
}

variable "gitlab_extra_values" {
  description = "Additional raw YAML values merged after module-managed values"
  type        = list(string)
  default     = []
}

variable "postgresql_host" {
  description = "External PostgreSQL host"
  type        = string
}

variable "postgresql_port" {
  description = "External PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgresql_database" {
  description = "External PostgreSQL database name"
  type        = string
}

variable "postgresql_username" {
  description = "External PostgreSQL username"
  type        = string
}

variable "postgresql_password" {
  description = "External PostgreSQL password (used only when creating a Kubernetes secret)"
  type        = string
  sensitive   = true
  default     = null
}

variable "postgresql_existing_secret_name" {
  description = "Existing Kubernetes secret name with PostgreSQL password"
  type        = string
  default     = null
}

variable "postgresql_existing_secret_key" {
  description = "Key in Kubernetes secret containing PostgreSQL password"
  type        = string
  default     = "password"
}

variable "s3_region" {
  description = "S3 object storage region"
  type        = string
}

variable "s3_endpoint" {
  description = "Custom S3 endpoint URL for S3-compatible object storage"
  type        = string
  default     = null
}

variable "s3_use_iam_profile" {
  description = "Use IAM role credentials from pod identity instead of static access keys"
  type        = bool
  default     = true
}

variable "s3_access_key" {
  description = "S3 access key (used only when creating a Kubernetes secret and IAM profile auth is disabled)"
  type        = string
  sensitive   = true
  default     = null
}

variable "s3_secret_key" {
  description = "S3 secret key (used only when creating a Kubernetes secret and IAM profile auth is disabled)"
  type        = string
  sensitive   = true
  default     = null
}

variable "s3_force_path_style" {
  description = "Use path-style S3 requests"
  type        = bool
  default     = true
}

variable "s3_existing_secret_name" {
  description = "Existing Kubernetes secret with object storage connection YAML"
  type        = string
  default     = null
}

variable "s3_existing_secret_key" {
  description = "Key in Kubernetes secret containing object storage connection YAML"
  type        = string
  default     = "connection"
}

variable "s3_buckets" {
  description = "GitLab object storage bucket names"
  type = object({
    artifacts        = optional(string)
    uploads          = optional(string)
    packages         = optional(string)
    lfs              = optional(string)
    terraform_state  = optional(string)
    dependency_proxy = optional(string)
    ci_secure_files  = optional(string)
    external_diffs   = optional(string)
    backups          = optional(string)
    tmp              = optional(string)
  })
  default = {}
}

variable "elasticache_replication_group_id" {
  description = "Replication group ID for ElastiCache. If null, generated from cluster name"
  type        = string
  default     = null
}

variable "elasticache_node_type" {
  description = "ElastiCache node type for Redis"
  type        = string
  default     = "cache.t4g.small"
}

variable "elasticache_engine_version" {
  description = "ElastiCache Redis engine version"
  type        = string
  default     = "7.1"
}

variable "elasticache_port" {
  description = "Redis port for ElastiCache and GitLab external Redis connection"
  type        = number
  default     = 6379
}

variable "elasticache_parameter_group_name" {
  description = "Optional ElastiCache parameter group name"
  type        = string
  default     = null
}

variable "elasticache_subnet_group_name" {
  description = "Existing ElastiCache subnet group name. If null, module creates one"
  type        = string
  default     = null
}

variable "elasticache_security_group_ids" {
  description = "Additional security group IDs attached to ElastiCache alongside the module-managed security group"
  type        = list(string)
  default     = []
}

variable "elasticache_allowed_cidrs" {
  description = "Additional CIDRs allowed to connect to ElastiCache Redis"
  type        = list(string)
  default     = []
}

variable "elasticache_at_rest_encryption_enabled" {
  description = "Enable at-rest encryption for ElastiCache"
  type        = bool
  default     = true
}

variable "elasticache_transit_encryption_enabled" {
  description = "Enable in-transit encryption for ElastiCache"
  type        = bool
  default     = false
}

variable "elasticache_auth_token" {
  description = "Auth token for ElastiCache Redis (currently unsupported by this module and must remain null)"
  type        = string
  sensitive   = true
  default     = null
}

variable "elasticache_apply_immediately" {
  description = "Apply ElastiCache modifications immediately"
  type        = bool
  default     = true
}

variable "elasticache_maintenance_window" {
  description = "Preferred maintenance window for ElastiCache (for example sun:05:00-sun:06:00)"
  type        = string
  default     = null
}

variable "elasticache_snapshot_retention_limit" {
  description = "Number of days to retain ElastiCache snapshots (currently only 0 is supported)"
  type        = number
  default     = 0
}

variable "create_irsa_role" {
  description = "Create an IAM role for service account access to object storage"
  type        = bool
  default     = true
}

variable "irsa_role_name" {
  description = "Name for the optional IRSA role"
  type        = string
  default     = null
}

variable "gitlab_irsa_role_arn" {
  description = "Existing IRSA role ARN to use for GitLab service accounts"
  type        = string
  default     = null
}

variable "irsa_policy_json" {
  description = "Custom IAM policy JSON for the IRSA role. If null, module creates scoped S3 access policy"
  type        = string
  default     = null
}

variable "gitlab_service_account_annotations" {
  description = "Additional annotations to apply to GitLab service accounts"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to AWS resources"
  type        = map(string)
  default     = {}
}
