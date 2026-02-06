# Troubleshooting: No logs or traces in Grafana

Use this checklist when Loki (Explore/drilldown) or Tempo show no data, or when the demo-app has no logs/traces.

---

## 1. Verify OpenTelemetry Collector is running and healthy

The collector receives OTLP from apps and filelog from nodes; it must be running and able to reach Loki and Tempo.

```bash
# DaemonSet and pods (name includes -agent)
kubectl get daemonset -n observability
kubectl get pods -n observability -l app.kubernetes.io/name=opentelemetry-collector

# Collector logs (look for errors about Loki, Tempo, or filelog)
kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector --tail=100
```

- **No pods / CrashLoopBackOff**: Check `kubectl describe pod -n observability -l app.kubernetes.io/name=opentelemetry-collector` and fix config or image.
- **Errors like "connection refused" to Loki/Tempo**: Ensure Loki and Tempo services are up in `observability` and that the collector can resolve them (`loki.observability.svc.cluster.local`, `tempo.observability.svc.cluster.local`).

---

## 2. Verify Loki has data

**In Grafana:** Explore → select **Loki** → run a broad query:

- `{namespace=~".+"}` — any namespace
- `{job=~".+"}` — if you have a `job` label

If you see no streams, Loki is not receiving logs yet.

**From the cluster:** Check Loki is up and that the collector can push:

```bash
# Loki pod
kubectl get pods -n observability -l app.kubernetes.io/name=loki

# Optional: port-forward and push a test log (then query in Grafana)
kubectl port-forward -n observability svc/loki 3100:3100 &
curl -s -X POST "http://localhost:3100/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d '{"streams":[{"stream":{"job":"test"},"values":[["'$(date +%s)000000000'","hello from curl"]]}]}'
```

---

## 3. Verify Tempo has data

**In Grafana:** Explore → select **Tempo** → Search. Run a search with no filters (or by service name if you know it). If no traces appear, nothing is reaching Tempo.

**From the cluster:**

```bash
# Tempo pod
kubectl get pods -n observability -l app.kubernetes.io/name=tempo

# Tempo is on port 3200 (not 3100)
kubectl get svc -n observability tempo
```

Traces only appear if an instrumented app sends OTLP traces to the collector (see demo-app section below).

---

## 4. Demo-app: OTLP endpoint and instrumentation

For the **demo-app** to show **traces** and **OTLP logs** in Grafana:

1. **OTLP endpoint**  
   The app must send telemetry to the collector. From inside the cluster, use:
   - **gRPC:** `http://otel-collector.observability.svc.cluster.local:4317`
   - **HTTP (if your SDK uses it):** `http://otel-collector.observability.svc.cluster.local:4318`

   Set in the app’s environment (example gRPC):
   ```bash
   OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability.svc.cluster.local:4317
   OTEL_EXPORTER_OTLP_PROTOCOL=grpc
   ```
   For .NET, often `OTEL_EXPORTER_OTLP_ENDPOINT` is enough (e.g. `http://...:4317`); the exporter may infer gRPC from the port.

2. **Instrumentation**  
   The app must be instrumented to export traces (and optionally logs):
   - **Traces:** OpenTelemetry tracing (e.g. .NET `OpenTelemetry.Instrumentation.*`).
   - **Logs:** OpenTelemetry logging exporter if you want app-level logs in Loki via OTLP (otherwise you only get container stdout from filelog).

3. **Deployment in cluster**  
   The demo-app should run in the same cluster so it can resolve `otel-collector.observability.svc.cluster.local`. If it runs only on your host, use port-forward and point the app to `localhost:4317` (and ensure the collector is listening).

**Quick checks:**

```bash
# Is the demo-app running and in which namespace?
kubectl get pods -n demo-apps
kubectl get pods -A | grep -i demo

# Does the pod have OTEL_EXPORTER_OTLP_ENDPOINT?
kubectl get pod -n demo-apps -o yaml | grep -A2 OTEL

# Can the demo-app pod reach the collector? (from inside the cluster)
kubectl run -n demo-apps curl --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s -o /dev/null -w "%{http_code}" http://otel-collector.observability.svc.cluster.local:4318
# Or from a pod that has curl/nslookup:
kubectl exec -n demo-apps deploy/<demo-app-deployment> -- nslookup otel-collector.observability.svc.cluster.local
```

