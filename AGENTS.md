# AGENTS.md

Este arquivo serve como guia para agentes de IA que venham a trabalhar neste repositório no futuro.

# Repository Guidelines

A Flutter application that measures tremors using accelerometer data and calculates a "BlueGuava" score (0-1000). Supports Android, iOS, and PWA.

## Project Structure

```
lib/
├── main.dart          # App entry point
├── models/            # Data models (e.g., Measurement)
├── screens/           # UI screens (e.g., HomeScreen)
├── services/          # Business logic (e.g., TremorService)
├── utils/             # Utilities & platform helpers
│   └── web_permission/# Conditional imports for safe Web sensor access
test/                  # Widget and unit tests
android/               # Android-specific configuration
web/                   # PWA assets and configuration
.github/workflows/     # CI/CD pipelines (Android deploy, Web deploy)
```

## Build & Development Commands

| Command | Description |
|---------|-------------|
| `flutter pub get` | Install dependencies |
| `flutter analyze` | Run static analysis (linting) |
| `flutter test` | Run all tests |
| `flutter run` | Run on connected device/emulator |
| `flutter build apk --release` | Build Android APK |
| `flutter build web` | Build PWA bundle |
| `flutter pub run flutter_launcher_icons` | Regenerate app icons |

## Coding Style & Conventions

- **Linting**: Uses `flutter_lints` (see `analysis_options.yaml`)
- **Indentation**: 2 spaces (Dart standard)
- **Naming**:
  - Files: `snake_case.dart`
  - Classes: `PascalCase`
  - Variables/functions: `camelCase`
- **No comments**: Write self-documenting code; use DartDocs only for public APIs

Run `flutter analyze` before committing to ensure code quality.

## Testing Guidelines

- **Framework**: `flutter_test`
- **Location**: `test/` directory
- **Naming**: `*_test.dart` suffix
- **Structure**: Follow AAA pattern (Arrange/Act/Assert)

Run tests with: `flutter test`

## Commit & Pull Request Guidelines

- **Commit format**: Use conventional commits with Portuguese descriptions
  - Example: `feat: adiciona fluxo de CI/CD para lançamento Android`
  - Prefixes: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
- **PRs**: Include a clear description of changes and link related issues
- **CI**: Ensure `flutter analyze` and `flutter test` pass before merging

## CI/CD Pipelines

- `deploy-web.yml`: Deploys PWA to web hosting (GitHub Pages)
- `publish-android.yml`: Builda e publica APKs assinados nas releases do GitHub

## Notas Técnicas Específicas

### Web PWA
- **Conditional Imports**: O projeto usa `lib/utils/web_permission/` para lidar com `dart:html` e `dart:js_util` de forma segura. **NÃO remova essa estrutura**, pois ela garante que o código compile para mobile sem erros de dependência web.
- **Base HREF**: O deploy assume subdiretório `/tremedometro/`. Se for alterado, ajuste `.github/workflows/deploy-web.yml`.

### Desktop
- O suporte a Desktop foi removido intencionalmente para focar em Mobile e PWA. Pastas `linux`, `windows` e `macos` foram excluídas.

### Android Signing (Assinatura de APK)

**CRÍTICO**: Para permitir atualizações do app sem desinstalar, todos os APKs devem ser assinados com o mesmo certificado.

#### Setup Local

1. Execute o script de geração: `./scripts/generate-keystore.sh`
2. Isso cria:
   - `android/app/upload-keystore.jks` (keystore - **NUNCA commite!**)
   - `android/key.properties` (credenciais - **NUNCA commite!**)
3. Faça backup da keystore em local seguro (perder = não poder mais atualizar o app)
4. Build: `flutter build apk --release` (já assina automaticamente)

#### Setup CI/CD (GitHub Actions)

Configure os seguintes **Repository Secrets**:
- `ANDROID_KEYSTORE_BASE64`: Keystore em base64 (`base64 -w 0 android/app/upload-keystore.jks`)
- `ANDROID_KEYSTORE_PASSWORD`: Senha do keystore
- `ANDROID_KEY_PASSWORD`: Senha da key
- `ANDROID_KEY_ALIAS`: Alias da key (padrão: `upload`)

O workflow `publish-android.yml` usa esses secrets para assinar APKs automaticamente.

#### Detalhes Técnicos

- `android/app/build.gradle.kts` carrega `key.properties` se existir
- Se `key.properties` não existir, usa debug key (apenas para desenvolvimento)
- `.gitignore` bloqueia commit de keystores e credenciais
- Documentação completa: `android/KEYSTORE_SETUP.md`

