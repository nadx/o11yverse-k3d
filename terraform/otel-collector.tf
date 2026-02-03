# -----------------------------------------------------------------------------
# OpenTelemetry Collector (telemetry gateway)
# Receives OTLP (gRPC/HTTP) from .NET apps; pipelines to Tempo, Prometheus, Loki.
# Apps use OTEL_EXPORTER_OTLP_ENDPOINT to point to this collector's service.
# -----------------------------------------------------------------------------

locals {
  otel_prometheus_endpoint = "http://kube-prometheus-stack-prometheus.${var.observability_namespace}.svc.cluster.local:9090/api/v1/write"
  otel_tempo_endpoint      = "tempo.${var.observability_namespace}.svc.cluster.local:4317"
  otel_loki_endpoint       = "http://loki.${var.observability_namespace}.svc.cluster.local:3100/loki/api/v1/push"
}

resource "helm_release" "otel_collector" {
  name       = "otel-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.helm_otel_collector_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  # Use contrib image for Loki exporter (and other contrib components)
  values = [
    yamlencode({
      mode = "deployment"

      image = {
        repository = "otel/opentelemetry-collector-contrib"
        pullPolicy  = "IfNotPresent"
      }

      command = {
        name = "otelcol-contrib"
      }

      # Full config: OTLP in; traces→Tempo, metrics→Prometheus remote write, logs→Loki
      # health_check extension is required for chart liveness/readiness probes
      alternateConfig = {
        extensions = {
          health_check = {
            endpoint = "$${env:MY_POD_IP}:13133"
          }
        }
        receivers = {
          otlp = {
            protocols = {
              grpc = {}
              http = {}
            }
          }
        }
        processors = {
          batch         = {}
          memory_limiter = {}
        }
        exporters = {
          prometheusremotewrite = {
            endpoint = local.otel_prometheus_endpoint
          }
          "otlp/tempo" = {
            endpoint = local.otel_tempo_endpoint
            tls = {
              insecure = true
            }
          }
          loki = {
            endpoint = local.otel_loki_endpoint
          }
        }
        service = {
          extensions = ["health_check"]
          pipelines = {
            traces = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["otlp/tempo"]
            }
            metrics = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["prometheusremotewrite"]
            }
            logs = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["loki"]
            }
          }
        }
      }

      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    })
  ]

  depends_on = [
    helm_release.prometheus_stack,
    helm_release.loki,
    helm_release.tempo
  ]
}
