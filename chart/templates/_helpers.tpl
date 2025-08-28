{{/*
Expand the name of the chart.
*/}}
{{- define "microservice-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "microservice-chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "microservice-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "microservice-chart.labels" -}}
helm.sh/chart: {{ include "microservice-chart.chart" . }}
{{ include "microservice-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "microservice-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "microservice-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "microservice-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "microservice-chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate ConfigMap checksum for rolling updates
*/}}
{{- define "microservice-chart.configChecksum" -}}
{{- if .Values.configMap.enabled -}}
{{- $configData := dict -}}
{{- range $key, $value := .Values.configMap.data -}}
{{- $_ := set $configData $key $value -}}
{{- end -}}
{{- include (print $.Template.BasePath "/configmap.yaml") . | sha256sum -}}
{{- else -}}
{{- "no-config" -}}
{{- end -}}
{{- end }}

{{/*
Generate Secret checksum for rolling updates
*/}}
{{- define "microservice-chart.secretChecksum" -}}
{{- if .Values.secret.enabled -}}
{{- $secretData := dict -}}
{{- range $key, $value := .Values.secret.data -}}
{{- $_ := set $secretData $key $value -}}
{{- end -}}
{{- include (print $.Template.BasePath "/secret.yaml") . | sha256sum -}}
{{- else -}}
{{- "no-secret" -}}
{{- end -}}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "microservice-chart.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end }}
{{- end }}

{{/*
Pod annotations with checksums for rolling updates
*/}}
{{- define "microservice-chart.podAnnotations" -}}
{{- if .Values.podAnnotations }}
{{ toYaml .Values.podAnnotations }}
{{- end }}
checksum/config: {{ include "microservice-chart.configChecksum" . }}
checksum/secret: {{ include "microservice-chart.secretChecksum" . }}
{{- end }}
