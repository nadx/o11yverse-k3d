# -----------------------------------------------------------------------------
# Pyroscope (continuous profiling)
# Accepts pprof-compatible profiles; flamegraphs in Grafana.
# Alloy subchart disabled so we only deploy Pyroscope (apps push via OTLP/pprof).
# -----------------------------------------------------------------------------

resource "helm_release" "pyroscope" {
  name       = "pyroscope"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "pyroscope"
  version    = var.helm_pyroscope_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  timeout = 600

  values = [
    yamlencode({
      # Disable Alloy subchart (default: true) to avoid extra pods and timeout on single-node
      alloy = {
        enabled = false
      }

      pyroscope = {
        persistence = {
          enabled = false
        }
        # Do not set structuredConfig with custom limits - field names differ by version
        # and cause "field ingestion_rate_limit not found in type validation.plain".
        # Use chart defaults; adjust limits via runtime config or chart docs if needed.
      }
    })
  ]

  depends_on = [kubernetes_namespace.observability]
}
