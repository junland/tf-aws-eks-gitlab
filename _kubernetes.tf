resource "kubernetes_namespace" "gitlab" {
  count = var.deploy_gitlab && var.gitlab_create_namespace ? 1 : 0

  metadata {
    name = var.gitlab_namespace
    labels = {
      "app.kubernetes.io/name" = "gitlab"
    }
  }
}

resource "kubernetes_secret" "postgresql" {
  count = var.deploy_gitlab && local.create_postgresql_secret ? 1 : 0

  metadata {
    name      = local.postgresql_secret_name
    namespace = var.gitlab_namespace
  }

  data = {
    (var.postgresql_existing_secret_key) = local.postgresql_password
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.gitlab]
}

resource "kubernetes_secret" "object_storage" {
  count = var.deploy_gitlab && local.create_object_storage_secret ? 1 : 0

  metadata {
    name      = local.object_storage_secret_name
    namespace = var.gitlab_namespace
  }

  data = {
    (var.s3_existing_secret_key) = local.object_storage_connection_yaml
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.gitlab]
}
