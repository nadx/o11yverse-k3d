# -----------------------------------------------------------------------------
# Loki (log aggregation)
# SingleBinary mode for local testbed (no object storage). Works on single-node k3d.
# -----------------------------------------------------------------------------

resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.helm_loki_version
  namespace  = kubernetes_namespace.observability.metadata[0].name

  # Allow more time for Loki to become ready; single-node can be slower
  timeout = 600

  values = [
    yamlencode({
      # SingleBinary: one pod, no object storage (SimpleScalable requires S3/GCS)
      deploymentMode = "SingleBinary"

      singleBinary = {
        replicas = 1
        # Allow scheduling on single-node cluster (default anti-affinity blocks this)
        affinity = {}
        persistence = {
          enabled = false
        }
        # Container runs with readOnlyRootFilesystem; ruler-storage needs writable /var/loki
        extraVolumes = [
          {
            name = "loki-data"
            emptyDir = {}
          }
        ]
        extraVolumeMounts = [
          {
            name      = "loki-data"
            mountPath = "/var/loki"
          }
        ]
      }

      gateway = {
        enabled = false
      }

      # Minimal Loki config for local dev: filesystem storage, test schema
      loki = {
        auth_enabled = false
        commonConfig = {
          replication_factor = 1
        }
        storage = {
          type = "filesystem"
          filesystem = {
            chunks_directory = "/var/loki/chunks"
            rules_directory   = "/var/loki/rules"
          }
        }
        useTestSchema = true
      }

      # Reduce moving parts for local testbed
      test = {
        enabled = false
      }
      lokiCanary = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.observability]
}
