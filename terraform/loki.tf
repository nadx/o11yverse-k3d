# -----------------------------------------------------------------------------
# Loki (log aggregation)
# Single binary or simple deployment for local testbed.
# -----------------------------------------------------------------------------

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.helm_loki_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      # Single binary mode for local dev
      singleBinary = {
        replicas = 1
        persistence = {
          enabled = false
        }
      }
      # Loki gateway for auth (optional; can be disabled for simplicity)
      gateway = {
        enabled = false
      }
      # Ingester and distributor config
      loki = {
        auth_enabled = false
        commonConfig = {
          replication_factor = 1
        }
        storage = {
          type = "filesystem"
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.observability]
}
