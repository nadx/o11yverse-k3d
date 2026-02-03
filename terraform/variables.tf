# -----------------------------------------------------------------------------
# Cluster & general
# -----------------------------------------------------------------------------

variable "cluster_name" {
  type        = string
  default     = "o11yverse"
  description = "Name of the k3d/kind cluster (used for context and labels)."
}

# -----------------------------------------------------------------------------
# Observability namespace
# -----------------------------------------------------------------------------

variable "observability_namespace" {
  type        = string
  default     = "observability"
  description = "Namespace for Prometheus, Loki, Tempo, Pyroscope, Grafana, and OpenTelemetry Collector."
}

variable "demo_apps_namespace" {
  type        = string
  default     = "demo-apps"
  description = "Namespace for demo/test workloads (e.g. .NET WebAPI)."
}

# -----------------------------------------------------------------------------
# Grafana external access
# -----------------------------------------------------------------------------

variable "grafana_domain" {
  type        = string
  default     = "grafana.localtest.me"
  description = "Host used for Grafana access (e.g. Ingress host). localtest.me resolves to 127.0.0.1."
}

variable "grafana_node_port" {
  type        = number
  default     = 30300
  description = "NodePort for Grafana when service type is NodePort (e.g. http://grafana.localtest.me:30300)."
}

variable "grafana_admin_password" {
  type        = string
  default     = "admin"
  description = "Default Grafana admin password (change in production)."
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Helm chart versions (pinned for reproducibility)
# -----------------------------------------------------------------------------

variable "helm_prometheus_stack_version" {
  type        = string
  default     = "55.5.0"
  description = "kube-prometheus-stack Helm chart version."
}

variable "helm_loki_version" {
  type        = string
  default     = "5.41.0"
  description = "Loki Helm chart version."
}

variable "helm_tempo_version" {
  type        = string
  default     = "1.5.0"
  description = "Tempo Helm chart version."
}

variable "helm_pyroscope_version" {
  type        = string
  default     = "0.8.0"
  description = "Pyroscope Helm chart version."
}

variable "helm_grafana_version" {
  type        = string
  default     = "6.56.0"
  description = "Grafana Helm chart version."
}

variable "helm_otel_collector_version" {
  type        = string
  default     = "0.96.0"
  description = "OpenTelemetry Collector Helm chart version."
}