#### Troubleshooting

- **"App not installed"** ao atualizar = certificado diferente, reinstale com nova keystore consistente
- **CI/CD falha** = verifique se todos os 4 secrets estão configurados corretamente

---

## Feature: Auto-Update

Sistema de atualização automática que verifica novas versões do app ao abrir.

### Funcionamento

1. **Verificação**: Ao iniciar o app, o `AutoUpdateService` consulta a API do GitHub (`/repos/lucasliet/tremedometro/releases/latest`).
2. **Comparação**: Compara a versão remota com a versão local do app (do `pubspec.yaml` via `package_info_plus`).
3. **Notificação**: Se houver nova versão, exibe um dialog com:
   - Número da versão nova
   - Changelog da release
   - Botões "Agora não" e "Atualizar"
4. **Download**: Ao clicar em "Atualizar", abre o link de download do APK (Android) ou página de release no navegador.

### Intervalo de Verificação

- **Padrão**: 24 horas entre verificações
- **Cache**: Usa `SharedPreferences` para armazenar data da última verificação
- **Skip**: Se verificou recentemente (< 24h), não consulta a API

### Plataformas

- **Android**: ✅ Abre download direto do APK
- **iOS**: ✅ Abre página de release
- **Web**: ⏭️ Auto-update desabilitado (PWAs atualizam automaticamente pelo navegador)

### Testes

- Testes unitários em `test/services/auto_update_service_test.dart`
- Usa `mockito` para mockar requisições HTTP
- Cobertura: parsing de versões, comparação, detecção de APK, cache

### Dependências

- `package_info_plus`: Obter versão atual do app
- `url_launcher`: Abrir links de download
- `http`: Requisições à API do GitHub

---

## Feature: Calibração Dinâmica (Wanderboy)

Sistema para definir a referência da escala "BlueGuava 1" dinamicamente baseada em um usuário admin (Wanderboy).

### Conceitos
- **GuavaPrime**: Medida "crua" baseada na magnitude do acelerômetro (m/s² * 1000). Esta escala é interna e oculta do usuário final. Vai de 0 a Infinito.
- **BlueGuava**: Escala final exibida na UI. `BlueGuava = GuavaPrime / Referência`.
- **Referência ("O padrão BlueGuava 1")**: Valor de GuavaPrime que equivale a **1.0 BlueGuava**.
    - **Dinâmico**: É a média das últimas 4 medições do usuário Admin (Wanderboy).
    - **Fallback**: Se a API falhar, usa o valor **15.0** (GuavaPrime) como referência padrão.

### Build Flags
- **Admin**: `flutter run --dart-define=WANDERBOY=true`
  - Habilita cálculo de média móvel e envio (POST) para API.
- **User (Padrão)**: `flutter run`
  - Apenas lê (GET) a referência da API.

### Arquitetura de Calibração
1. App inicia -> Tenta buscar referência na API (`keyvaluedb.deno.dev`).
2. Se falhar -> Usa fallback (15).
3. **Modo Admin**: Ao finalizar medição, calcula nova média e atualiza API.
4. **Modo User**: Usa referência cacheada para calcular score exibido.

### Estratégia de Dados e Cache
- **Persistência**: O banco de dados local armazena o **GuavaPrime** (valor bruto).
- **Exibição Dinâmica**: A UI converte `GuavaPrime -> BlueGuava` em tempo real usando a referência atual. Isso permite que o histórico seja re-calibrado retroativamente.
- **Cache de API**: Usa estratégia *stale-while-revalidate*.
    1. Carrega referência do disco (rápido).
    2. Busca atualização na API em background.
    3. Se houver novidade, atualiza cache e UI silenciosamente.
4. **Sincronização em Tempo Real**:
    - O `CalibrationService` expõe um `referenceUpdateStream`.
    - O `TremorService` escuta esse stream e atualiza sua variável interna `_currentReference` instantaneamente.
    - Isso garante que, se a API atualizar o valor em background (ou via Hot Reload), a próxima medição já use o valor novo sem reiniciar o app.
    - Hot Reload (`r`) força uma chamada a `refreshReference()`.

### Feedback Visual
- O app exibe um `SnackBar` sempre que a referência é atualizada e difere da anterior (delta > 0.1).
- Isso confirma para o usuário (e para o Admin) que a calibração foi recebida com sucesso.

---
*Last Updated: 2025-12-28*
