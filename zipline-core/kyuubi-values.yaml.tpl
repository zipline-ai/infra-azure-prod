# Kyuubi Helm values template for Azure deployment
# This file is templated by Terraform

replicaCount: 1

podManagementPolicy: OrderedReady
minReadySeconds: 30
revisionHistoryLimit: 10

updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    partition: 0

image:
  repository: apache/kyuubi
  pullPolicy: IfNotPresent
  tag: 1.10.0-spark

imagePullSecrets: []

# Pod labels for Azure workload identity
podLabels:
  azure.workload.identity/use: "true"

podAnnotations: {}

# ServiceAccount with Azure workload identity
serviceAccount:
  create: true
  name: kyuubi
  annotations:
    azure.workload.identity/client-id: "${workload_identity_client_id}"

# Priority class (disabled by default)
priorityClass:
  create: false
  name: ~
  value: 1000000000

# RBAC for Spark on Kubernetes
rbac:
  create: true
  rules:
    - apiGroups: [""]
      resources: ["pods", "services", "configmaps", "persistentvolumeclaims"]
      verbs: ["create", "get", "list", "watch", "patch", "delete", "deletecollection"]

service:
  type: ClusterIP
  annotations: {}
  headless:
    annotations: {}

# Ingress (disabled - using LoadBalancer service for REST)
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts: []
  tls: []

server:
  # Thrift Binary protocol (HiveServer2 compatible)
  thriftBinary:
    enabled: true
    port: 10009
    service:
      type: ClusterIP
      port: "{{ .Values.server.thriftBinary.port }}"
      nodePort: ~
      annotations: {}
      sessionAffinity: ~
      sessionAffinityConfig: {}

  # Thrift HTTP protocol (disabled)
  thriftHttp:
    enabled: false
    port: 10010
    service:
      type: ClusterIP
      port: "{{ .Values.server.thriftHttp.port }}"
      nodePort: ~
      annotations: {}
      sessionAffinity: ~
      sessionAffinityConfig: {}

  # REST API protocol
  rest:
    enabled: true
    port: 10099
    service:
      type: LoadBalancer
      port: "{{ .Values.server.rest.port }}"
      nodePort: ~
      annotations:
        service.beta.kubernetes.io/azure-dns-label-name: ${kyuubi_dns_label}
      sessionAffinity: ~
      sessionAffinityConfig: {}

  # MySQL compatible text protocol (disabled)
  mysql:
    enabled: false
    port: 3309
    service:
      type: ClusterIP
      port: "{{ .Values.server.mysql.port }}"
      nodePort: ~
      annotations: {}
      sessionAffinity: ~
      sessionAffinityConfig: {}

# Kyuubi configuration files
kyuubiConf:
  dir: /opt/kyuubi/conf
  files:
    'kyuubi-defaults.conf': |
      kyuubi.authentication=NONE
      kyuubi.operation.log.dir.root={{ .Values.logging.workDir }}/{{ .Values.logging.operationLogDir }}
      kyuubi.engine.operation.log.dir.root={{ .Values.logging.workDir }}/{{ .Values.logging.engineOperationLogDir }}
      # Spark UI URL pattern for Kubernetes - populates appUrl in batch status
      kyuubi.kubernetes.spark.appUrlPattern=http://{{ "{{SPARK_DRIVER_SVC}}" }}.kyuubi.svc:4040
    'log4j2.xml': |
      <?xml version="1.0" encoding="UTF-8"?>
      <Configuration status="INFO">
        <Appenders>
          <Console name="stdout" target="SYSTEM_OUT">
            <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss.SSS} %p %c{1.}: %m%n%ex"/>
          </Console>
          <RollingFile name="file" fileName="{{ .Values.logging.dir }}/kyuubi-server.log"
                       filePattern="{{ .Values.logging.dir }}/kyuubi-server.log.%i">
            <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss.SSS} %p %c{1.}: %m%n%ex"/>
            <Policies>
              <SizeBasedTriggeringPolicy size="50MB"/>
            </Policies>
            <DefaultRolloverStrategy max="{{ .Values.logging.maxLogFiles }}"/>
          </RollingFile>
        </Appenders>
        <Loggers>
          <Root level="INFO">
            <AppenderRef ref="stdout"/>
            <AppenderRef ref="file"/>
          </Root>
          <Logger name="org.apache.kyuubi" level="INFO"/>
          <Logger name="org.apache.spark" level="WARN"/>
          <Logger name="org.apache.hadoop" level="WARN"/>
          <Logger name="org.apache.hive" level="WARN"/>
        </Loggers>
      </Configuration>
  filesFrom: []

