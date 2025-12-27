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

---
*Last Updated: 2025-12-27*
