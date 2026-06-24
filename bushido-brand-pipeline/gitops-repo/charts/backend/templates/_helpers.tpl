{{/* 
Expand the name of the chart. 
*/}}
{{- define "backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | truncate 63 | trimSuffix "-" -}}
{{- end -}}

{{/* 
Create a default fully qualified app name. 
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec). 
*/}}
{{- define "backend.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | truncate 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | truncate 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | truncate 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* 
Create chart name and version as used by the chart label. 
*/}}
{{- define "backend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | truncate 63 | trimSuffix "-" -}}
{{- end -}}

{{/* 
Common labels 
*/}}
{{- define "backend.labels" -}}
helm.sh/chart: {{ include "backend.chart" . }}
{{- if .Chart.AppVersion -}}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- include "backend.selectorLabels" . -}}
{{- end -}}

{{/* 
Selector labels 
*/}}
{{- define "backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
