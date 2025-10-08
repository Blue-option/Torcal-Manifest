#!/bin/bash

# Script interactivo para configurar credenciales del pipeline GitOps

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     🔑  Asistente de Configuración de Credenciales       ║
║           Pipeline GitOps - Torcal-ML                    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Variables globales
CREDENTIALS_FILE="$HOME/.torcal-credentials"
AWS_REGION="eu-west-1"
AWS_ACCOUNT_ID="651857781455"

# Función para guardar credenciales de forma segura
save_credential() {
    local key=$1
    local value=$2
    
    # Crear archivo si no existe
    touch "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    
    # Actualizar o agregar credencial
    if grep -q "^${key}=" "$CREDENTIALS_FILE" 2>/dev/null; then
        sed -i.bak "s|^${key}=.*|${key}=${value}|" "$CREDENTIALS_FILE"
    else
        echo "${key}=${value}" >> "$CREDENTIALS_FILE"
    fi
}

# Función para leer credencial
read_credential() {
    local key=$1
    if [ -f "$CREDENTIALS_FILE" ]; then
        grep "^${key}=" "$CREDENTIALS_FILE" 2>/dev/null | cut -d'=' -f2-
    fi
}

echo -e "${CYAN}Este script te ayudará a obtener y configurar todas las credenciales necesarias.${NC}"
echo ""
echo -e "${YELLOW}¿Qué necesitamos configurar?${NC}"
echo "  1. AWS Access Key ID"
echo "  2. AWS Secret Access Key"
echo "  3. AWS Region"
echo "  4. GitHub Personal Access Token"
echo ""
echo -e "${CYAN}Las credenciales se guardarán de forma segura en: ${CREDENTIALS_FILE}${NC}"
echo ""

read -p "Presiona ENTER para comenzar..."
clear

# ============================================
# 1. AWS ACCESS KEY
# ============================================
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Paso 1: Configurar AWS Access Key${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

EXISTING_KEY=$(read_credential "AWS_ACCESS_KEY_ID")
if [ ! -z "$EXISTING_KEY" ]; then
    echo -e "${YELLOW}Ya tienes una clave guardada: ${EXISTING_KEY:0:20}...${NC}"
    read -p "¿Quieres usar esta clave? (s/n): " use_existing
    if [[ "$use_existing" =~ ^[sS]$ ]]; then
        AWS_ACCESS_KEY_ID=$EXISTING_KEY
    else
        EXISTING_KEY=""
    fi
fi

if [ -z "$EXISTING_KEY" ]; then
    echo -e "${CYAN}Opciones para obtener AWS Access Key:${NC}"
    echo ""
    echo "  A) Crear nuevo usuario IAM (Recomendado)"
    echo "  B) Usar credenciales existentes de AWS CLI"
    echo "  C) Introducir manualmente"
    echo ""
    read -p "Selecciona una opción (A/B/C): " aws_option
    
    case $aws_option in
        [Aa])
            echo ""
            echo -e "${YELLOW}📋 Instrucciones para crear un nuevo usuario IAM:${NC}"
            echo ""
            echo "1. Abre tu navegador en:"
            echo "   ${CYAN}https://console.aws.amazon.com/iam/home#/users${NC}"
            echo ""
            echo "2. Haz clic en 'Create user' (Crear usuario)"
            echo ""
            echo "3. Nombre del usuario: ${GREEN}circleci-torcal-ml${NC}"
            echo ""
            echo "4. NO marques 'Provide user access to AWS Management Console'"
            echo ""
            echo "5. En permisos, selecciona 'Attach policies directly'"
            echo ""
            echo "6. Busca y selecciona: ${GREEN}AmazonEC2ContainerRegistryPowerUser${NC}"
            echo ""
            echo "7. Crea el usuario"
            echo ""
            echo "8. Ve al usuario → Security credentials → Create access key"
            echo ""
            echo "9. Selecciona 'Command Line Interface (CLI)'"
            echo ""
            echo "10. Copia las credenciales que te muestra"
            echo ""
            read -p "Presiona ENTER cuando hayas creado las credenciales..."
            echo ""
            read -p "Ingresa tu AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
            ;;
            
        [Bb])
            echo ""
            echo -e "${YELLOW}Buscando credenciales en AWS CLI...${NC}"
            if [ -f "$HOME/.aws/credentials" ]; then
                AWS_ACCESS_KEY_ID=$(grep -A 2 "\[default\]" ~/.aws/credentials | grep "aws_access_key_id" | cut -d'=' -f2 | tr -d ' ')
                if [ ! -z "$AWS_ACCESS_KEY_ID" ]; then
                    echo -e "${GREEN}✅ Credenciales encontradas!${NC}"
                    echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:20}..."
                else
                    echo -e "${RED}❌ No se encontraron credenciales${NC}"
                    read -p "Ingresa tu AWS_ACCESS_KEY_ID manualmente: " AWS_ACCESS_KEY_ID
                fi
            else
                echo -e "${RED}❌ Archivo ~/.aws/credentials no encontrado${NC}"
                read -p "Ingresa tu AWS_ACCESS_KEY_ID manualmente: " AWS_ACCESS_KEY_ID
            fi
            ;;
            
        [Cc])
            echo ""
            read -p "Ingresa tu AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
            ;;
            
        *)
            echo -e "${RED}Opción inválida${NC}"
            exit 1
            ;;
    esac
    
    save_credential "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
    echo -e "${GREEN}✅ AWS Access Key guardada${NC}"
fi

echo ""
read -p "Presiona ENTER para continuar..."
clear

