{{- define "tolerant-post.validate.core" -}}
{{- if not (or (eq (include "tolerant-post.engineVersion" .) "V5") (eq (include "tolerant-post.engineVersion" .) "V6")) }}
{{- fail "invalid configuration: global.post.engine.version must be V5 or V6" }}
{{- end }}
{{- $isV6 := include "tolerant-post.isV6Engine" . -}}
{{- if $isV6 }}
{{- if not .Values.global.post.v6LicenceFileName }}
{{- fail "No license file configured" }}
{{- end  }}
{{- $secretFile := .Files.Get (printf "files/v6/%s" .Values.global.post.v6LicenceFileName) }}
{{- if not $secretFile }}
{{- fail "No license files found in files/v6." }}
{{- end }}
{{- else }}
{{- if eq (len .Values.global.post.v5Licenses) 0 }}
{{- fail "No v5Licenses provided" }}
{{- end }}
{{- range .Values.global.post.v5Licenses }}
{{- if not .envName }}
{{- fail "Each v5Licenses item must have a non-empty 'envName'" }}
{{- end }}
{{- if not .value }}
{{- fail "Each v5Licenses item must have a non-empty 'value'" }}
{{- end }}
{{- end }}
{{- end }}
{{- if not (or (eq .Values.config.managementMode "declarative") (eq .Values.config.managementMode "runtime")) }}
{{- fail "invalid configuration: config.managementMode must be one of declarative, runtime" }}
{{- end }}
{{- end -}}

{{- define "tolerant-post.validate.runtimeConfig" -}}
{{- $isRuntimeConfigMode := eq (include "tolerant-post.isRuntimeConfigMode" .) "true" -}}
{{- if and $isRuntimeConfigMode .Values.persistence.configFiles.enabled }}
{{- fail "invalid configuration: persistence.configFiles.enabled cannot be true when config.managementMode=runtime" }}
{{- end }}
{{- if and $isRuntimeConfigMode (gt (int .Values.replicaCount) 1) (not .Values.persistence.runtimeConfig.existingClaim) (ne .Values.persistence.runtimeConfig.accessMode "ReadWriteMany") }}
{{- fail "invalid configuration: config.managementMode=runtime with replicaCount>1 requires persistence.runtimeConfig.accessMode=ReadWriteMany for chart-managed runtime config PVC (or set persistence.runtimeConfig.existingClaim to a suitable shared claim)" }}
{{- end }}
{{- if and .Values.master.enabled .Values.master.guiEnabled (not $isRuntimeConfigMode) (not .Values.persistence.configFiles.enabled) }}
{{- fail "invalid configuration: master.guiEnabled=true with config.managementMode=declarative requires persistence.configFiles.enabled=true" }}
{{- end }}
{{- end -}}

{{- define "tolerant-post.validate.guiGatewaySecurityMetrics" -}}
{{- $isMasterMode := eq (include "tolerant-post.isMasterMode" .) "true" -}}
{{- if and $isMasterMode .Values.master.gui.enabled (not .Values.master.guiEnabled) }}
{{- fail "invalid configuration: master.gui.enabled=true requires master.guiEnabled=true so backend GUI_ENABLED is enabled on master" }}
{{- end }}
{{- if and $isMasterMode .Values.master.gui.enabled (eq (int .Values.containers.gui.port) 8080) }}
{{- fail "invalid configuration: containers.gui.port must not be 8080 when the GUI sidecar is enabled because the Post backend uses port 8080 in the same pod" }}
{{- end }}
{{- if and .Values.gateway.gui.enabled (not $isMasterMode) }}
{{- fail "invalid configuration: gateway.gui.enabled=true requires master.enabled=true" }}
{{- end }}
{{- if and (not $isMasterMode) .Values.master.gui.enabled }}
{{- fail "invalid configuration: master.gui.enabled=true requires master.enabled=true" }}
{{- end }}
{{- if and .Values.gateway.gui.enabled $isMasterMode (not .Values.master.gui.enabled) }}
{{- fail "invalid configuration: gateway.gui.enabled=true with master.enabled=true requires master.gui.enabled=true" }}
{{- end }}
{{- if and .Values.gateway.gui.enabled (not .Values.gateway.enabled) }}
{{- fail "invalid configuration: gateway.gui.enabled=true requires gateway.enabled=true" }}
{{- end }}
{{- if and .Values.gateway.gui.enabled (eq (len (.Values.gateway.gui.paths | default (list))) 0) }}
{{- fail "invalid configuration: gateway.gui.enabled=true requires gateway.gui.paths with at least one entry" }}
{{- end }}
{{- if and .Values.metrics.serviceMonitor.enabled (not .Values.metrics.enabled) }}
{{- fail "invalid configuration: metrics.serviceMonitor.enabled=true requires metrics.enabled=true" }}
{{- end }}
{{- if and .Values.telemetry.tracing.enabled (not .Values.telemetry.tracing.endpoint) }}
{{- fail "invalid configuration: telemetry.tracing.endpoint is required when telemetry.tracing.enabled=true" }}
{{- end }}
{{- if and .Values.telemetry.logs.enabled (not .Values.telemetry.logs.endpoint) }}
{{- fail "invalid configuration: telemetry.logs.endpoint is required when telemetry.logs.enabled=true" }}
{{- end }}
{{- if and .Values.security.enabled (not .Values.security.oidc.identityProviderUrl) }}
{{- fail "invalid configuration: security.oidc.identityProviderUrl is required when security.enabled=true" }}
{{- end }}
{{- if and .Values.security.enabled (not .Values.security.oidc.realm) }}
{{- fail "invalid configuration: security.oidc.realm is required when security.enabled=true" }}
{{- end }}
{{- if and .Values.security.enabled (not .Values.security.oidc.clientId) }}
{{- fail "invalid configuration: security.oidc.clientId is required when security.enabled=true" }}
{{- end }}
{{- end -}}