# Hadoop configuration files
hadoopConf:
  dir: /opt/hadoop/conf
  files:
    'core-site.xml': |
      <?xml version="1.0"?>
      <configuration>
        <!-- Azure ABFS OAuth with Workload Identity -->
        <property>
          <name>fs.azure.account.auth.type.${azure_storage_account_name}.dfs.core.windows.net</name>
          <value>OAuth</value>
        </property>
        <property>
          <name>fs.azure.account.oauth.provider.type.${azure_storage_account_name}.dfs.core.windows.net</name>
          <value>org.apache.hadoop.fs.azurebfs.oauth2.MsiTokenProvider</value>
        </property>
      </configuration>
  filesFrom: []

# Spark configuration files
sparkConf:
  dir: /opt/spark/conf
  files:
    'spark-defaults.conf': |
      # Master URL for Kubernetes - required for KubernetesApplicationOperation to track apps
      spark.master=k8s://https://kubernetes.default.svc:443
      spark.submit.deployMode=cluster
      spark.kubernetes.container.image=ziplinecanary.azurecr.io/spark-azure:3.5.3
      spark.kubernetes.container.image.pullPolicy=IfNotPresent
      spark.kubernetes.namespace=kyuubi
      spark.kubernetes.authenticate.driver.serviceAccountName=kyuubi
      spark.kubernetes.authenticate.executor.serviceAccountName=kyuubi
      spark.driver.extraJavaOptions=-Divy.cache.dir=/tmp -Divy.home=/tmp
      spark.executor.extraJavaOptions=-Divy.cache.dir=/tmp -Divy.home=/tmp
      # Azure Workload Identity labels for driver and executor pods
      spark.kubernetes.driver.label.azure.workload.identity/use=true
      spark.kubernetes.driver.annotation.azure.workload.identity/client-id=${workload_identity_client_id}
      spark.kubernetes.executor.label.azure.workload.identity/use=true
      spark.kubernetes.executor.annotation.azure.workload.identity/client-id=${workload_identity_client_id}
  filesFrom: []

# Command and args (use defaults)
command: ~
args: ~

containers: []

# Resource requests and limits
resources: {}

# Liveness probe
livenessProbe:
  enabled: true
  httpGet:
    path: /api/v1/ping
    port: rest
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 10
  successThreshold: 1

# Readiness probe
readinessProbe:
  enabled: true
  httpGet:
    path: /api/v1/ping
    port: rest
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 10
  successThreshold: 1

# Persistence (disabled by default)
persistence:
  enabled: false
  accessModes:
    - ReadWriteOnce
  size: 10Gi
  storageClass: ~

# Pod scheduling
nodeSelector: {}
tolerations: []
affinity: {}
securityContext: {}

# Logging configuration
logging:
  dir: /opt/kyuubi/logs
  workDir: /opt/kyuubi/work
  maxLogFiles: 5
  operationLogDir: operation_logs
  engineOperationLogDir: engine_operation_logs

# Metrics configuration
metrics:
  enabled: true
  reporters: PROMETHEUS
  prometheusPort: 10019
  podMonitor:
    enabled: false
    podMetricsEndpoints: []
    labels: {}
  serviceMonitor:
    enabled: false
    endpoints: []
    labels: {}
  prometheusRule:
    enabled: false
    groups: []
    labels: {}
