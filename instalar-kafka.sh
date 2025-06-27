# INSTALACIÓN CORRECTA CON STORAGECLASS
helm install kafka bitnami/kafka \
  --namespace kafka-system \
  --set auth.clientProtocol=plaintext \
  --set auth.interBrokerProtocol=plaintext \
  --set kraft.enabled=true \
  --set controller.replicaCount=1 \
  --set broker.replicaCount=1 \
  --set broker.persistence.storageClass=gp3 \
  --set controller.persistence.storageClass=gp3 \
  --set broker.persistence.size=8Gi \
  --set controller.persistence.size=8Gi \
  --set metrics.kafka.enabled=true \
  --set metrics.jmx.enabled=true \
  --set serviceMonitor.enabled=true \
  --wait \
  --timeout=10m
# Crear el topic deshabilitando JMX
kubectl exec -n kafka-system $KAFKA_POD -- env JMX_PORT="" kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic torcal-gpu-trigger \
  --partitions 3 \
  --replication-factor 1

# Verificar topics
kubectl exec -n kafka-system $KAFKA_POD -- env JMX_PORT="" kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list