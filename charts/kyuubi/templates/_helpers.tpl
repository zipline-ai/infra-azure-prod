{{/*
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "kyuubi.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "kyuubi.fullname" -}}
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
Create the name of the service account to use.
*/}}
{{- define "kyuubi.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "kyuubi.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the image reference.
*/}}
{{- define "kyuubi.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}

{{/*
A comma separated string of enabled frontend protocols, e.g. "REST,THRIFT_BINARY".
For details, see 'kyuubi.frontend.protocols': https://kyuubi.readthedocs.io/en/master/configuration/settings.html#frontend
*/}}
{{- define "kyuubi.frontend.protocols" -}}
  {{- $protocols := list }}
  {{- range $name, $frontend := .Values.server }}
    {{- if $frontend.enabled }}
      {{- $protocols = $name | snakecase | upper | append $protocols }}
    {{- end }}
  {{- end }}
  {{- if not $protocols }}
    {{ fail "At least one frontend protocol must be enabled!" }}
  {{- end }}
  {{- $protocols |  join "," }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kyuubi.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "kyuubi.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "kyuubi.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Kyuubi defaults configuration
*/}}
{{- define "kyuubi.kyuubiDefaults" -}}
kyuubi.frontend.protocols={{ include "kyuubi.frontend.protocols" . | trim }}
{{- if .Values.server.thriftBinary.enabled }}
kyuubi.frontend.thrift.binary.bind.port={{ .Values.server.thriftBinary.port }}
{{- end }}
{{- if .Values.server.thriftHttp.enabled }}
kyuubi.frontend.thrift.http.bind.port={{ .Values.server.thriftHttp.port }}
{{- end }}
{{- if .Values.server.rest.enabled }}
kyuubi.frontend.rest.bind.port={{ .Values.server.rest.port }}
{{- end }}
{{- if .Values.server.mysql.enabled }}
kyuubi.frontend.mysql.bind.port={{ .Values.server.mysql.port }}
{{- end }}
{{- if .Values.metrics.enabled }}
kyuubi.metrics.enabled=true
kyuubi.metrics.reporters={{ .Values.metrics.reporters }}
kyuubi.metrics.prometheus.port={{ .Values.metrics.prometheusPort }}
{{- end }}
{{- if index .Values.kyuubiConf.files "kyuubi-defaults.conf" }}
{{ tpl (index .Values.kyuubiConf.files "kyuubi-defaults.conf") . }}
{{- end }}
{{- end }}

{{/*
Spark defaults configuration
*/}}
{{- define "kyuubi.sparkDefaults" -}}
{{- if .Values.sparkConf.files }}
{{- range $key, $value := .Values.sparkConf.files }}
{{ $value }}
{{- end }}
{{- end }}
{{- end }}
