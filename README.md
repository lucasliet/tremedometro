# BlueGuava Tremor App

O **BlueGuava** é um aplicativo Flutter inovador projetado para medir e quantificar tremores usando o acelerômetro do dispositivo. Ele oferece uma interface simples e moderna para realizar medições rápidas, calcular uma pontuação objetiva e acompanhar o histórico ao longo do tempo.

### 🌟 Funcionalidades Principais

*   **Algoritmo BlueGuava**: Converte dados brutos do acelerômetro em uma pontuação de 0 a 1000, filtrando a gravidade e normalizando a intensidade do movimento.
*   **Interface Intuitiva**: Design escuro (dark mode), contador regressivo animado e feedback visual por cores.
*   **Histórico Local**: Armazena automaticamente as últimas medições.
*   **Multiplataforma**: Funciona nativamente no **Android** e como **Progressive Web App (PWA)** no navegador.
*   **Suporte iOS Web**: Lógica especializada para solicitar permissões de sensor no iOS Safari.

---

### 📥 Download

Baixe a versão mais recente do APK para Android na página de Releases:

[**⬇️ Baixar APK (GitHub Releases)**](https://github.com/lucasliet/blueguava/releases)

---

### 🚀 Build local

#### Pré-requisitos
*   Flutter SDK (v3.10+)
*   Android Studio / VS Code

#### Instalação

1.  Clone o repositório:
    ```bash
    git clone https://github.com/lucasliet/blueguava.git
    cd blueguava
    ```

2.  Instale as dependências:
    ```bash
    flutter pub get
    ```

#### Executando o App

*   **Android**:
    Conecte seu dispositivo e execute:
    ```bash
    flutter run
    ```
    *Nota: Certifique-se de autorizar a depuração USB no seu dispositivo.*

*   **Web**:
    ```bash
    flutter run -d chrome
    ```

---

### 📦 CI/CD

#### GitHub Pages

O projeto conta com um **GitHub Action** configurado para deploy automático.

1.  Faça push para a branch `main`.
2.  O workflow irá compilar a versão web e publicar na branch `gh-pages`.
3.  Acesse em: `https://lucasliet.github.io/tremedometro/`

Se precisar rodar manualmente o deploy:
1.  Vá na aba **Actions** do GitHub.
2.  Selecione "Deploy to GitHub Pages".
3.  Clique em **Run workflow**.

#### Gerando APK (Release)
```bash
flutter build apk --release
```

---

### 🛠️ Estrutura do Projeto

*   `lib/services/tremor_service.dart`: Coração do app. Contém a lógica de acesso aos sensores, filtro passa-alta e cálculo do score.
*   `lib/screens/home_screen.dart`: UI principal.
*   `lib/utils/web_permission/`: Utilitários para lidar com permissões de sensores na Web (compatibilidade iOS).
*   `.github/workflows/`: Workflows de automação CI/CD.

---

### 📝 Notas de Desenvolvimento

*   **Ícones**: Gerados via `flutter_launcher_icons`. Para atualizar, substitua `assets/icon.jpg` e rode: `flutter pub run flutter_launcher_icons`.
*   **Plataformas**: Mobile nativo e PWA.