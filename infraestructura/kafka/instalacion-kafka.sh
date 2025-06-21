# Crear namespace
kubectl create namespace kafka-system

# Instalar Strimzi Operator
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka-system' -n kafka-system

# Esperar que esté listo
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka-system --timeout=300s

# kafka-optimized.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: kafka-cluster
  namespace: kafka-system
spec:
  kafka:
    version: 3.8.0
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    config:
      # Configuración optimizada para single-replica
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
      
      # Optimización de recursos
      num.network.threads: 2
      num.io.threads: 4
      socket.send.buffer.bytes: 32768
      socket.receive.buffer.bytes: 32768
      socket.request.max.bytes: 104857600
      
      # Configuración para tu caso de uso (GPU scaling)
      auto.create.topics.enable: true
      delete.topic.enable: true
      log.retention.hours: 24          # Solo 1 día de retención
      log.retention.bytes: 536870912   # 512MB max por partition
      log.segment.bytes: 268435456     # 256MB por segmento
      log.cleanup.policy: delete
      
      # Compresión para ahorrar espacio
      compression.type: snappy
      
    storage:
      type: persistent-claim
      size: 5Gi  # Reducido de 10Gi
      class: gp3
      deleteClaim: false
      
    # Recursos optimizados
    resources:
      requests:
        memory: 1.5Gi  # Reducido de 2Gi
        cpu: 300m      # Reducido de 500m
      limits:  
        memory: 2.5Gi  # Reducido de 4Gi
        cpu: 800m      # Reducido de 1000m
        
    # JVM optimizada
    jvmOptions:
      -Xms: 768m
      -Xmx: 1536m
      -XX:+UseG1GC
      -XX:MaxGCPauseMillis: 20
      -XX:InitiatingHeapOccupancyPercent: 35
      -XX:+ExplicitGCInvokesConcurrent
      -Djava.awt.headless: true
      -Dsun.net.useExclusiveBind: false
      
    # Scheduling en nodos generales
    template:
      pod:
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: role
                  operator: In
                  values: [general]
                  
  zookeeper:
    replicas: 1
    storage:
      type: persistent-claim  
      size: 3Gi  # Reducido de 5Gi
      class: gp3
      deleteClaim: false
      
    # Recursos optimizados para Zookeeper
    resources:
      requests:
        memory: 512Mi  # Reducido de 1Gi
        cpu: 100m      # Reducido de 250m
      limits:
        memory: 1Gi    # Reducido de 2Gi
        cpu: 300m      # Reducido de 500m
        
    # JVM optimizada para Zookeeper
    jvmOptions:
      -Xms: 256m
      -Xmx: 512m
      -XX:+UseG1GC
      
    # Scheduling en nodos generales  
    template:
      pod:
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: role
                  operator: In
                  values: [general]
                  
  entityOperator:
    # Recursos mínimos para el operator
    topicOperator:
      resources:
        requests:
          memory: 128Mi
          cpu: 50m
        limits:
          memory: 256Mi
          cpu: 100m
    userOperator:
      resources:
        requests:
          memory: 128Mi
          cpu: 50m  
        limits:
          memory: 256Mi
          cpu: 100m
    template:
      pod:
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: role
                  operator: In
                  values: [general]

---
# Topic para GPU scaling
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: torcal-gpu-trigger
  namespace: kafka-system
  labels:
    strimzi.io/cluster: kafka-cluster
spec:
  partitions: 1  # Solo 1 partición necesaria
  replicas: 1
  config:
    retention.ms: 86400000     # 1 día
    segment.ms: 86400000       # 1 día
    cleanup.policy: delete
    max.message.bytes: 1048576 # 1MB max
    compression.type: snappy

---
# Service consistente
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: kafka-system
spec:
  selector:
    strimzi.io/cluster: kafka-cluster
    strimzi.io/kind: Kafka
    strimzi.io/name: kafka-cluster-kafka
  ports:
  - name: kafka-plain
    port: 9092
    targetPort: 9092