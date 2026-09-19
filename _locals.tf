locals {
  cluster_name = coalesce(var.cluster_name, "${var.name_prefix}-eks")

  tags = merge(
    {
      "terraform-module" = "gitlab-eks"
      "managed-by"       = "terraform"
    },
    var.tags
  )

  vpc_id = var.create_vpc ? aws_vpc.this[0].id : var.vpc_id

  private_subnet_ids = var.create_vpc ? aws_subnet.private[*].id : var.private_subnet_ids
  public_subnet_ids  = var.create_vpc ? aws_subnet.public[*].id : var.public_subnet_ids

  s3_bucket_names = {
    artifacts        = coalesce(var.s3_buckets.artifacts, "${local.cluster_name}-gitlab-artifacts")
    uploads          = coalesce(var.s3_buckets.uploads, "${local.cluster_name}-gitlab-uploads")
    packages         = coalesce(var.s3_buckets.packages, "${local.cluster_name}-gitlab-packages")
    lfs              = coalesce(var.s3_buckets.lfs, "${local.cluster_name}-gitlab-lfs")
    terraform_state  = coalesce(var.s3_buckets.terraform_state, "${local.cluster_name}-gitlab-terraform-state")
    dependency_proxy = coalesce(var.s3_buckets.dependency_proxy, "${local.cluster_name}-gitlab-dependency-proxy")
    ci_secure_files  = coalesce(var.s3_buckets.ci_secure_files, "${local.cluster_name}-gitlab-secure-files")
    external_diffs   = coalesce(var.s3_buckets.external_diffs, "${local.cluster_name}-gitlab-external-diffs")
    backups          = coalesce(var.s3_buckets.backups, "${local.cluster_name}-gitlab-backups")
    tmp              = coalesce(var.s3_buckets.tmp, "${local.cluster_name}-gitlab-tmp")
  }

  postgresql_secret_name     = coalesce(var.postgresql_existing_secret_name, "${var.gitlab_release_name}-postgresql")
  object_storage_secret_name = coalesce(var.s3_existing_secret_name, "${var.gitlab_release_name}-object-storage")

  create_postgresql_secret = var.postgresql_existing_secret_name == null && var.postgresql_password != null

  create_object_storage_secret = (
    var.s3_existing_secret_name == null && (
      var.s3_use_iam_profile ||
      (
        var.s3_access_key != null &&
        var.s3_secret_key != null
      )
    )
  )

  object_storage_connection_yaml = yamlencode(merge(
    {
      provider              = "AWS"
      region                = var.s3_region
      use_iam_profile       = var.s3_use_iam_profile
      aws_signature_version = 4
      path_style            = var.s3_force_path_style
    },
    var.s3_endpoint != null ? { endpoint = var.s3_endpoint } : {},
    var.s3_use_iam_profile ? {} : {
      aws_access_key_id     = var.s3_access_key
      aws_secret_access_key = var.s3_secret_key
    }
  ))

  manage_irsa_role = var.create_irsa_role && var.gitlab_irsa_role_arn == null

  irsa_role_name = coalesce(var.irsa_role_name, "${local.cluster_name}-gitlab-irsa")

  gitlab_service_account_annotations = merge(
    var.gitlab_service_account_annotations,
    local.manage_irsa_role ? { "eks.amazonaws.com/role-arn" = aws_iam_role.gitlab_irsa[0].arn } : {},
    var.gitlab_irsa_role_arn != null ? { "eks.amazonaws.com/role-arn" = var.gitlab_irsa_role_arn } : {}
  )

  gitlab_lb_security_group_annotation = var.create_gitlab_security_group ? {
    "service.beta.kubernetes.io/aws-load-balancer-security-groups" = aws_security_group.gitlab_ingress[0].id
  } : {}

  gitlab_hostname_root = replace(var.gitlab_hostname, "https://", "")

  gitlab_helm_values = {
    global = {
      edition = var.gitlab_edition

      hosts = {
        domain = local.gitlab_hostname_root
        ssh    = coalesce(var.gitlab_ssh_hostname, "gitlab-ssh.${local.gitlab_hostname_root}")
      }

      ingress = {
        class                = var.gitlab_ingress_class
        configureCertmanager = var.gitlab_configure_cert_manager
        annotations          = var.gitlab_ingress_annotations
        tls = {
          enabled    = var.gitlab_tls_enabled
          secretName = var.gitlab_tls_secret_name
        }
      }

      serviceAccount = {
        annotations = local.gitlab_service_account_annotations
      }

      psql = {
        host     = var.postgresql_host
        port     = var.postgresql_port
        database = var.postgresql_database
        username = var.postgresql_username
        password = {
          secret = local.postgresql_secret_name
          key    = var.postgresql_existing_secret_key
        }
      }

      appConfig = {
        object_store = {
          enabled = true
          connection = {
            secret = local.object_storage_secret_name
            key    = var.s3_existing_secret_key
          }
        }

        artifacts = {
          bucket = local.s3_bucket_names.artifacts
        }
        uploads = {
          bucket = local.s3_bucket_names.uploads
        }
        packages = {
          bucket = local.s3_bucket_names.packages
        }
        lfs = {
          bucket = local.s3_bucket_names.lfs
        }
        terraformState = {
          enabled = true
          bucket  = local.s3_bucket_names.terraform_state
        }
        dependencyProxy = {
          enabled = true
          bucket  = local.s3_bucket_names.dependency_proxy
        }
        ciSecureFiles = {
          enabled = true
          bucket  = local.s3_bucket_names.ci_secure_files
        }
        externalDiffs = {
          enabled = true
          bucket  = local.s3_bucket_names.external_diffs
        }
        backups = {
          bucket    = local.s3_bucket_names.backups
          tmpBucket = local.s3_bucket_names.tmp
        }
      }
    }

    postgresql = {
      install = false
    }

    minio = {
      enabled = false
    }

    certmanager = {
      install = var.gitlab_install_certmanager
    }

    "nginx-ingress" = {
      enabled = var.gitlab_install_nginx_ingress
      controller = {
        service = {
          type                     = var.gitlab_service_type
          annotations              = merge(var.gitlab_service_annotations, local.gitlab_lb_security_group_annotation)
          loadBalancerSourceRanges = var.gitlab_ingress_cidrs
        }
      }
    }

    registry = {
      enabled = var.gitlab_enable_registry
    }

    gitlab = {
      webservice = {
        minReplicas = var.gitlab_webservice_min_replicas
        maxReplicas = var.gitlab_webservice_max_replicas
      }
      sidekiq = {
        minReplicas = var.gitlab_sidekiq_min_replicas
        maxReplicas = var.gitlab_sidekiq_max_replicas
      }
      toolbox = {
        backups = {
          objectStorage = {
            config = {
              secret = local.object_storage_secret_name
              key    = var.s3_existing_secret_key
            }
          }
        }
      }
    }

    "gitlab-runner" = {
      install = var.gitlab_install_runner
    }

    prometheus = {
      install = var.gitlab_install_prometheus
    }
  }
}
