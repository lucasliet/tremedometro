# Configuração de Assinatura do Android

Este guia explica como configurar a assinatura consistente para os APKs do Android, permitindo atualizações sem precisar desinstalar o app.

## Por que isso é necessário?

O Android exige que APKs sejam assinados com o mesmo certificado para permitir atualizações. Sem isso:
- ❌ Usuários precisam desinstalar o app antes de instalar uma nova versão
- ❌ Dados do app são perdidos
- ❌ Má experiência de usuário

Com assinatura consistente:
- ✅ Atualizações funcionam perfeitamente
- ✅ Dados são preservados
- ✅ Experiência profissional

## Setup Local (Desenvolvimento)

### 1. Gerar keystore

Execute o script de geração:

```bash
chmod +x scripts/generate-keystore.sh
./scripts/generate-keystore.sh
```

O script irá:
- Criar `android/app/upload-keystore.jks`
- Criar `android/key.properties` com as credenciais
- Guiá-lo através do processo interativo

### 2. Fazer backup da keystore

⚠️ **CRÍTICO**: Faça backup da keystore em local seguro!

```bash
# Copie para um local seguro (ex: gerenciador de senhas, cofre)
cp android/app/upload-keystore.jks ~/backup/tremedometro-keystore-$(date +%Y%m%d).jks
```

**Se perder a keystore, NUNCA poderá atualizar o app na Play Store ou via APK!**

### 3. Verificar .gitignore

O `.gitignore` já está configurado para NÃO commitar:
- `key.properties`
- `*.keystore`
- `*.jks`

**NUNCA commite esses arquivos!**

### 4. Build do APK

Agora você pode fazer build de releases assinados:

```bash
flutter build apk --release
```

O APK será assinado automaticamente com sua keystore.

## Setup CI/CD (GitHub Actions)

Para que o GitHub Actions possa assinar os APKs automaticamente:

### 1. Gerar base64 da keystore

```bash
base64 -w 0 android/app/upload-keystore.jks > keystore.txt
```

### 2. Configurar Secrets no GitHub

Vá em: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

Crie os seguintes secrets:

| Nome | Valor |
|------|-------|
| `ANDROID_KEYSTORE_BASE64` | Conteúdo do arquivo `keystore.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | A senha do store que você definiu |
| `ANDROID_KEY_PASSWORD` | A senha da key que você definiu |
| `ANDROID_KEY_ALIAS` | O alias da key (padrão: `upload`) |

### 3. Verificar workflow

O workflow `.github/workflows/publish-android.yml` já está configurado para:
1. Baixar a keystore do secret base64
2. Criar o `key.properties`
3. Assinar o APK automaticamente

### 4. Criar uma release

```bash
git tag v1.0.1
git push origin v1.0.1
```

O GitHub Actions irá:
- Buildar o APK assinado
- Criar uma release
- Anexar os APKs

## Troubleshooting

### Erro: "App not installed" ou "Update blocked"

Isso significa que o certificado mudou. Soluções:
1. **Desenvolvimento**: Delete o `key.properties` e keystore, gere novos
2. **Produção**: Restaure do backup da keystore original

### Erro: "keystore not found"

Verifique:
1. Arquivo `android/key.properties` existe?
2. Caminho da keystore em `key.properties` está correto?
3. Executou o script `generate-keystore.sh`?

### CI/CD falha na assinatura

Verifique:
1. Todos os 4 secrets estão configurados?
2. O base64 foi gerado com `-w 0` (sem quebras de linha)?
3. Senhas estão corretas?

## Informações Adicionais

### Keystore Parameters

- **Algoritmo**: RSA 2048 bits
- **Validade**: 10000 dias (~27 anos)
- **Localização**: `android/app/upload-keystore.jks`
- **Alias padrão**: `upload`

### Segurança

- ✅ Keystore em `.gitignore`
- ✅ Senhas apenas em secrets/variáveis de ambiente
- ✅ Backup em local seguro offline
- ❌ Nunca compartilhe a keystore publicamente
- ❌ Nunca commite credenciais no git
