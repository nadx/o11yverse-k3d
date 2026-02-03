# o11yverse-k3d

A local Kubernetes observability testbed for comprehensive telemetry testing—metrics, logs, traces, and profiles—with a focus on .NET applications. The stack runs on k3d (or kind), is deployed entirely with Terraform and Helm, and uses the OpenTelemetry Collector as the single telemetry gateway. All backends (Prometheus, Loki, Tempo, Pyroscope) are wired into Grafana for a single place to explore and correlate data.

---

## Executive summary

**o11yverse-k3d** provides a reproducible, local observability environment:

- **Backends**: Prometheus (metrics), Loki (logs), Tempo (traces), Pyroscope (profiles).
- **Ingestion**: One OpenTelemetry Collector receives OTLP from .NET (or other) apps and fans out to the backends.
- **UI**: Grafana with pre-provisioned datasources and NodePort access (e.g. `http://grafana.localtest.me:30300`).
- **Management**: Terraform + Helm; no manual YAML. You create a k3d (or kind) cluster, then `terraform apply` to deploy the full stack.

Use it to validate .NET OpenTelemetry instrumentation, build dashboards, and test trace→log→profile correlation without touching production.

---

## Prerequisites (local dev machine)

| Requirement | Purpose |
|-------------|--------|
| **Docker Desktop** | Container runtime; k3d runs k3s in Docker. |
| **k3d** | Lightweight local Kubernetes (k3s in Docker); preferred on Apple Silicon. |
| **kubectl** | Cluster access and debugging. |
| **Helm** | Install observability Helm charts. |
| **Terraform** | Apply the stack from `terraform/`. |
| **.NET SDK** | Build and run .NET demo apps (optional; only if you deploy sample workloads). |

---

## Installation (macOS)

### 1. Homebrew

If you don’t have Homebrew:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Docker Desktop

- Download and install from [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/), or:
- **Apple Silicon**: `brew install --cask docker`
- Start Docker Desktop and ensure it’s running (whale icon in the menu bar).

### 3. k3d

```bash
brew install k3d
```

### 4. kubectl

```bash
brew install kubectl
```

### 5. Helm

```bash
brew install helm
```

### 6. Terraform

```bash
brew install terraform
```

### 7. .NET SDK (optional)

Only needed if you run .NET demo apps in the cluster:

```bash
brew install dotnet
```

---

## How everything is configured

### Cluster and kubeconfig

- You create the cluster yourself (e.g. with k3d). Terraform does **not** create the cluster; it assumes one exists and uses `~/.kube/config`.
- Example k3d cluster:

```bash
k3d cluster create o11yverse --port "30300:30300@server:0"
```

- The port mapping exposes Grafana’s NodePort (30300) on localhost. After `terraform apply`, open `http://grafana.localtest.me:30300` (or `http://localhost:30300`). `grafana.localtest.me` resolves to `127.0.0.1`.

### Terraform layout

All infrastructure lives under `terraform/`:

| File | Role |
|------|------|
| `versions.tf` | Terraform and provider version constraints (Kubernetes, Helm). |
| `providers.tf` | `kubernetes` and `helm` providers using `~/.kube/config`. |
| `variables.tf` | Inputs: namespaces, Grafana URL/NodePort/password, Helm chart versions. |
| `main.tf` | Namespaces: `observability`, `demo-apps`. |
| `prometheus.tf` | kube-prometheus-stack (Prometheus + node/kube scrapes); Grafana subchart disabled. |
| `loki.tf` | Loki (single-binary style) for log aggregation. |
| `tempo.tf` | Tempo with OTLP receiver for traces. |
| `pyroscope.tf` | Pyroscope for profiling. |
| `grafana.tf` | Grafana: NodePort, admin password, pre-provisioned datasources for Prometheus, Loki, Tempo, Pyroscope. |
| `otel-collector.tf` | OpenTelemetry Collector (contrib image): OTLP in → traces to Tempo, metrics to Prometheus remote write, logs to Loki. |
| `outputs.tf` | OTLP endpoint URL, Grafana URL, namespace names. |

Apply from the repo root:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Terraform uses the current kube context (e.g. your k3d cluster). No remote backend is required; state can stay local or be wired to your preferred backend later.

### Namespaces

- **observability**: All observability components (Prometheus, Loki, Tempo, Pyroscope, Grafana, OpenTelemetry Collector). Created by Terraform.
- **demo-apps**: Reserved for test workloads (e.g. .NET WebAPI). Keeps app telemetry separate from platform components.

### Data flow

1. **.NET apps** (or any OTLP client) send telemetry to the OpenTelemetry Collector:
   - **OTLP gRPC**: `http://otel-collector.observability.svc.cluster.local:4317`
   - **OTLP HTTP**: `http://otel-collector.observability.svc.cluster.local:4318`
2. **Collector** (in `observability` namespace) sends:
   - Traces → Tempo (OTLP)
   - Metrics → Prometheus (remote write)
   - Logs → Loki (Loki exporter)
3. **Grafana** is pre-provisioned with datasources for Prometheus, Loki, Tempo, and Pyroscope so you can query, explore, and correlate in one UI.

### Key configuration points

- **Grafana**: Exposed via NodePort (default `30300`). URL: `http://grafana.localtest.me:30300`. Admin password is set by `grafana_admin_password` in `variables.tf` (default `admin`).
- **Collector**: Uses `opentelemetry-collector-contrib` image so the Loki exporter is available. Config is in `otel-collector.tf` via Helm `alternateConfig` (receivers, processors, exporters, pipelines).
- **Prometheus**: Remote write receiver enabled so the collector can push metrics; kube-prometheus-stack’s own Grafana is disabled.
- **Versions**: All Helm chart versions are in `variables.tf` (e.g. `helm_prometheus_stack_version`, `helm_otel_collector_version`) for reproducibility.

### Wiring .NET apps

From a pod in the same cluster (e.g. in `demo-apps`), set:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability.svc.cluster.local:4317
```

For gRPC (typical). Use port `4318` for OTLP over HTTP if your client is configured for that. After `terraform apply`, run `terraform output` to print the exact OTLP endpoint and Grafana URL.

---

## Quick start

```bash
# 1. Create cluster (example; adjust ports if needed)
k3d cluster create o11yverse --port "30300:30300@server:0"

# 2. Deploy observability stack
cd terraform && terraform init && terraform apply -auto-approve

# 3. Open Grafana
open "http://grafana.localtest.me:30300"   # or http://localhost:30300
# Login: admin / (value of grafana_admin_password, default: admin)

# 4. Optional: run a .NET app in demo-apps with OTEL_EXPORTER_OTLP_ENDPOINT set to the collector URL above
terraform output otel_collector_otlp_endpoint
```

---

## License

See [LICENSE](LICENSE).
