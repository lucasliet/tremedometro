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

## Notas Técnicas Específicas

### Web PWA
- **Conditional Imports**: O projeto usa `lib/utils/web_permission/` para lidar com `dart:html` e `dart:js_util` de forma segura. **NÃO remova essa estrutura**, pois ela garante que o código compile para mobile sem erros de dependência web.
- **Base HREF**: O deploy assume subdiretório `/tremedometro/`. Se for alterado, ajuste `.github/workflows/deploy-web.yml`.

### Desktop
- O suporte a Desktop foi removido intencionalmente para focar em Mobile e PWA. Pastas `linux`, `windows` e `macos` foram excluídas.

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

---
*Last Updated: 2025-12-27*
