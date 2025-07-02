#!/bin/bash

# Script para borrar PVCs de Neo4j, PostgreSQL y MinIO y recrearlos vacíos
# Esto eliminará completamente los datos y creará volúmenes nuevos

set -e

NAMESPACE="torcal-ml"

echo "🚨 ADVERTENCIA: Este script borrará COMPLETAMENTE los PVCs y creará nuevos vacíos para:"
echo "   - Neo4j (todos los volúmenes: data, logs, import, plugins)"
echo "   - PostgreSQL (volumen de datos)"
echo "   - MinIO (volumen de datos)"
echo ""
read -p "¿Estás seguro? Escribe 'RECREAR' para continuar: " confirmation

if [ "$confirmation" != "RECREAR" ]; then
    echo "Operación cancelada."
    exit 1
fi

echo "🔄 Iniciando proceso de borrado y recreación de PVCs..."

# 1. DETENER APLICACIÓN PRINCIPAL
echo ""
echo "🛑 Paso 1: Deteniendo aplicación torcal-ml..."
kubectl scale deployment torcal-ml --replicas=0 -n $NAMESPACE
kubectl wait --for=delete pod -l app=torcal-ml -n $NAMESPACE --timeout=120s || true

# 2. ELIMINAR Y RECREAR NEO4J
echo ""
echo "🗂️  Paso 2: Recreando Neo4j con PVCs vacíos..."

# Eliminar StatefulSet Neo4j (esto NO elimina los PVCs automáticamente)
echo "🗑️  Eliminando StatefulSet neo4j..."
kubectl delete statefulset neo4j -n $NAMESPACE --ignore-not-found=true

# Esperar a que los pods terminen
kubectl wait --for=delete pod -l app=neo4j -n $NAMESPACE --timeout=120s || true

# Eliminar PVCs de Neo4j manualmente
echo "🗑️  Eliminando PVCs de Neo4j..."
kubectl delete pvc data-neo4j-0 -n $NAMESPACE --ignore-not-found=true
kubectl delete pvc logs-neo4j-0 -n $NAMESPACE --ignore-not-found=true  
kubectl delete pvc import-neo4j-0 -n $NAMESPACE --ignore-not-found=true
kubectl delete pvc plugins-neo4j-0 -n $NAMESPACE --ignore-not-found=true

# Recrear StatefulSet Neo4j (creará PVCs nuevos)
echo "🔄 Recreando StatefulSet neo4j..."
kubectl apply -f application-aws/neo4j/neo4j-deployment.yaml
kubectl apply -f application-aws/neo4j/neo4j-service.yaml
kubectl apply -f application-aws/neo4j/neo4j-configmap.yaml

# Esperar a que Neo4j esté listo
echo "⏳ Esperando a que Neo4j esté listo..."
kubectl wait --for=condition=ready pod -l app=neo4j -n $NAMESPACE --timeout=300s

# 3. ELIMINAR Y RECREAR POSTGRESQL
echo ""
echo "🐘 Paso 3: Recreando PostgreSQL con PVC vacío..."

# Eliminar StatefulSet PostgreSQL
echo "🗑️  Eliminando StatefulSet postgres..."
kubectl delete statefulset postgres -n $NAMESPACE --ignore-not-found=true

# Esperar a que los pods terminen
kubectl wait --for=delete pod -l app=postgres -n $NAMESPACE --timeout=120s || true

# Eliminar PVC de PostgreSQL
echo "🗑️  Eliminando PVC de PostgreSQL..."
kubectl delete pvc data-postgres-0 -n $NAMESPACE --ignore-not-found=true

# Recrear StatefulSet PostgreSQL
echo "🔄 Recreando StatefulSet postgres..."
kubectl apply -f application-aws/postgres/postgres-deployment.yaml
kubectl apply -f application-aws/postgres/postgres-service.yaml

# Esperar a que PostgreSQL esté listo
echo "⏳ Esperando a que PostgreSQL esté listo..."
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s

# 4. ELIMINAR Y RECREAR MINIO
echo ""
echo "🪣 Paso 4: Recreando MinIO con PVC vacío..."

# Eliminar StatefulSet MinIO
echo "🗑️  Eliminando StatefulSet minio..."
kubectl delete statefulset minio -n $NAMESPACE --ignore-not-found=true

# Esperar a que los pods terminen
kubectl wait --for=delete pod -l app=minio -n $NAMESPACE --timeout=120s || true

# Eliminar PVC de MinIO
echo "🗑️  Eliminando PVC de MinIO..."
kubectl delete pvc data-minio-0 -n $NAMESPACE --ignore-not-found=true

# Recrear StatefulSet MinIO
echo "🔄 Recreando StatefulSet minio..."
kubectl apply -f application-aws/minio/minio-deployment.yaml
kubectl apply -f application-aws/minio/minio-service.yaml
kubectl apply -f application-aws/minio/minio-init-job.yaml

# Esperar a que MinIO esté listo
echo "⏳ Esperando a que MinIO esté listo..."
kubectl wait --for=condition=ready pod -l app=minio -n $NAMESPACE --timeout=300s

# 5. REINICIAR APLICACIÓN PRINCIPAL
echo ""
echo "🚀 Paso 5: Reiniciando aplicación torcal-ml..."
kubectl scale deployment torcal-ml --replicas=1 -n $NAMESPACE
echo "⏳ Esperando a que torcal-ml esté listo..."
kubectl wait --for=condition=ready pod -l app=torcal-ml -n $NAMESPACE --timeout=300s

# 6. VERIFICAR ESTADO
echo ""
echo "🔍 Verificando estado final..."
echo ""
echo "📊 Estado de los pods:"
kubectl get pods -n $NAMESPACE

echo ""
echo "💾 Estado de los PVCs (todos nuevos):"
kubectl get pvc -n $NAMESPACE

echo ""
echo "🔧 Información detallada de los PVCs:"
kubectl describe pvc -n $NAMESPACE | grep -E "(Name:|Status:|Volume:|Capacity:)" || true

echo ""
echo "✅ ¡Proceso completado!"
echo ""
echo "📋 Resumen de acciones realizadas:"
echo "   ✓ Neo4j: 4 PVCs eliminados y recreados vacíos (data, logs, import, plugins)"
echo "   ✓ PostgreSQL: 1 PVC eliminado y recreado vacío (data)"
echo "   ✓ MinIO: 1 PVC eliminado y recreado vacío (data)"
echo "   ✓ Todas las aplicaciones reiniciadas y funcionando"
echo ""
echo "🔧 Los PVCs son completamente nuevos con:"
echo "   - Volúmenes EBS nuevos en AWS"
echo "   - Sin datos previos"
echo "   - Configuraciones por defecto"
echo ""
echo "⚠️  Recuerda:"
echo "   1. Las aplicaciones pueden tardar unos minutos en inicializar completamente"
echo "   2. Neo4j y PostgreSQL crearán sus estructuras iniciales automáticamente"
echo "   3. MinIO estará vacío - necesitarás recrear buckets si es necesario"