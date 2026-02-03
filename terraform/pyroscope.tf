# -----------------------------------------------------------------------------
# Pyroscope (continuous profiling)
# Accepts pprof-compatible profiles; flamegraphs in Grafana.
# -----------------------------------------------------------------------------

resource "helm_release" "pyroscope" {
  name       = "pyroscope"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "pyroscope"
  version    = var.helm_pyroscope_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      # Single replica, no persistence for local testbed
      persistence = {
        enabled = false
      }
      # Pyroscope accepts OTLP and pprof
      config = {
        limits = {
          ingestion-rate-limit = 10000
          max-global-series-per-user = 10000
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.observability]
}
