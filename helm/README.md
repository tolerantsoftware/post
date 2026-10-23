# tolerant-post Helm chart

This chart deploys TOLERANT Post 12.2.

It renders:

- a Post worker `Deployment` named `<release>-post`
- an optional Post master `Deployment` named `<release>-post-master`
- an optional GUI sidecar in the master pod
- `ClusterIP` services for worker and, when enabled, master
- Gateway API resources for backend and GUI traffic
- ConfigMaps containing the packaged V5/V6 `postserviceconfig.xml`
- optional PVCs for reference data, customer-managed config files, and runtime-managed config
- optional Prometheus annotations and `ServiceMonitor`

##  Requirements

* **Kubernetes:** 1.32+
* **Helm:** 3.0+
* **Gateway Controller:** NGINX Gateway Fabric

### Setting Up NGINX Gateway Fabric

If not already installed, deploy the Kubernetes Gateway API and NGINX Gateway Fabric to handle external traffic:

```text
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.0" | kubectl apply -f -
```

```text
kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.0/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.0/deploy/default/deploy.yaml
```

Verify the controller and the policy CRD:

```text
kubectl get crd clientsettingspolicies.gateway.nginx.org
kubectl get pods -n nginx-gateway --watch
```

## Command Variables

The command examples use the following release and namespace values. Set them once in the current shell session before running the examples.

Linux/macOS shell:

```sh
NS=tolerant-post
RELEASE=tolerant-post
HELM_VALUES_FILE=../post-values.yaml
```

PowerShell:

```powershell
$NS = "tolerant-post"
$RELEASE = "tolerant-post"
$HELM_VALUES_FILE = "..\post-values.yaml"
```

Copy the appropriate example to a customer-specific file outside version control, edit the copy with the licensed customer values, and set `HELM_VALUES_FILE` to that file before running the commands:

- V6: `helm/docs/examples/post-values-v6.yaml`
- V5: `helm/docs/examples/post-values-v5.yaml`

## Install

Install the chart with the selected engine values file:

```sh
helm install ${RELEASE} ./helm \
  --values ${HELM_VALUES_FILE} \
  --namespace ${NS} \
  --create-namespace
```

PowerShell:

```powershell
helm install ${RELEASE} ./helm `
  --values ${HELM_VALUES_FILE} `
  --namespace ${NS} `
  --create-namespace
```

For local development images:

```sh
helm install ${RELEASE} ./helm \
  --values ${HELM_VALUES_FILE} \
  -f helm/tolerant-post/values-dev-local.yaml \
  --namespace ${NS} \
  --create-namespace
```

PowerShell:

```powershell
helm install ${RELEASE} ./helm `
  --values ${HELM_VALUES_FILE} `
  -f helm/tolerant-post/values-dev-local.yaml `
  --namespace ${NS} `
  --create-namespace
```

## Engine Licenses

`global.post.engineVersion` must be `V5` or `V6`.

For V6:

- `global.post.v6LicenceFileName` is required.
- The chart reads the license from `files/v6/<global.post.v6LicenceFileName>` and stores it in the `post-ad-license` secret.
- V6 reference databases are expected below `FileSetA` in the reference data mount. For more information see [Reference Data](#reference-data)

For V5:

- `global.post.v5Licenses` must contain at least one non-empty `envName` and `value`.
- The values are rendered into the `post-ad-license` secret and exposed to the Post container with `envFrom`.
- V5 reference databases are expected at the root of the reference data mount. For more information see [Reference Data](#reference-data)

`global.post.license` is optional. When set, it is rendered as `post.lic` in a separate secret and made available in `/opt/tolerant/config/post.lic`.

## Workloads

By default, the chart deploys both:

- worker `Deployment`: `replicaCount` controls the number of worker pods
- master `Deployment`: enabled with `master.enabled=true`

The master pod runs one Post backend container. With the default `master.gui.enabled=true`, it also runs the `post-gui` sidecar. The backend receives `GUI_ENABLED=true` on the master pod and `GUI_ENABLED=false` on worker pods.

To deploy workers only:

```yaml
master:
  enabled: false
  gui:
    enabled: false
