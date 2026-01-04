# AGENTS.md

Este arquivo serve como guia para agentes de IA que venham a trabalhar neste repositório no futuro.

> **⚠️ Mantenha este arquivo atualizado**: Sempre que fizer mudanças que alterem o contexto geral da aplicação (nova feature, novo serviço, mudança de arquitetura, novo workflow, etc.) ou que invalidem informações aqui documentadas, atualize as seções relevantes.

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
│   ├── web_permission/# Conditional imports for safe Web sensor permission
│   └── web_sensor_support/# Web sensor capability detection
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
- **Mocking**: Uses `mockito` with code generation

### Running Tests

Before running tests for the first time (or after changing mocked classes), generate the mock files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This is required because `mockito` uses code generation to create type-safe mocks. The generated files (`*.mocks.dart`) are gitignored and must be regenerated locally.

Then run tests with: `flutter test`

## Commit & Pull Request Guidelines

- **Commit format**: Use conventional commits with Portuguese descriptions
  - Example: `feat: adiciona fluxo de CI/CD para lançamento Android`
  - Prefixes: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`
- **PRs**: Include a clear description of changes and link related issues
- **CI**: Ensure `flutter analyze` and `flutter test` pass before merging

## CI/CD Pipelines

- `run-tests.yml`: Executa testes, linting e geração de ícones em PRs e pushes para `main`/`develop`
- `deploy-web.yml`: Deploys PWA to web hosting (GitHub Pages)
- `publish-android.yml`: Builda e publica APKs assinados nas releases do GitHub

## Notas Técnicas Específicas

### Web PWA
- **Conditional Imports**: O projeto usa `lib/utils/web_permission/` e `lib/utils/web_sensor_support/` para lidar com `dart:html` e `dart:js_util` de forma segura. **NÃO remova essa estrutura**, pois ela garante que o código compile para mobile sem erros de dependência web.
- **Base HREF**: O deploy assume subdiretório `/tremedometro/`. Se for alterado, ajuste `.github/workflows/deploy-web.yml`.
- **Web Sensor Support**: Sistema de detecção de suporte a sensores (`lib/utils/web_sensor_support/`) verifica:
  - Contexto seguro (HTTPS ou localhost) - obrigatório para DeviceMotionEvent
  - Disponibilidade do acelerômetro no navegador
  - Necessidade de permissão explícita (iOS Safari)
  - Feedback visual ao usuário quando sensor indisponível
- **Calibração Web**:
  - O acelerômetro web (`AccelerometerEvent`) retorna aceleração total (incluindo gravidade)
  - Mobile usa `UserAccelerometerEvent` (remove gravidade via fusão de sensores - giroscópio + acelerômetro + magnetômetro)
  - **Offset Empírico**: PWA Android aplica offset de **-7.0** no resultado final (calibração empírica vs mobile)
  - **Limitação**: Sem acesso ao giroscópio para fusão de sensores, filtros passa-alta não funcionam adequadamente quando há rotação do dispositivo
  - **Solução**: Offset fixo baseado em testes práticos entre PWA Android e app nativo
- **Error Handling Web**:
  - `cancelOnError: false` para resiliência a erros transientes
  - Contador de erros com limite de 5 falhas consecutivas
  - Apenas finaliza medição após múltiplos erros
- **iOS Safari - Não Suportado (PWA)**:
  - **Status**: PWA no iOS Safari está **DESABILITADO** devido a bugs críticos
  - **Bug Conhecido**: iOS 13.4+ retorna (0,0,0) mesmo após permissão concedida
  - **Workaround**: Usuários iOS devem usar o **app nativo Android** ou baixar APK pelo GitHub Releases
  - **Detecção**: App detecta iOS automaticamente e exibe mensagem explicativa bloqueando medição

### Desktop
- O suporte a Desktop foi removido intencionalmente para focar em Mobile e PWA. Pastas `linux`, `windows` e `macos` foram excluídas.

### Android Signing (Assinatura de APK)

APKs são assinados com keystore de release para permitir atualizações sem desinstalar.

- **Local**: Keystore em `android/app/upload-keystore.jks` + credenciais em `android/key.properties`
- **CI/CD**: GitHub Secrets configurados (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`)
- **Build**: `flutter build apk --release` assina automaticamente
- **Importante**: Keystore e credenciais estão em `.gitignore` (nunca commitar!)

