# -----------------------------------------------------------------------------
# Outputs for .NET apps and external access
# -----------------------------------------------------------------------------

output "otel_collector_otlp_endpoint" {
  description = "OTLP gRPC endpoint for .NET apps (OTEL_EXPORTER_OTLP_ENDPOINT). Use from within cluster or port-forward."
  value       = "http://otel-collector.${var.observability_namespace}.svc.cluster.local:4317"
}

output "grafana_url" {
  description = "Grafana URL (NodePort). Use http://grafana.localtest.me:NODEPORT or port-forward."
  value       = "http://${var.grafana_domain}:${var.grafana_node_port}"
}

output "observability_namespace" {
  description = "Namespace where the observability stack is deployed."
  value       = var.observability_namespace
}

output "demo_apps_namespace" {
  description = "Namespace for demo/test workloads (e.g. .NET WebAPI)."
  value       = var.demo_apps_namespace
}
