# -----------------------------------------------------------------------------
# Namespaces and Helm repositories
# -----------------------------------------------------------------------------

# Observability stack: Prometheus, Loki, Tempo, Pyroscope, Grafana, OpenTelemetry Collector
resource "kubernetes_namespace" "observability" {
  metadata {
    name = var.observability_namespace
    labels = {
      "app.kubernetes.io/name" = "observability"
    }
  }
}

# Isolated namespace for demo/test workloads (e.g. .NET WebAPI)
resource "kubernetes_namespace" "demo_apps" {
  metadata {
    name = var.demo_apps_namespace
    labels = {
      "app.kubernetes.io/name" = "demo-apps"
    }
  }
}

# Helm charts use repository URLs directly in each helm_release.
# No need to pre-add repos; ensure helm is installed (e.g. brew install helm).
