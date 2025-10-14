{{/*
Expand the name of the chart.
*/}}
{{- define "cupcake.name" -}}
{{- default .Chart.Name .Values.operator.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cupcake.fullname" -}}
{{- if .Values.operator.fullnameOverride }}
{{- .Values.operator.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.operator.nameOverride }}
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
{{- define "cupcake.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cupcake.labels" -}}
helm.sh/chart: {{ include "cupcake.chart" . }}
{{ include "cupcake.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for operator
*/}}
{{- define "cupcake.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cupcake.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: operator
{{- end }}

{{/*
Agent labels
*/}}
{{- define "cupcake.agent.labels" -}}
helm.sh/chart: {{ include "cupcake.chart" . }}
{{ include "cupcake.agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for agent
*/}}
{{- define "cupcake.agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cupcake.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: agent
{{- end }}

{{/*
Create the name of the operator service account
*/}}
{{- define "cupcake.serviceAccountName" -}}
{{- if .Values.operator.serviceAccount.create }}
{{- default (include "cupcake.fullname" .) .Values.operator.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.operator.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the agent service account
*/}}
{{- define "cupcake.agent.serviceAccountName" -}}
{{- if .Values.agent.serviceAccount.create }}
{{- default (printf "%s-agent" (include "cupcake.fullname" .)) .Values.agent.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.agent.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Namespace
*/}}
{{- define "cupcake.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
External store secret name
*/}}
{{- define "cupcake.externalStoreSecretName" -}}
{{- if .Values.externalStore.s3.existingSecret }}
{{- .Values.externalStore.s3.existingSecret }}
{{- else if .Values.externalStore.gcs.existingSecret }}
{{- .Values.externalStore.gcs.existingSecret }}
{{- else }}
{{- printf "%s-backup-store" (include "cupcake.fullname" .) }}
{{- end }}
{{- end }}
