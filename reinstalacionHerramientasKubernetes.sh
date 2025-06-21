#!/bin/bash

# Script para obtener todas las versiones de controladores en Kubernetes
# Autor: Script para verificar versiones de componentes K8s
# Fecha: $(date)

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -n, --namespace NAMESPACE    Especificar namespace (default: kube-system)"
    echo "  -o, --output FORMAT          Formato de salida: table, json, yaml (default: table)"
    echo "  -s, --save FILE              Guardar resultado en archivo"
    echo "  -h, --help                   Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0                           # Listar controladores en kube-system"
    echo "  $0 -n default                # Listar en namespace default"
    echo "  $0 -o json -s versions.json  # Guardar en formato JSON"
}

# Valores por defecto
NAMESPACE="kube-system"
OUTPUT_FORMAT="table"
SAVE_FILE=""

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -s|--save)
            SAVE_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Verificar que kubectl está disponible
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl no está instalado o no está en el PATH${NC}"
    exit 1
fi

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: No se puede conectar al cluster de Kubernetes${NC}"
    exit 1
fi

# Función para obtener versiones en formato tabla
get_versions_table() {
    echo -e "${BLUE}=== Versiones de Controladores en namespace: ${NAMESPACE} ===${NC}"
    echo ""
    
    printf "%-40s %-50s %-20s\n" "POD NAME" "IMAGE" "VERSION"
    printf "%-40s %-50s %-20s\n" "--------" "-----" "-------"
    
    # Obtener todos los pods del namespace
    kubectl get pods -n "$NAMESPACE" -o json | jq -r '
        .items[] | 
        {
            name: .metadata.name,
            containers: .spec.containers[]
        } | 
        "\(.name)|\(.containers.image)"
    ' | while IFS='|' read -r pod_name image; do
        # Extraer la versión de la imagen
        if [[ $image == *":"* ]]; then
            image_name=$(echo "$image" | cut -d':' -f1)
            version=$(echo "$image" | cut -d':' -f2)
        else
            image_name="$image"
            version="latest"
        fi
        
        # Formatear el nombre de la imagen para mostrar solo la parte relevante
        short_image=$(basename "$image_name")
        
        printf "%-40s %-50s %-20s\n" "$pod_name" "$short_image" "$version"
    done
}

# Función para obtener versiones en formato JSON
get_versions_json() {
    kubectl get pods -n "$NAMESPACE" -o json | jq '{
        namespace: "'$NAMESPACE'",
        timestamp: now | strftime("%Y-%m-%d %H:%M:%S"),
        controllers: [
            .items[] | {
                name: .metadata.name,
                status: .status.phase,
                images: [
                    .spec.containers[] | {
                        name: .name,
                        image: .image,
                        version: (.image | split(":")[1] // "latest")
                    }
                ]
            }
        ]
    }'
}

# Función para obtener versiones en formato YAML
get_versions_yaml() {
    get_versions_json | yq eval -P
}

# Función para obtener información detallada de componentes específicos
get_detailed_info() {
    echo -e "${YELLOW}=== Información Detallada de Componentes AWS ===${NC}"
    echo ""
    
    # AWS Load Balancer Controller
    echo -e "${GREEN}AWS Load Balancer Controller:${NC}"
    kubectl get deployment -n "$NAMESPACE" aws-load-balancer-controller -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "No encontrado"
    echo ""
    
    # AWS Node (CNI)
    echo -e "${GREEN}AWS VPC CNI:${NC}"
    kubectl get daemonset -n "$NAMESPACE" aws-node -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "No encontrado"
    echo ""
    
    # EBS CSI Driver
    echo -e "${GREEN}EBS CSI Driver:${NC}"
    kubectl get deployment -n "$NAMESPACE" ebs-csi-controller -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "No encontrado"
    echo ""
    
    # CoreDNS
    echo -e "${GREEN}CoreDNS:${NC}"
    kubectl get deployment -n "$NAMESPACE" coredns -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "No encontrado"
    echo ""
    
    # Kube Proxy
    echo -e "${GREEN}Kube Proxy:${NC}"
    kubectl get daemonset -n "$NAMESPACE" kube-proxy -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "No encontrado"
    echo ""
}

# Función para generar comandos de reinstalación
generate_reinstall_commands() {
    echo -e "${YELLOW}=== Comandos de Reinstalación/Actualización ===${NC}"
    echo ""
    
    cat << 'EOF'
# AWS Load Balancer Controller
# Desinstalar:
helm uninstall aws-load-balancer-controller -n kube-system

# Reinstalar:
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=YOUR_CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# EBS CSI Driver
# Actualizar usando AWS CLI:
aws eks create-addon --cluster-name YOUR_CLUSTER_NAME --addon-name aws-ebs-csi-driver --resolve-conflicts OVERWRITE

# AWS VPC CNI
# Actualizar usando AWS CLI:
aws eks create-addon --cluster-name YOUR_CLUSTER_NAME --addon-name vpc-cni --resolve-conflicts OVERWRITE

# CoreDNS
# Actualizar usando AWS CLI:
aws eks create-addon --cluster-name YOUR_CLUSTER_NAME --addon-name coredns --resolve-conflicts OVERWRITE

# Kube Proxy
# Actualizar usando AWS CLI:
aws eks create-addon --cluster-name YOUR_CLUSTER_NAME --addon-name kube-proxy --resolve-conflicts OVERWRITE

# NVIDIA Device Plugin (si usas nodos GPU)
kubectl delete daemonset nvidia-device-plugin-daemonset -n kube-system
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml

EOF
}

# Ejecutar según el formato solicitado
case $OUTPUT_FORMAT in
    "table")
        result=$(get_versions_table)
        echo "$result"
        get_detailed_info
        echo ""
        generate_reinstall_commands
        ;;
    "json")
        result=$(get_versions_json)
        echo "$result"
        ;;
    "yaml")
        result=$(get_versions_yaml)
        echo "$result"
        ;;
    *)
        echo -e "${RED}Formato de salida no válido: $OUTPUT_FORMAT${NC}"
        echo "Formatos válidos: table, json, yaml"
        exit 1
        ;;
esac

# Guardar en archivo si se especifica
if [[ -n "$SAVE_FILE" ]]; then
    case $OUTPUT_FORMAT in
        "table")
            {
                get_versions_table
                echo ""
                get_detailed_info
                echo ""
                generate_reinstall_commands
            } > "$SAVE_FILE"
            ;;
        "json")
            get_versions_json > "$SAVE_FILE"
            ;;
        "yaml")
            get_versions_yaml > "$SAVE_FILE"
            ;;
    esac
    echo -e "${GREEN}Resultado guardado en: $SAVE_FILE${NC}"
fi

echo -e "${GREEN}¡Completado!${NC}"