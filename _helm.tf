resource "helm_release" "gitlab" {
  count = var.deploy_gitlab ? 1 : 0

  name       = var.gitlab_release_name
  namespace  = var.gitlab_namespace
  repository = "https://charts.gitlab.io"
  chart      = "gitlab"
  version    = var.gitlab_chart_version

  cleanup_on_fail = true
  atomic          = var.gitlab_helm_atomic
  timeout         = var.gitlab_helm_timeout
  max_history     = var.gitlab_helm_max_history

  values = concat([yamlencode(local.gitlab_helm_values)], var.gitlab_extra_values)

  depends_on = [
    kubernetes_namespace.gitlab,
    kubernetes_secret.postgresql,
    kubernetes_secret.object_storage
  ]
}
