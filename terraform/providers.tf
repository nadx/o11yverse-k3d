# -----------------------------------------------------------------------------
# Kubernetes and Helm providers target the local cluster via kubeconfig.
# Ensure kubeconfig points to your k3d/kind cluster before terraform apply.
# -----------------------------------------------------------------------------

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
