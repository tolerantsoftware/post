# Grafana Playbook

Use this playbook to visualize Post metrics, traces, and logs in Grafana for a Helm deployment in Kubernetes.

See the [Helm OpenTelemetry settings](../README.md#opentelemetry) for trace and log exporters, endpoints, and sampling.

The Post chart does not install Grafana, a Collector, Tempo, or Loki. Have the required backends available before verification. A Collector must have a pipeline for each exported signal and forward it to a backend that Grafana can query.

## 1) Enable Metrics in Helm

```sh
NS=<namespace>
RELEASE=tolerant-post

helm upgrade --install ${RELEASE} ./helm \
  --namespace ${NS} \
  --reuse-values \
  --set metrics.enabled=true \
  --set metrics.serviceMonitor.enabled=true
```

```powershell
$NS="<namespace>"
$RELEASE="tolerant-post"

helm upgrade --install $RELEASE ./helm `
  --namespace $NS `
  --reuse-values `
  --set metrics.enabled=true `
  --set metrics.serviceMonitor.enabled=true
```

If you do not run Prometheus Operator, keep `metrics.serviceMonitor.enabled=false` and scrape via service annotations.

## 2) Verify Prometheus Scrape

- In Prometheus UI, check `Status -> Targets` and verify Post targets are `UP`.
- Quick probe:

```promql
up{namespace="<namespace>"}
```

## 3) Import Dashboards

Import this JSON file in Grafana:

- Main service dashboard: `docs/examples/grafana/post-k8s-main-dashboard.json`

On import, map `${DS_PROMETHEUS}` to your Prometheus datasource.

## 4) Configure Trace Exploration

Tracing requires an OpenTelemetry Collector or Tempo deployment reachable from Post. Enable trace export with:

```sh
helm upgrade --install ${RELEASE} ./helm \
  --namespace ${NS} \
  --reuse-values \
  --set telemetry.tracing.enabled=true \
  --set telemetry.tracing.endpoint="http://<collector-service>:4318" \
  --set telemetry.tracing.protocol=http/protobuf
```

Provision or add a Grafana Tempo datasource whose URL points to the Tempo query endpoint, for example `http://<tempo-query-service>:3200`. In Grafana **Explore**, select that datasource and search for service name `tolerant-post`.

Post emits these custom spans:

- `post.startup`
- `post.pipeline`
- `post.engine.process`
- `post.stab_ags.process`

### Verify Traces

1. Apply the tracing configuration and wait for the updated Post pods to start.
2. Perform several normal Post address-validation requests through the GUI or your existing API client against a configured project. A health probe alone does not exercise the address-processing pipeline.
3. In Grafana **Explore**, select the Tempo datasource and a time range covering those requests, such as the last 15 minutes. Search for service name `tolerant-post`, refresh after allowing time for export, and open a trace to inspect its `post.pipeline` and related spans.
4. For `post.startup`, select a time range containing service initialization. Engine and STAB/AGS spans depend on the configured processing path; not every request executes those steps.

Helm defaults to `parentbased_traceidratio` with a ratio of `0.05`: approximately 5% of new root traces are sampled, while child spans follow the parent's decision. A handful of requests may therefore produce no visible traces. Temporarily set `telemetry.tracing.samplerArgument` to `"1.0"` for troubleshooting and restore the original value afterwards. An unsampled upstream parent still prevents sampling.

## 5) Configure Log Exploration

Enable log export using the [Helm settings](../README.md#opentelemetry). For direct Loki export, use a Loki deployment that supports native OTLP ingestion and has structured metadata enabled. See [Loki's OpenTelemetry ingestion requirements](https://grafana.com/docs/loki/latest/send-data/otel/).

For Helm, enable `telemetry.logs.enabled`, set `telemetry.logs.endpoint` to the complete Loki OTLP/HTTP URL (for example `http://loki.observability:3100/otlp/v1/logs`), and use `telemetry.logs.protocol: http/protobuf` and `telemetry.logs.level: info`. To route through a Collector instead, use its complete logs signal URL, for example `http://otel-collector.observability:4318/v1/logs`, and ensure its logs pipeline forwards to Loki. Trace export remains controlled separately by `telemetry.tracing.enabled`.

1. Add a **Loki** datasource in Grafana with the Loki query base URL, for example `http://loki.observability:3100`. Configure authentication and tenant settings if your deployment requires them, then use **Save & test**. The datasource URL must be reachable from Grafana and must not include the OTLP ingestion path. See [Grafana's Loki datasource configuration](https://grafana.com/docs/grafana/latest/datasources/loki/configure/).
2. Apply the export configuration and wait for the updated Post instances to start. Identify a new INFO-or-higher startup or application message in the normal Post logs; requests do not necessarily emit a message at that level.
3. In **Explore**, select the Loki datasource and a time range covering the message. With Loki's default OTLP label mapping, query:

```logql
{service_name="tolerant-post"}
```

4. Refresh after allowing time for export, then compare the message and timestamp with the normal Post log. If your Collector or Loki configuration changes resource attributes or index labels, use the label browser to select the actual service label.

Enabling OTLP logs does not automatically collect proxy, GUI, or other containers' stdout. Trace sampling does not set the log export threshold; use the log-level setting for logs.

## 6) Troubleshoot Telemetry

Keep ingestion endpoints and Grafana query endpoints separate. These examples use OTLP over HTTP/protobuf:

| Connection | Example URL | Purpose |
|---|---|---|
| Post to Tempo or Collector | `http://tempo:4318` | Trace base endpoint; the exporter appends `/v1/traces` |
| Post directly to Loki | `http://loki:3100/otlp/v1/logs` | Complete OTLP logs endpoint |
| Post to Collector for logs | `http://otel-collector:4318/v1/logs` | Complete OTLP logs endpoint |
| Grafana to Tempo | `http://tempo:3200` | Trace queries |
| Grafana to Loki | `http://loki:3100` | Log queries |

Replace these hosts with your deployment's services or gateways. Check the following when data is missing:

- **No connection:** verify DNS, port, network access, and any TLS or authentication requirements from the sending container or pod. Grafana and Post may have different network access; `localhost` refers to the process's own container or pod.
- **Export errors:** inspect Post and Collector logs for connection failures, rejected requests, or protocol errors. Confirm the receiver accepts `http/protobuf` on the configured port; an HTTP query port is not an OTLP trace receiver.
- **No traces:** verify `MICRONAUT_OTEL_ENABLED=true` and `OTEL_TRACES_EXPORTER=otlp` in the running Post environment, then check sampling, upstream parent decisions, service filters, and the query time range.
- **No logs:** verify the SDK is enabled, `OTEL_LOGS_EXPORTER=otlp`, `OTEL_LOGS_LEVEL` is not `off`, and the complete logs endpoint is configured. Confirm the normal application logger actually emits the expected level; lowering the export threshold cannot recover messages filtered by that logger. For Loki rejections, check its native OTLP and structured metadata configuration.
- **Collector receives data but Grafana is empty:** verify the Collector's signal pipeline and destination, then confirm the datasource queries that same backend and tenant. A successful datasource connection alone does not prove ingestion works.
- **Configuration appears unchanged:** check the effective Helm values, rendered workload environment, and running pod's environment. Apply changed values with `helm upgrade` and verify that the workload rollout has completed.

## 7) Use Dashboard Variables

- `Namespace`: namespace containing Post pods
- `Pod`: single pod or all pods
- `projectId`: project filter (regex)
