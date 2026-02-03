# -----------------------------------------------------------------------------
# Prometheus (metrics) via kube-prometheus-stack
# Grafana is disabled; we deploy a separate Grafana instance for the full stack.
# -----------------------------------------------------------------------------

resource "helm_release" "prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.helm_prometheus_stack_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      # Disable bundled Grafana; we use grafana/grafana for central UI
      grafana = {
        enabled = false
      }

      # Prometheus: enable remote write receiver for OTel Collector
      prometheus = {
        prometheusSpec = {
          retention = "15d"
          # Allow OTel Collector to remote-write into this Prometheus
          enableRemoteWriteReceiver = true
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }

      # Alertmanager: keep default or disable if not needed for testbed
      alertmanager = {
        enabled = true
      }

      # Default scrape configs for kube state and nodes
      defaultRules = {
        create = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.observability]
}