---

## Feature: Auto-Update

Sistema de atualização automática que verifica, baixa e instala novas versões do app.

### Funcionamento

1. **Verificação**: Ao iniciar o app, o `AutoUpdateService` consulta a API do GitHub (`/repos/lucasliet/tremedometro/releases/latest`).
2. **Comparação**: Compara a versão remota com a versão local do app (do `pubspec.yaml` via `package_info_plus`).
3. **Detecção de Arquitetura**: Detecta automaticamente a ABI do dispositivo Android (`arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86`) via código nativo Kotlin.
4. **Seleção de APK**: Seleciona o APK correto da release baseado na arquitetura do dispositivo, com fallback para APK universal se necessário.
5. **Notificação**: Se houver nova versão, exibe um dialog com:
   - Número da versão nova
   - Changelog da release
   - Botões "Agora não" e "Atualizar"
6. **Download e Instalação**: Ao clicar em "Atualizar":
   - Baixa o APK correto automaticamente com feedback de progresso (usando `dio`)
   - Salva no diretório de cache do app (`/cache/apk/`)
   - Abre o instalador do Android automaticamente
   - Exibe SnackBars com progresso de download (10%, 20%, ..., 100%)
7. **Limpeza**: Na próxima abertura do app após instalação, remove automaticamente o APK do cache.

### Intervalo de Verificação

- **24 horas**: Respeita intervalo de 24h entre verificações para não sobrecarregar a API do GitHub
- **Exceção**: Se houver atualização disponível, o timestamp NÃO é salvo, fazendo o diálogo aparecer toda vez que o app abre até que o usuário atualize
- **Após atualização**: Quando o app é atualizado com sucesso, o timestamp é resetado automaticamente
- **Limpeza automática**: Remove APK do cache após primeira abertura do app atualizado

**Comportamento**:
1. App abre → Verifica se passou 24h desde última checagem
2. Se passou 24h → Consulta GitHub API
3. Se app está atualizado → Salva timestamp (não consulta de novo por 24h)
4. Se há atualização disponível → NÃO salva timestamp (continua mostrando diálogo toda vez)
5. Usuário atualiza → Na próxima abertura, limpa APK e reseta timestamp

### Plataformas

- **Android**: ✅ Download e instalação automática com detecção de arquitetura
- **iOS**: ❌ Não implementado (App Store gerencia atualizações)
- **Web**: ⏭️ Auto-update desabilitado (PWAs atualizam automaticamente pelo navegador)
- **Wanderboy (Admin)**: ⏭️ Auto-update **DESABILITADO** no modo admin para manter controle total sobre atualizações durante calibração

### Permissões Android

- `REQUEST_INSTALL_PACKAGES`: Permite instalar APKs
- `WRITE_EXTERNAL_STORAGE` (API ≤ 28): Permite salvar APK no cache
- `READ_EXTERNAL_STORAGE` (API ≤ 32): Permite ler APK do cache

### Código Nativo (Kotlin)

`MainActivity.kt` implementa três métodos via MethodChannel:
- `getDeviceAbi()`: Retorna a ABI preferida do dispositivo (`Build.SUPPORTED_ABIS[0]`)
- `installApk(apkPath)`: Abre o instalador do Android com o APK
- `deleteApk(apkPath)`: Remove o APK do cache (usado na limpeza)

Usa `FileProvider` para compartilhar o APK com o instalador de forma segura (necessário no Android 7.0+).

### Testes

- Testes unitários em `test/services/auto_update_service_test.dart`
- Usa `mockito` para mockar requisições HTTP
- Cobertura: parsing de versões, comparação, detecção de APK, seleção baseada em ABI

### Dependências

- `package_info_plus`: Obter versão atual do app
- `http`: Requisições à API do GitHub
- `dio`: Download com progresso
- `path_provider`: Acesso ao diretório de cache
- `device_info_plus`: Informações do dispositivo (não usado atualmente, mas disponível)

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
  - **Desabilita auto-update** para manter controle total sobre atualizações.
- **User (Padrão)**: `flutter run`
  - Apenas lê (GET) a referência da API.
  - Auto-update habilitado (Android).

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
*Last Updated: 2025-12-30*
