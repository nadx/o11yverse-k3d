# -----------------------------------------------------------------------------
# Tempo (distributed tracing)
# Receives OTLP from OpenTelemetry Collector; queried via Grafana.
# -----------------------------------------------------------------------------

resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = var.helm_tempo_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [
    yamlencode({
      # Tempo app v2.10.0 for TraceQL and drilldown (chart default is 2.9.x)
      tempo = {
        tag = "2.10.0"
        # Required for TraceQL aggregations (e.g. rate() by()) and drilldown; "empty ring" = generator not enabled
        metricsGenerator = {
          enabled = true
        }
        receivers = {
          otlp = {
            protocols = {
              grpc = {}
              http = {}
            }
          }
        }
        storage = {
          trace = {
            backend = "local"
            local = {
              path = "/var/tempo/traces"
            }
          }
        }
      }
      # Single replica for local testbed
      persistence = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.observability]
}
