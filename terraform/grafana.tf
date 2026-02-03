# -----------------------------------------------------------------------------
# Grafana (central UI)
# NodePort for external access at grafana.localtest.me:NODEPORT
# Pre-provisioned datasources: Prometheus, Loki, Tempo, Pyroscope
# -----------------------------------------------------------------------------

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.helm_grafana_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      adminPassword = var.grafana_admin_password

      service = {
        type      = "NodePort"
        nodePort = var.grafana_node_port
      }

      # Pre-provisioned datasources for all backends
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://kube-prometheus-stack-prometheus.${var.observability_namespace}.svc.cluster.local:9090"
              access    = "proxy"
              isDefault = true
            },
            {
              name   = "Loki"
              type   = "loki"
              url    = "http://loki.${var.observability_namespace}.svc.cluster.local:3100"
              access = "proxy"
            },
            {
              name   = "Tempo"
              type   = "tempo"
              url    = "http://tempo.${var.observability_namespace}.svc.cluster.local:3100"
              access = "proxy"
            },
            {
              name   = "Pyroscope"
              type   = "grafana-pyroscope-datasource"
              url    = "http://pyroscope.${var.observability_namespace}.svc.cluster.local:4040"
              access = "proxy"
            }
          ]
        }
      }

      # Persistence disabled for local testbed
      persistence = {
        enabled = false
      }

      # Ingress optional: uncomment and set ingress.enabled = true for grafana.localtest.me
      ingress = {
        enabled = false
      }
    })
  ]

  depends_on = [
    helm_release.prometheus_stack,
    helm_release.loki,
    helm_release.tempo,
    helm_release.pyroscope
  ]
}