gateway:
  gui:
    enabled: false
```

## Configuration Modes

The chart supports two config ownership modes.

### Declarative Mode

This is the default:

```yaml
config:
  managementMode: declarative
```

By default, `persistence.configFiles.enabled=true`. The chart mounts a configuration PVC at `/opt/tolerant/config`; when `existingClaim` is empty, the chart creates that PVC. A newly created PVC is empty by design. The chart does not seed the packaged configuration files into it, and Post may not become ready until the required customer configuration has been copied to the PVC.

For a predictable installation, choose one of these approaches:

- Provide a pre-populated PVC through `persistence.configFiles.existingClaim`.
- Use the chart-created PVC, populate it after creation, and then restart the Post Deployments.
- Disable `persistence.configFiles.enabled` and use the packaged read-only ConfigMap configuration. GUI configuration editing must also be disabled in this mode, as shown below.

When using the chart-created configuration PVC:

1. Create or install the PVC.
2. Copy the complete required customer configuration into the PVC.
3. Restart the worker Deployment and, when enabled, the master Deployment.
4. Verify the rollouts and application readiness.

The `pvc-copy-helper` described under [Reference Data](#reference-data) only targets the Post data PVC and cannot be used to populate the configuration PVC. See [Applying Configuration And License Changes](#applying-configuration-and-license-changes) for the manual restart commands.

To use the selected packaged configuration from a read-only ConfigMap instead:

```yaml
config:
  managementMode: declarative
persistence:
  configFiles:
    enabled: false
master:
  guiEnabled: false
  gui:
    enabled: false
gateway:
  gui:
    enabled: false
```

- V6 uses `files/postserviceconfig_v6.xml`
- V5 uses `files/postserviceconfig_v5.xml`

The default customer-managed PVC settings are:

```yaml
config:
  managementMode: declarative
persistence:
  configFiles:
    enabled: true
    existingClaim: ""
    accessMode: ReadWriteOnce
    size: 1Gi
    storageClassName: ""
```

### Runtime Mode

Runtime mode mounts a writable config PVC at `/opt/tolerant/config`, intended for GUI/API-managed config changes.

```yaml
config:
  managementMode: runtime
persistence:
  runtimeConfig:
    existingClaim: ""
    accessMode: ReadWriteOnce
    size: 5Gi
    storageClassName: ""
    seedFromConfigMaps:
      enabled: true
      image: busybox:1.36
```

When seeding is enabled, an init container copies missing packaged config files into the runtime PVC without overwriting existing files.

Runtime mode cannot be used with `persistence.configFiles.enabled=true`.

### Configuration PVC Access Modes

The default `ReadWriteOnce` access mode is intended for local or single-node Kubernetes environments such as Docker Desktop. Kubernetes permits multiple pods on the same node to use an RWO volume.

In a distributed or multi-node cluster, the Post worker and master pods may be scheduled on different nodes. If they share a customer-managed or runtime configuration PVC, use a storage backend and access mode that support concurrent multi-node access, normally `ReadWriteMany`, or provide a suitable shared `existingClaim`. Alternatively, enforce pod co-location according to the capabilities and operational requirements of the selected storage backend.

The chart cannot inspect the access modes or capabilities of an `existingClaim`; ensuring that the claim supports the configured topology is the responsibility of the operator.

## Reference Data

Reference data is controlled by `persistence.data`.

```yaml
persistence:
  data:
    enabled: true
    existingClaim: ""
    accessMode: ReadWriteMany
    size: 10Gi
    storageClassName: ""
    mountPath: /opt/tolerant/data
```

If `persistence.data.existingClaim` is empty, the chart creates a PVC named `<release>-post-data`. Set `persistence.data.existingClaim` to mount an existing PVC instead.

PVCs created by the chart are annotated with `helm.sh/resource-policy: keep` by default. Disable that behavior with:

```yaml
persistence:
  keepPVCOnUninstall: false
