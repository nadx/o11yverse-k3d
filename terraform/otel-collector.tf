# -----------------------------------------------------------------------------
# OpenTelemetry Collector (DaemonSet: telemetry gateway + log collector)
# - Receives OTLP (gRPC/HTTP) from apps; pipelines to Tempo, Prometheus, Loki.
# - Collects container logs from each node (filelog -> Loki). No Promtail.
# Apps use OTEL_EXPORTER_OTLP_ENDPOINT pointing at this collector's service.
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

  values = [
    yamlencode({
      # DaemonSet: one pod per node for OTLP + node-level log collection
      mode = "daemonset"

      # Service so apps can reach OTLP (disabled by default for daemonset)
      service = {
        enabled = true
      }

      image = {
        repository = "otel/opentelemetry-collector-contrib"
        pullPolicy = "IfNotPresent"
      }

      command = {
        name = "otelcol-contrib"
      }

      # Log collection from all containers: filelog reads /var/log/pods; chart adds volumes/mounts
      # kubernetesAttributes: enrich logs with namespace, pod, container so Loki has labels for all namespaces
      presets = {
        logsCollection = {
          enabled             = true
          includeCollectorLogs = false
          storeCheckpoints    = false
        }
        kubernetesAttributes = {
          enabled = true
        }
      }

      # Read all pod logs: /var/log/pods is often root-only on nodes; run as root so filelog can read every namespace
      podSecurityContext = {}
      securityContext = {
        runAsUser  = 0
        runAsGroup = 0
      }

      # OTLP + filelog (from preset) -> Tempo, Prometheus, Loki
      config = {
        processors = {
          # Copy k8s.namespace.name to "namespace" so Loki gets label namespace (Grafana query: {namespace="kube-system"})
          transform = {
            log_statements = [
              {
                context    = "resource"
                statements = ["set(attributes[\"namespace\"], attributes[\"k8s.namespace.name\"])"]
              }
            ]
          }
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
            # otlp (app logs) + filelog (container logs from preset) -> Loki; transform sets namespace label
            logs = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "transform", "batch"]
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
