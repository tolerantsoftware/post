{{- define "tolerant-post.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tolerant-post.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "tolerant-post.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tolerant-post.labels" -}}
helm.sh/chart: {{ include "tolerant-post.chart" . }}
app.kubernetes.io/name: {{ include "tolerant-post.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "tolerant-post.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tolerant-post.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "tolerant-post.serviceAccountName" -}}
default
{{- end -}}

{{- define "tolerant-post.engineVersion" -}}
{{- default "V6" .Values.global.post.engineVersion -}}
{{- end -}}

{{- define "tolerant-post.isV6Engine" -}}
{{- $dbType := include "tolerant-post.engineVersion" . -}}
{{- if eq $dbType "V6" -}}
true
{{- end -}}
{{- end -}}



{{- define "tolerant-post.renderPostEnv" -}}
{{- $root := .root -}}
- name: GUI_ENABLED
  value: {{ .guiEnabled | quote }}
- name: TL_PROMETHEUS_METRICS_ENABLED
  value: {{ $root.Values.metrics.enabled | quote }}
- name: MICRONAUT_OTEL_ENABLED
  value: {{ or $root.Values.telemetry.tracing.enabled $root.Values.telemetry.logs.enabled | quote }}
{{ if or $root.Values.telemetry.tracing.enabled $root.Values.telemetry.logs.enabled }}
- name: OTEL_SERVICE_NAME
  value: tolerant-post
- name: OTEL_METRICS_EXPORTER
  value: none
- name: OTEL_TRACES_EXPORTER
  value: {{ ternary "otlp" "none" $root.Values.telemetry.tracing.enabled | quote }}
{{ if $root.Values.telemetry.tracing.enabled }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ $root.Values.telemetry.tracing.endpoint | quote }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: {{ $root.Values.telemetry.tracing.protocol | quote }}
- name: OTEL_TRACES_SAMPLER
  value: {{ $root.Values.telemetry.tracing.sampler | quote }}
- name: OTEL_TRACES_SAMPLER_ARG
  value: {{ $root.Values.telemetry.tracing.samplerArgument | quote }}
{{ end }}
- name: OTEL_LOGS_EXPORTER
  value: {{ ternary "otlp" "none" $root.Values.telemetry.logs.enabled | quote }}
{{ if $root.Values.telemetry.logs.enabled }}
- name: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
  value: {{ $root.Values.telemetry.logs.endpoint | quote }}
- name: OTEL_EXPORTER_OTLP_LOGS_PROTOCOL
  value: {{ $root.Values.telemetry.logs.protocol | quote }}
- name: OTEL_LOGS_LEVEL
  value: {{ $root.Values.telemetry.logs.level | quote }}
{{ end }}
{{ end }}
- name: SECURITY_ENABLED
  value: {{ $root.Values.security.enabled | quote }}
- name: THREAD_COUNT
  value: {{ $root.Values.containers.post.threadCount | quote }}
- name: LOGGING_PROFILE
  value: {{ $root.Values.containers.post.loggingProfile | quote }}
{{ if $root.Values.security.enabled }}
- name: IDENTITY_PROVIDER_URL
  value: {{ $root.Values.security.oidc.identityProviderUrl | quote }}
- name: INTERNAL_IDENTITY_PROVIDER_URL
  value: {{ $root.Values.security.oidc.identityProviderUrl | quote }}
- name: TOLERANT_REALM
  value: {{ $root.Values.security.oidc.realm | quote }}
- name: TOLERANT_CLIENT_ID
  value: {{ $root.Values.security.oidc.clientId | quote }}
{{ end }}
{{- end -}}

{{- define "tolerant-post.renderConfigProjectedSources" -}}
{{- $dbType := include "tolerant-post.engineVersion" . -}}
- configMap:
    name: {{ include "tolerant-post.postConfigMapName" . }}
{{ if .Values.global.post.license }}
- secret:
    name: {{ include "tolerant-post.fullname" . }}-post-license
{{- end }}
{{ if eq $dbType "V6" }}
- secret:
    name: {{ include "tolerant-post.fullname" . }}-post-ad-license
{{- end -}}
{{- end -}}


{{- define "tolerant-post.postConfigMapName" -}}
{{- $dbType := include "tolerant-post.engineVersion" . -}}
{{- if eq $dbType "V6" -}}
{{ include "tolerant-post.fullname" . }}-post-config-v6
{{- else -}}
{{ include "tolerant-post.fullname" . }}-post-config-v5
{{- end -}}
{{- end -}}

{{- define "tolerant-post.renderGuiContainer" -}}
- name: post-gui
  image: {{ .Values.containers.gui.image | quote }}
  imagePullPolicy: {{ .Values.containers.gui.imagePullPolicy | default .Values.image.pullPolicy | quote }}
  ports:
    - containerPort: {{ int .Values.containers.gui.port }}
      name: gui-http
  env:
    - name: GUI_BASE_PATH
      value: {{ .Values.containers.gui.basePath | quote }}
    - name: API_BASE_PATH
      value: {{ .Values.containers.gui.apiBasePath | quote }}
    {{- range .Values.containers.gui.env }}
    {{- if and (ne .name "GUI_BASE_PATH") (ne .name "API_BASE_PATH") }}
    {{- toYaml (list .) | nindent 4 }}
    {{- end }}
    {{- end }}
  {{- with .Values.containers.gui.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.containers.gui.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.containers.gui.volumeMounts }}
  volumeMounts:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}

{{- define "tolerant-post.isRuntimeConfigMode" -}}
{{- if eq .Values.config.managementMode "runtime" -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{- define "tolerant-post.isMasterMode" -}}
{{- if .Values.master.enabled -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{- define "tolerant-post.renderPvc" -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .name }}
  {{- if .keepPVCOnUninstall }}
  annotations:
    helm.sh/resource-policy: keep
  {{- end }}
spec:
  accessModes:
    - {{ .accessMode }}
  {{- with .storageClassName }}
  storageClassName: {{ . | quote }}
  {{- end }}
  resources:
    requests:
      storage: {{ .size }}
{{- end -}}
