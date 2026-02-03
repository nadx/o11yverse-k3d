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
      tempo = {
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