# ============================================
# 2. AWS SECRET ACCESS KEY
# ============================================
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Paso 2: Configurar AWS Secret Access Key${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

EXISTING_SECRET=$(read_credential "AWS_SECRET_ACCESS_KEY")
if [ ! -z "$EXISTING_SECRET" ]; then
    echo -e "${YELLOW}Ya tienes una clave secreta guardada${NC}"
    read -p "¿Quieres usar esta clave? (s/n): " use_existing
    if [[ "$use_existing" =~ ^[sS]$ ]]; then
        AWS_SECRET_ACCESS_KEY=$EXISTING_SECRET
    else
        EXISTING_SECRET=""
    fi
fi

if [ -z "$EXISTING_SECRET" ]; then
    if [[ "$aws_option" == [Bb] ]] && [ -f "$HOME/.aws/credentials" ]; then
        AWS_SECRET_ACCESS_KEY=$(grep -A 2 "\[default\]" ~/.aws/credentials | grep "aws_secret_access_key" | cut -d'=' -f2 | tr -d ' ')
        if [ ! -z "$AWS_SECRET_ACCESS_KEY" ]; then
            echo -e "${GREEN}✅ Secret Key encontrada en AWS CLI${NC}"
        else
            read -sp "Ingresa tu AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY
            echo ""
        fi
    else
        read -sp "Ingresa tu AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY
        echo ""
    fi
    
    save_credential "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"
    echo -e "${GREEN}✅ AWS Secret Access Key guardada${NC}"
fi

echo ""
read -p "Presiona ENTER para continuar..."
clear

# ============================================
# 3. GITHUB TOKEN
# ============================================
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Paso 3: Configurar GitHub Personal Access Token${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

EXISTING_TOKEN=$(read_credential "GITHUB_TOKEN")
if [ ! -z "$EXISTING_TOKEN" ]; then
    echo -e "${YELLOW}Ya tienes un token guardado${NC}"
    read -p "¿Quieres usar este token? (s/n): " use_existing
    if [[ "$use_existing" =~ ^[sS]$ ]]; then
        GITHUB_TOKEN=$EXISTING_TOKEN
    else
        EXISTING_TOKEN=""
    fi
fi

if [ -z "$EXISTING_TOKEN" ]; then
    echo -e "${YELLOW}📋 Instrucciones para crear un GitHub Personal Access Token:${NC}"
    echo ""
    echo "1. Abre tu navegador en:"
    echo "   ${CYAN}https://github.com/settings/tokens${NC}"
    echo ""
    echo "2. Haz clic en 'Generate new token' → 'Generate new token (classic)'"
    echo ""
    echo "3. Nombre: ${GREEN}CircleCI Torcal-ML Pipeline${NC}"
    echo ""
    echo "4. Expiration: Selecciona 90 días o más"
    echo ""
    echo "5. Selecciona los siguientes scopes:"
    echo "   ${GREEN}✅ repo (Full control of private repositories)${NC}"
    echo "   ${GREEN}✅ workflow (Update GitHub Action workflows)${NC}"
    echo ""
    echo "6. Haz clic en 'Generate token'"
    echo ""
    echo "7. ${RED}⚠️  COPIA EL TOKEN INMEDIATAMENTE (solo se muestra una vez)${NC}"
    echo ""
    read -p "Presiona ENTER cuando estés listo para ingresar el token..."
    echo ""
    read -sp "Ingresa tu GITHUB_TOKEN: " GITHUB_TOKEN
    echo ""
    
    save_credential "GITHUB_TOKEN" "$GITHUB_TOKEN"
    echo -e "${GREEN}✅ GitHub Token guardado${NC}"
fi

echo ""
read -p "Presiona ENTER para continuar..."
clear

# ============================================
# 4. VERIFICACIÓN
# ============================================
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Paso 4: Verificando Credenciales${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verificar AWS
echo -e "${YELLOW}Verificando AWS credentials...${NC}"
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_REGION=$AWS_REGION

if aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}✅ AWS credentials válidas${NC}"
    aws sts get-caller-identity
    AWS_VALID=true
else
    echo -e "${RED}❌ AWS credentials inválidas${NC}"
    AWS_VALID=false
fi

echo ""

# Verificar GitHub
echo -e "${YELLOW}Verificando GitHub token...${NC}"
GITHUB_CHECK=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/Blue-option/Torcal-Manifest 2>&1)

if echo "$GITHUB_CHECK" | grep -q '"name"'; then
    echo -e "${GREEN}✅ GitHub token válido${NC}"
    echo "Repositorio accesible: Blue-option/Torcal-Manifest"
    GITHUB_VALID=true
else
    echo -e "${RED}❌ GitHub token inválido o sin permisos${NC}"
    GITHUB_VALID=false
fi

echo ""
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

# ============================================
# 5. EXPORTAR PARA CIRCLECI
# ============================================
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Paso 5: Configurar en CircleCI${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}Ahora debes configurar estas variables en CircleCI:${NC}"
echo ""
echo "1. Ve a: ${CYAN}https://app.circleci.com/pipelines/github/Blue-option/torcal-ml${NC}"
echo ""
echo "2. Haz clic en 'Project Settings' (engranaje)"
echo ""
echo "3. En el menú lateral, haz clic en 'Environment Variables'"
echo ""
echo "4. Agrega las siguientes variables:"
echo ""

# Crear archivo temporal con las variables
TMP_FILE=$(mktemp)
cat > "$TMP_FILE" << EOF
AWS_ACCESS_KEY_ID=$(read_credential "AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY=$(read_credential "AWS_SECRET_ACCESS_KEY")
AWS_REGION=$AWS_REGION
GITHUB_TOKEN=$(read_credential "GITHUB_TOKEN")
EOF

echo -e "${YELLOW}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${YELLOW}│ Variables a configurar en CircleCI:            │${NC}"
echo -e "${YELLOW}├─────────────────────────────────────────────────┤${NC}"
cat "$TMP_FILE" | while read line; do
    key=$(