```

For manual data copying into the chart-managed data PVC, render the PVC and the helper pod, copy the data, then delete the helper pod.

Linux/macOS shell:

```sh
DATA_PATH=./path/to/data

helm template ${RELEASE} ./helm --values ${HELM_VALUES_FILE} --show-only templates/post-data-pvc.yaml | kubectl apply -n ${NS} -f -
helm template ${RELEASE} ./helm --values ${HELM_VALUES_FILE} --set global.copyHelperEnabled=true --show-only templates/pvc-copy-helper.yaml | kubectl apply -n ${NS} -f -
kubectl wait -n ${NS} --for=condition=Ready pod/pvc-copy-helper --timeout=60s
kubectl cp "${DATA_PATH}/." pvc-copy-helper:/target -n ${NS}
helm template ${RELEASE} ./helm --values ${HELM_VALUES_FILE} --set global.copyHelperEnabled=true --show-only templates/pvc-copy-helper.yaml | kubectl delete -n ${NS} -f -
```

PowerShell:

```powershell
$DATA_PATH = ".\path\to\data"

helm template ${RELEASE} ./helm --values ${HELM_VALUES_FILE} --show-only templates/post-data-pvc.yaml | kubectl apply -n ${NS} -f -
helm template ${RELEASE} ./helm --values ${HELM_VALUES_FILE} --set "global.copyHelperEnabled=true" --show-only templates/pvc-copy-helper.yaml | kubectl apply -n ${NS} -f -
kubectl wait -n ${NS} --for=condition=Ready pod/pvc-copy-helper --timeout=60s
kubectl cp "${DATA_PATH}/." pvc-copy-helper:/target -n ${NS}
helm template ${RELEASE} ./helm --values ${HELM_VALUES_FILE} --set "global.copyHelperEnabled=true" --show-only templates/pvc-copy-helper.yaml | kubectl delete -n ${NS} -f -
```

When reference data is copied before the first Helm installation, no restart is required because the initial pods start with the populated PVC. If Post is already installed, restart the worker and, when enabled, the master after copying reference data so both backends reinitialize consistently.

Linux/macOS shell:

```sh
kubectl rollout restart deployment/${RELEASE}-post -n ${NS}
kubectl rollout status deployment/${RELEASE}-post -n ${NS}

# Run these commands only when the master is enabled.
kubectl rollout restart deployment/${RELEASE}-post-master -n ${NS}
kubectl rollout status deployment/${RELEASE}-post-master -n ${NS}
```

PowerShell:

```powershell
kubectl rollout restart deployment/${RELEASE}-post -n ${NS}
kubectl rollout status deployment/${RELEASE}-post -n ${NS}

# Run these commands only when the master is enabled.
kubectl rollout restart deployment/${RELEASE}-post-master -n ${NS}
kubectl rollout status deployment/${RELEASE}-post-master -n ${NS}
```

To use the created persistent volume, install the Helm chart with this command.

Linux/macOS shell:

```sh
helm install ${RELEASE} ./helm --values ${HELM_VALUES_FILE} --set persistence.data.existingClaim=${RELEASE}-post-data -n ${NS}
```

PowerShell:

```powershell
helm install ${RELEASE} ./helm `
  --values ${HELM_VALUES_FILE} `
  --set "persistence.data.existingClaim=${RELEASE}-post-data" `
  -n ${NS}
```

## Gateway API And GUI

Gateway API resources are enabled by default. Backend routes use `gateway.paths` unless `gateway.backend.paths` is set. The chart renders a `Gateway`, an `HTTPRoute`, and an NGINX `ClientSettingsPolicy`. Install the NGINX Gateway Fabric and its Gateway API CRDs before installing this chart.

