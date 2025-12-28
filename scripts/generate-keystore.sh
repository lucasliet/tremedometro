#!/bin/bash

# Script para gerar keystore de release para Android
# Este script deve ser executado UMA VEZ para configurar a assinatura do app

set -e

KEYSTORE_PATH="android/app/upload-keystore.jks"
KEY_PROPERTIES_PATH="android/key.properties"

echo "🔐 Gerador de Keystore para Android"
echo "===================================="
echo ""

# Verifica se já existe
if [ -f "$KEYSTORE_PATH" ]; then
    echo "⚠️  Keystore já existe em: $KEYSTORE_PATH"
    read -p "Deseja sobrescrever? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Operação cancelada."
        exit 0
    fi
    rm -f "$KEYSTORE_PATH"
fi

# Parâmetros padrão
DEFAULT_ALIAS="upload"
DEFAULT_VALIDITY="10000"

echo "Configurações da keystore:"
read -p "Key Alias [$DEFAULT_ALIAS]: " KEY_ALIAS
KEY_ALIAS=${KEY_ALIAS:-$DEFAULT_ALIAS}

read -sp "Store Password: " STORE_PASSWORD
echo
read -sp "Confirme Store Password: " STORE_PASSWORD_CONFIRM
echo

if [ "$STORE_PASSWORD" != "$STORE_PASSWORD_CONFIRM" ]; then
    echo "❌ Senhas não coincidem!"
    exit 1
fi

read -sp "Key Password: " KEY_PASSWORD
echo
read -sp "Confirme Key Password: " KEY_PASSWORD_CONFIRM
echo

if [ "$KEY_PASSWORD" != "$KEY_PASSWORD_CONFIRM" ]; then
    echo "❌ Senhas não coincidem!"
    exit 1
fi

echo ""
echo "Informações do certificado:"
read -p "Nome completo: " CERT_NAME
read -p "Unidade organizacional: " CERT_OU
read -p "Organização: " CERT_O
read -p "Cidade: " CERT_L
read -p "Estado: " CERT_ST
read -p "Código do país (2 letras): " CERT_C

# Gera keystore
echo ""
echo "🔨 Gerando keystore..."

keytool -genkey -v \
    -keystore "$KEYSTORE_PATH" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity "$DEFAULT_VALIDITY" \
    -storepass "$STORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "CN=$CERT_NAME, OU=$CERT_OU, O=$CERT_O, L=$CERT_L, ST=$CERT_ST, C=$CERT_C"

# Cria key.properties
echo ""
echo "📝 Criando key.properties..."

cat > "$KEY_PROPERTIES_PATH" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=upload-keystore.jks
EOF

echo ""
echo "✅ Keystore criada com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo "1. NUNCA commite o arquivo key.properties ou a keystore"
echo "2. Faça backup da keystore em local seguro"
echo "3. Para CI/CD no GitHub, configure os secrets:"
echo "   - ANDROID_KEYSTORE_BASE64: $(base64 -w 0 $KEYSTORE_PATH | head -c 50)..."
echo "   - ANDROID_KEYSTORE_PASSWORD: $STORE_PASSWORD"
echo "   - ANDROID_KEY_PASSWORD: $KEY_PASSWORD"
echo "   - ANDROID_KEY_ALIAS: $KEY_ALIAS"
echo ""
echo "Para gerar o base64 completo do keystore:"
echo "  base64 -w 0 $KEYSTORE_PATH"
