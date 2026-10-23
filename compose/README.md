# Tolerant Post Docker compose

## Steps to use your own identity provider

-  Make sure, that you have configured your identity provider having a client with clientId and realm matching the values of **TOLERANT_CLIENT_ID** and **TOLERANT_REALM** in the .env file
-  Remove postgres and keycloak from the compose-secure.yml, this includes **services**, **volumes** and **depends_on** sections.
-  Remove the variables **INTERNAL_IDENTITY_PROVIDER_URL** and **INTERNAL_IDENTITY_PROVIDER_PORT** from the **proxy** service in the compose-secure.yml
-  Adjust **INTERNAL_IDENTITY_PROVIDER_URL** and **IDENTITY_PROVIDER_URL** in the .env file to the URL of your identity provider.
-  Remove the mount for the keycloak location from the **proxy** service in the compose-secure.yml

## Steps to use your own ssl certificate
-  Remove openssl from the compose-secure.yml, this includes **services**, **volumes_from** and **depends_on** sections.
-  Comment in the volumes of the proxy service for ssl certificates in the compose-secure.yml
-  Make sure that the ssl certificate and key are under the mounted directory's mentioned in step before
-  Make sure that the variables **CERT_FILENAME** and **CERT_PRIVATE_KEY_FILENAME** in the .env file Post your filenames

## Steps to use without gui

### Without security
- Replace the mounts for default.conf.template and common.loc.template for **proxy** with mounts for default.no.gui.conf.template and common.no.gui.loc.template in the compose.yml
- Remove gui from the compose.yml, this includes **services** and **depends_on** sections.
- Set **GUI_ENABLED** to false for the backend service.

### With enabled security
- Replace the mounts for ssl.conf.template and common.loc.template for **proxy** with mounts for ssl.no.gui.conf.template and common.no.gui.loc.template in the compose-secure.yml
- Remove gui from the compose-secure.yml, this includes **services** and **depends_on** sections.
- Set **GUI_ENABLED** to false for the backend service.

## Usage

### Starting

**The services can be started using the following commands:**

Without security:

```sh
docker compose up -d
```

With enabled security:

```sh
docker compose -f compose-secure.yml up -d
```

The `docker compose` command should be executed from the directory containing the `compose.yml or compose-secure.yml` file.


### Stopping

**The running services can be stopped using the following commands:**

Without security:

```sh
docker compose down
```

With enabled security:

```sh
docker compose -f compose-secure.yml down
```


The `docker compose` command should be executed from the directory containing the `compose.yml or compose-secure.yml` file.

### Starting a batch process
>**Note**
> The config file and the reference data must exist inside the container.

A batch process can be stated with the following example

```sh
docker compose -f compose-batch.yml up -d
```

Removing the container after it has exited

```sh
docker compose -f compose-batch.yml down
```

Steps to use your own configuration and data for a batch process
- mount your configuration and data to the batch container
- adjust the entry point of the `compose-batch.yml` to Post the following pattern:
```yaml
entrypoint: ["postBatch.sh", "<configFilename>", "<projectId>", "<profileId>"]
```

### Starting with local user and group

To start with a different user please use the following instructions:

* create the following directories using the local user
    * post-config
    * post-data
    * post-logs
    * post-protocols
* use the fully qualified path of the above mentioned directories in the compose.yml or compose-secure.yml
* comment in the **user** setting for the **backend** and the **gui** service
* start the compose file

Without security:

```sh
export UID=`id -u`; export GID=`id -g`; docker compose up -d
```

With enabled security:

```sh
export UID=`id -u`; export GID=`id -g`; docker compose -f compose-secure.yml up -d
```

The `docker compose` command should be executed from the directory containing the `compose.yml or compose-secure.yml` file.

### Stopping with local user and group

```sh
export UID=`id -u`; export GID=`id -g`; docker compose down
```

With enabled security:

```sh
export UID=`id -u`; export GID=`id -g`; docker compose -f compose-secure.yml down
```

The `docker compose` command should be executed from the directory containing the `compose.yml or compose-secure.yml` file.

## OpenTelemetry

The packaged `.env` enables tracing for the local Docker example. The backend exports traces to the bundled Tempo service, and Grafana is provisioned with the Tempo datasource. In Grafana **Explore**, select Tempo and search for service name `tolerant-post`.

Set `MICRONAUT_OTEL_ENABLED=false` before starting Docker Compose to disable OpenTelemetry.

Log export is disabled by default and does not install Loki. To export logs to an existing Loki instance that accepts native OTLP/HTTP, set the following values in the `.env` file:

```yaml
MICRONAUT_OTEL_ENABLED=true
OTEL_TRACES_EXPORTER=none
OTEL_LOGS_EXPORTER=otlp
OTEL_LOGS_LEVEL=info
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://loki:3100/otlp/v1/logs
```

The backend must be able to resolve and reach the endpoint. Trace and log export are configured independently.

## OpenTelemetry

### Tracing

The supplied `.env` enables tracing by default with `MICRONAUT_OTEL_ENABLED=true`. `compose.yml` includes a Tempo service for trace storage, even when trace export is disabled. Without the `.env` setting or a shell override, the Compose file falls back to disabling the SDK. To explicitly enable tracing, set the following values in the `.env` file before starting or recreating the services:

```text
MICRONAUT_OTEL_ENABLED=true
OTEL_TRACES_EXPORTER=otlp
```

For the secure setup, use `docker compose -f compose-secure.yml up -d`. The tracing variables apply to the backend. Log export remains disabled unless configured separately below; metrics continue to use Prometheus (`OTEL_METRICS_EXPORTER=none`).

The configured trace destination is `http://tempo:4318`, using OTLP over HTTP/protobuf. This is a base URL: the exporter appends `/v1/traces`. Open Grafana on the configured `GRAFANA_PORT`, select a Tempo datasource in **Explore**, and search for service name `tolerant-post` after making Post requests. If needed, add a Tempo datasource with query URL `http://tempo:3200`; this differs from the OTLP ingestion port. Post emits spans including `post.startup`, `post.pipeline`, `post.engine.process`, and `post.stab_ags.process`.

To disable all OpenTelemetry export, set `MICRONAUT_OTEL_ENABLED=false` in your `.env` and recreate the services with the appropriate `up -d` command. To disable only traces while retaining logs, keep the SDK enabled and set `OTEL_TRACES_EXPORTER=none`.

### Using a custom collector

The trace endpoint and protocol are configure via the variables `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_PROTOCOL` in the `.env`


The value of `OTEL_EXPORTER_OTLP_ENDPOINT` must be a hostname reachable from the Post container. The collector must accept OTLP/HTTP traces on this port and forward them to your trace backend. A container on another Docker network is not automatically reachable by its service name, and `localhost` refers to the Post container itself.

Apply the override last:

```sh
docker compose up -d
```

For the secure setup, insert `-f compose-secure.yml`

This changes trace export only; the bundled Tempo service still starts because it remains in the Compose configuration and dependencies. Point Grafana's Tempo datasource at the query endpoint of the Tempo deployment receiving the collector's traces, or use the appropriate datasource for your chosen trace backend.

### Trace sampling

The Compose file does not explicitly configure sampling. To configure a 5% ratio, add these entries to the same service's `environment` mapping in the override:

```yaml
      OTEL_TRACES_SAMPLER: parentbased_traceidratio
      OTEL_TRACES_SAMPLER_ARG: "0.05"
```

This samples approximately 5% of new root traces, not 5% of each trace's spans. Child spans follow the parent's sampling decision, including a parent received from an upstream service. The ratio ranges from `0.0` to `1.0`; use `1.0` temporarily to sample all new root traces when troubleshooting. An unsampled upstream parent still suppresses sampling. With `0.05`, a small number of requests may produce no visible traces. These variables must be added to the Compose environment; shell exports alone are not forwarded by the supplied files. See the [OpenTelemetry Java SDK configuration](https://opentelemetry.io/docs/languages/java/configuration/) for sampler details.

## Exporting logs with OpenTelemetry

Log export is disabled by default and does not install Loki. For a **logs-only** setup exporting to an existing Loki instance that accepts native OTLP/HTTP, set these variables in the `.env` before starting Docker Compose:

```text
MICRONAUT_OTEL_ENABLED=true
OTEL_TRACES_EXPORTER=none
OTEL_LOGS_EXPORTER=otlp
OTEL_LOGS_LEVEL=info
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://loki:3100/otlp/v1/logs
```

The backend must be able to resolve and reach the endpoint. `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` is the complete logs URL, including `/otlp/v1/logs` for Loki. To export both logs and traces, use `OTEL_TRACES_EXPORTER=otlp` instead of `none` and configure tracing as described above. If using a Compose override, keep its `OTEL_TRACES_EXPORTER` value consistent with the desired setup, since that value takes precedence over the base file's shell-variable substitution. Apply the changes with the appropriate `docker compose ... up -d` command to recreate the affected containers.