---

## 5. Container logs (filelog) and k3d

Logs you see in Loki from “Grafana” or “demo-app” might be:

- **Container stdout/stderr** (filelog): The collector DaemonSet tails `/var/log/pods` on each node and sends to Loki.
- **OTLP logs**: Only if the app explicitly exports logs via OpenTelemetry to the collector.

**If Loki only receives logs from namespace `observability` (e.g. only `loki-canary` / `loki-single-binary` jobs):**

- **Permissions:** On many clusters `/var/log/pods` (or some pod log dirs) is readable only by root. The collector runs as non-root by default, so it may only read a subset of log files. The Terraform config sets `securityContext.runAsUser: 0` and `runAsGroup: 0` for the collector when log collection is enabled so it can read all pod logs. Apply and roll the collector, then check Loki again.
- **Labels:** The `kubernetesAttributes` preset is enabled so logs get `namespace`, `pod`, `container` before export to Loki, giving correct job/stream labels for every namespace.

**If there are no container logs in Loki (or still only observability):**

- **k3d nodes:** The node is a container; `/var/log/pods` is the path **inside the k3d node**. The DaemonSet mounts the host path; on k3d this is usually the node container’s `/var/log/pods`. If k3d mounts a different path for logs, filelog might not see them.
- **Permissions:** The collector pod must be able to read `/var/log/pods`. Check the pod’s securityContext (run as root when using logsCollection).
- **Verify what filelog sees:** Exec into the collector pod and list `/var/log/pods`; you should see dirs for all pods on that node (e.g. `demo-apps_myapp-xxx`, `observability_loki-xxx`). If only observability dirs exist, the issue is node/k3d log layout.

**Check filelog:**

```bash
# Collector logs: look for filelog errors (e.g. "permission denied", "no such file")
kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector --tail=200 | grep -i filelog

# On a node, where do container logs live? (run a debug pod with hostPath)
kubectl run -n observability debug --rm -it --restart=Never --overrides='
{"spec":{"containers":[{"name":"debug","image":"busybox","command":["sh","-c","ls -la /var/log/pods 2>/dev/null || echo no /var/log/pods; sleep 30"]},{"volumeMounts":[{"name":"varlog","mountPath":"/var/log"}],"name":"debug"}]],"volumes":[{"name":"varlog","hostPath":{"path":"/var/log"}}]}}
' --image=busybox
```

If `/var/log/pods` is empty or missing on the host, the runtime may be writing logs elsewhere; adjust the collector’s filelog path or the cluster’s log configuration.

---

## 6. Grafana datasources and drilldown

- **Loki label names (OTel → Loki):** The OTel Loki exporter turns resource attributes into Loki labels and replaces dots with underscores (e.g. `k8s.namespace.name` → `k8s_namespace_name`). If `{namespace="kube-system"}` returns "No logs volume available", try `{k8s_namespace_name="kube-system"}`. The Terraform config adds a transform processor so a `namespace` label is also set; after apply and collector rollout, `{namespace="kube-system"}` should work.

**Explore → Loki:** Ensure the Loki datasource URL is correct (e.g. `http://loki.observability.svc.cluster.local:3100`). Test in Configuration → Data sources → Loki → “Save & test”.
- **Explore → Tempo:** Same for Tempo (e.g. `http://tempo.observability.svc.cluster.local:3200`). Test the connection.
- **Drilldown:** “Logs for this span” or “Trace for this log” only work if:
  - Trace IDs / log fields are present and consistent (e.g. `traceID` in Loki logs, or span→log linking in your app).
  - There is at least one trace or log in Tempo/Loki; otherwise there is nothing to drill into.

---

## 7. Quick reference: service endpoints

| Component   | In-cluster URL (HTTPS omitted) |
|------------|---------------------------------|
| OTLP gRPC  | `otel-collector.observability.svc.cluster.local:4317` |
| OTLP HTTP  | `otel-collector.observability.svc.cluster.local:4318` |
| Loki       | `loki.observability.svc.cluster.local:3100` |
| Tempo      | `tempo.observability.svc.cluster.local:3200` |
| Prometheus | `kube-prometheus-stack-prometheus.observability.svc.cluster.local:9090` |

Use these in app env vars and when testing from inside the cluster.
