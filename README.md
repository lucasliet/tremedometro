# Tremedômetro

O **Tremedômetro** é um aplicativo Flutter inovador projetado para medir e quantificar tremores usando o acelerômetro do dispositivo. Sua interface moderna e escala objetiva permitem acompanhar a intensidade do tremor de forma simples.

### 🌟 Funcionalidades Principais

*   **Escala BlueGuava**: Uma medida de intensidade relativa. O valor **1.0** representa o tremor de referência padrão (calibrado dinamicamente pela tremedeira do Wanderson Lopes). Valores maiores indicam tremores mais intensos (ex: 2.0 = dobro da referência).
*   **Interface Moderna**: Design escuro (dark mode), feedback visual imediato e histórico de medições.
*   **Multiplataforma**: Funciona nativamente no **Android** e via navegador (**PWA**), com suporte especial para iOS Safari.
*   **Auto-Update**: Verifica automaticamente por novas versões ao abrir o app e notifica o usuário.

---

### 📥 Download

Baixe a versão mais recente do APK para Android na página de Releases:

[**⬇️ Baixar APK (GitHub Releases)**](https://github.com/lucasliet/tremedometro/releases/latest)

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

### 📊 Como funciona o cálculo de tremedeira?

O Tremedômetro utiliza um sistema de medição em duas camadas para quantificar tremores de forma precisa e intuitiva:

#### GuavaPrime (Medida Bruta)

A medida bruta, chamada **GuavaPrime**, é calculada a partir dos dados do acelerômetro do dispositivo:

1. **Captura de Dados**: Durante 5 segundos, o app coleta dados do acelerômetro a cada 20ms (50Hz).

2. **Remoção de Gravidade**:
   - **Mobile**: Usa o sensor `UserAccelerometer` que já remove a gravidade automaticamente.
   - **Web**: Aplica um filtro passa-alta manual para isolar apenas o movimento do usuário, removendo a influência da gravidade.

3. **Cálculo da Magnitude**: Para cada amostra, calcula-se a magnitude vetorial:
   ```
   magnitude = √(x² + y² + z²)
   ```
   Onde x, y, z são as componentes da aceleração linear (em m/s²).

4. **GuavaPrime**: A média de todas as magnitudes multiplicada por 1000 para uma escala legível:
   ```
   GuavaPrime = média(magnitudes) × 1000
   ```

#### BlueGuava (Escala Relativa)

O **BlueGuava** é a escala final exibida ao usuário, calculada como:

```
BlueGuava = GuavaPrime / Referência
```

Onde a **Referência** é o valor médio das últimas 4 medições do usuário administrador (Wanderson Lopes). Isso cria uma escala relativa onde:
- **1.0** = tremor equivalente ao padrão de referência
- **< 1.0** = tremor mais leve que a referência
- **> 1.0** = tremor mais intenso que a referência

#### Por que essa abordagem?

1. **Calibração Dinâmica**: A referência pode ser atualizada sem invalidar medições antigas. Todo o histórico é recalculado automaticamente com a nova referência.

2. **Escala Intuitiva**: Usar um valor relativo (1.0 = referência) é mais fácil de interpretar do que valores brutos de aceleração.

3. **Persistência Inteligente**: Salvar o GuavaPrime (valor bruto) permite recalibrar retroativamente todas as medições.

4. **Precisão Cross-Platform**: O sistema se adapta às diferenças entre sensores nativos (mobile) e web, garantindo medições consistentes.

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