```yaml
gateway:
  existing:
    enabled: false
    gatewayName: ""
    gatewayNamespace: ""
  enabled: true
  clientMaxBodySize: "101m"
  className: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: post.tolerant-software.de
  paths:
    - path: /
      pathType: PathPrefix
  backend:
    paths: []
    pathType: PathPrefix
  gui:
    enabled: true
    redirectToTrailingSlash: true
    paths:
      - path: /ui
        pathType: PathPrefix
```

The GUI sidecar defaults to:

```yaml
containers:
  gui:
    image: tolerantsoftware/post-gui:12.2
    port: 8081
    basePath: /ui
    apiBasePath: /
```

When GUI routing is enabled:

- `gateway.enabled` must also be true.
- `master.enabled` and `master.gui.enabled` must also be true.
- `gateway.gui.paths` must contain at least one path.
- `gateway.gui.paths` must include `containers.gui.basePath`.
- `containers.gui.port` must not be `8080`, because the Post backend uses that port in the same pod.

Example:

```sh
helm install ${RELEASE} ./helm \
  --values ${HELM_VALUES_FILE} \
  --set gateway.listeners[0].hostname=post.example.com \
  --set gateway.listeners[0].name=http \
  --set containers.gui.basePath=/ui \
  --set gateway.gui.paths[0].path=/ui \
  --namespace ${NS} \
  --create-namespace
```

PowerShell:

```powershell
helm install ${RELEASE} ./helm `
  --values ${HELM_VALUES_FILE} `
  --set "gateway.listeners[0].hostname=post.example.com" `
  --set "gateway.listeners[0].name=http" `
  --set "containers.gui.basePath=/ui" `
  --set "gateway.gui.paths[0].path=/ui" `
  --namespace ${NS} `
  --create-namespace
```

To use a Gateway managed by another Helm release or platform component, keep `gateway.enabled=true` so that the chart renders its HTTPRoute and set `gateway.existing.enabled=true`. 
The chart then skips its own Gateway and attaches the HTTPRoute to the named external Gateway. Set `gateway.existing.gatewayNamespace` when the Gateway is in another namespace:

```yaml
gateway:
  enabled: true
  existing:
    enabled: true
    gatewayName: shared-gateway
    gatewayNamespace: shared-networking
```

The external Gateway must expose listener names matching the entries in `gateway.listeners`. The chart still renders the NGINX `ClientSettingsPolicy` when `gateway.className=nginx`; that policy targets the chart's HTTPRoute. The policy is omitted for other Gateway classes.


## Probes, Resources, And Pod Customization

The Post container supports configurable `livenessProbe`, `readinessProbe`, `startupProbe`, and `resources` under `containers.post`.
The common `podLabels`, `podAnnotations`, `podSecurityContext`, `securityContext`, `volumes`, and `volumeMounts` values apply to both worker and master workloads. GUI-specific resources, security context, and volume mounts are configured under `containers.gui`.

Default startup probe:

```yaml
containers:
  post:
    startupProbe:
      httpGet:
        path: /health/readiness
        port: http
      initialDelaySeconds: 10
      periodSeconds: 5
      timeoutSeconds: 5
      failureThreshold: 24
```

To disable a probe, set it to `null`.

## Metrics

Enable metrics annotations on the Post services with:

```yaml
metrics:
  enabled: true
  path: /prometheus
  port: "8080"
  scheme: http
```

If the Prometheus Operator CRDs are installed, enable a `ServiceMonitor`:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    namespace: ""
    labels: {}
    interval: 30s
    scrapeTimeout: 10s
```

`metrics.serviceMonitor.enabled=true` requires `metrics.enabled=true`.

Grafana dashboard (Kubernetes/Helm):

- [docs/examples/grafana/post-k8s-main-dashboard.json](./docs/examples/grafana/post-k8s-main-dashboard.json)

## OpenTelemetry

OpenTelemetry tracing is disabled by default. Enable OTLP trace export to Tempo or an OpenTelemetry Collector with:

```yaml
telemetry:
  tracing:
    enabled: true
    endpoint: http://otel-collector.observability:4318
    protocol: http/protobuf
    sampler: parentbased_traceidratio
    samplerArgument: "0.05"
```