{{- define "tolerant-post.validate.guiBasePath" -}}
{{- $guiApiPath := dict "value" (.Values.containers.gui.apiBasePath | default "") -}}
{{- $guiBasePath := dict "value" (.Values.containers.gui.basePath | default "") -}}
{{- range .Values.containers.gui.env }}
  {{- if and (eq .name "API_BASE_PATH") (eq (toString (get $guiApiPath "value")) "") }}
    {{- $_ := set $guiApiPath "value" (toString .value) -}}
  {{- end }}
  {{- if and (eq .name "GUI_BASE_PATH") (eq (toString (get $guiBasePath "value")) "") }}
    {{- $_ := set $guiBasePath "value" (toString .value) -}}
  {{- end }}
{{- end }}
{{- $normalizedGuiBasePath := trimSuffix "/" (trimPrefix "/" (lower (get $guiBasePath "value"))) -}}
{{- if eq (trim (get $guiBasePath "value")) "" }}
{{- fail "invalid configuration: containers.gui.basePath (or GUI_BASE_PATH) must not be empty" }}
{{- end }}
{{- if not (hasPrefix "/" (toString (get $guiBasePath "value"))) }}
{{- fail "invalid configuration: containers.gui.basePath (or GUI_BASE_PATH) must start with '/'" }}
{{- end }}
{{- if and (eq (get $guiApiPath "value") "/") (or (eq (get $guiBasePath "value") "/") (eq (get $guiBasePath "value") "/ ")) }}
{{- fail "invalid configuration: when API_BASE_PATH=/, GUI_BASE_PATH cannot be '/'" }}
{{- end }}
{{- if and (eq (get $guiApiPath "value") "/") (regexMatch "^(api|admin|gui|guiconfig|info|refresh|stop|health|metrics|prometheus|operations|license|configuration|swagger-ui|swagger|routes|execute)$" $normalizedGuiBasePath) }}
{{- fail "invalid configuration: when API_BASE_PATH=/, GUI_BASE_PATH cannot use a reserved backend route segment (api, admin, gui, guiconfig, info, refresh, stop, health, metrics, prometheus, operations, license, configuration, swagger-ui, swagger, routes, execute)" }}
{{- end }}
{{- if .Values.gateway.gui.enabled }}
{{- $guiGatewayHasBasePath := dict "value" false -}}
{{- range .Values.gateway.gui.paths }}
  {{- if eq .path (get $guiBasePath "value") }}
    {{- $_ := set $guiGatewayHasBasePath "value" true -}}
  {{- end }}
{{- end }}
{{- if not (get $guiGatewayHasBasePath "value") }}
{{- fail "invalid configuration: gateway.gui.paths must include containers.gui.basePath (or GUI_BASE_PATH) when gateway.gui.enabled=true" }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "tolerant-post.validate.gateway" -}}
{{- if and .Values.gateway.existing.enabled (not .Values.gateway.enabled) -}}
{{- fail "gateway.enabled must be true when gateway.existing.enabled is true so that the HTTPRoute is rendered" -}}
{{- end -}}
{{- if and .Values.gateway.existing.enabled (empty .Values.gateway.existing.gatewayName) -}}
{{- fail "gateway.existing.gatewayName is required when gateway.existing.enabled is true" -}}
{{- end -}}
{{- if .Values.gateway.enabled -}}
{{- if empty .Values.gateway.listeners -}}
{{- fail "gateway.listeners must contain at least one listener when gateway.enabled is true" -}}
{{- end -}}
{{- range $index, $listener := .Values.gateway.listeners -}}
{{- if empty $listener.name -}}
{{- fail (printf "gateway.listeners[%d].name is required when gateway.enabled is true" $index) -}}
{{- end -}}
{{- if not $.Values.gateway.existing.enabled -}}
{{- if empty $listener.port -}}
{{- fail (printf "gateway.listeners[%d].port is required when gateway.existing.enabled is false" $index) -}}
{{- end -}}
{{- if empty $listener.protocol -}}
{{- fail (printf "gateway.listeners[%d].protocol is required when gateway.existing.enabled is false" $index) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}