With `parentbased_traceidratio`, `samplerArgument: "0.05"` samples approximately 5% of new root traces, not 5% of each trace's spans. Child spans follow their parent's sampling decision, including a parent received from an upstream service. The ratio ranges from `0.0` to `1.0`; temporarily use `"1.0"` to sample all new root traces when troubleshooting. An unsampled upstream parent still suppresses sampling. At the default 5% ratio, a small number of requests may produce no visible traces. See the [OpenTelemetry Java SDK configuration](https://opentelemetry.io/docs/languages/java/configuration/) for sampler details.

OpenTelemetry log export is also disabled by default. It can send OTLP logs directly to Loki or to an OpenTelemetry Collector without installing Loki in the chart:

```yaml
telemetry:
  logs:
    enabled: true
    endpoint: http://loki.observability:3100/otlp/v1/logs
    protocol: http/protobuf
    level: info
```

The log endpoint is the complete signal endpoint. Loki's native OTLP/HTTP endpoint normally ends in `/otlp/v1/logs`. Enabling logs also enables the Micronaut OpenTelemetry SDK; trace export remains disabled unless `telemetry.tracing.enabled=true`.

The chart keeps the existing Prometheus endpoint unchanged by setting the OpenTelemetry metrics exporter to `none`.

Post emits `post.startup` for service initialization, `post.pipeline` for complete service-request pipeline processing, `post.engine.process` for selected-engine execution, and `post.stab_ags.process` for coarse STAB/AGS step processing. Pipeline spans include the project ID, profile ID, and `service_request` invocation source. Engine spans include the project ID, profile ID, engine type, and an invocation source of `service_request` or `batch_record`. STAB/AGS spans include the project ID and profile ID, but do not include address, query, result, or database values.

The chart does not install a trace backend. Configure Grafana with a Tempo datasource that points to the Tempo query endpoint associated with the configured collector. See [docs/playbook-grafana.md](./docs/playbook-grafana.md#4-configure-trace-exploration).

## Security

OIDC-related backend environment variables are rendered when `security.enabled=true`.

```yaml
security:
  enabled: true
  oidc:
    identityProviderUrl: https://id.example.com
    realm: tolerant
    clientId: tolerant-post
```

When security is enabled, all three OIDC values are required.

## Applying Configuration And License Changes

The chart intentionally does not restart Post pods automatically when a generated ConfigMap or Secret changes. After a Helm upgrade that changes packaged configuration, the Post license, or a V5/V6 engine license, restart the enabled Post Deployments manually. Run the master commands only when the master is enabled.

Linux/macOS shell:

```sh
kubectl rollout restart deployment/${RELEASE}-post -n ${NS}
kubectl rollout status deployment/${RELEASE}-post -n ${NS}

# Run these commands only when the master is enabled.
kubectl rollout restart deployment/${RELEASE}-post-master -n ${NS}
kubectl rollout status deployment/${RELEASE}-post-master -n ${NS}
```

PowerShell:

```powershell
kubectl rollout restart deployment/${RELEASE}-post -n ${NS}
kubectl rollout status deployment/${RELEASE}-post -n ${NS}

# Run these commands only when the master is enabled.
kubectl rollout restart deployment/${RELEASE}-post-master -n ${NS}
kubectl rollout status deployment/${RELEASE}-post-master -n ${NS}
```

Perform the restart during an appropriate maintenance window. Configuration stored on a runtime-managed or customer-managed PVC remains owned by that PVC and is not overwritten by this process.

## Tests

This chart includes `helm-unittest` suites under `tests`.

```sh
helm plugin install https://github.com/helm-unittest/helm-unittest
helm unittest ./helm
```

The tests cover default V6 behavior, V5 behavior, Gateway API resources, PVCs, GUI/master resources, metrics, secrets, and validation failures.


## Operational Playbooks

- Grafana and Prometheus visualization: [docs/playbook-grafana.md](./docs/playbook-grafana.md)
