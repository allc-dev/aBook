# 📖 BookQuest - Quiz Bíblico

Um aplicativo Flutter interativo de quiz bíblico onde você descobre de qual livro da Bíblia é o versículo apresentado.

## 🎯 Funcionalidades

- ✅ Quiz interativo com versículos bíblicos
- ✅ Sistema de pontuação e estatísticas
- ✅ Leitor de Bíblia integrado
- ✅ Múltiplas versões da Bíblia
- ✅ Histórico de leitura
- ✅ Temas personalizáveis
- ✅ Versão PRO com recursos extras
- ✅ Anúncios AdMob integrados
- ✅ Compras dentro do app

## 📱 Plataforma

Este aplicativo foi otimizado exclusivamente para **Android**.

## 🚀 Como executar o projeto

### Pré-requisitos

- [Flutter](https://flutter.dev/docs/get-started/install) (versão 3.7+)
- [Android Studio](https://developer.android.com/studio) ou [VS Code](https://code.visualstudio.com/)
- Android SDK configurado
- Git

### Passo a passo

1. **Clone o repositório**
   ```bash
   git clone https://github.com/seu-usuario/aBook.git
   cd aBook
   ```

2. **Configure as dependências**
   ```bash
   flutter pub get
   ```

3. **Configure os arquivos necessários**

   a) **AdMob (Anúncios)**
   ```bash
   # Copie o arquivo de exemplo
   cp lib/constants/ad_ids.dart.example lib/constants/ad_ids.dart
   
   # Edite o arquivo e substitua pelos seus IDs do AdMob
   # Para obter IDs do AdMob: https://apps.admob.com/
   ```

   b) **Configurações do Android**
   ```bash
   # Copie o arquivo de exemplo
   cp android/local.properties.example android/local.properties
   
   # Edite e ajuste os caminhos do Android SDK e Flutter SDK
   ```

   c) **Assinatura do APK (Para release)**
   ```bash
   # Copie o arquivo de exemplo
   cp android/key.properties.example android/key.properties
   
   # Gere sua chave de assinatura:
   keytool -genkey -v -keystore android/app/release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release
   
   # Edite android/key.properties com suas informações
   ```

4. **Execute o aplicativo**
   ```bash
   # Modo debug
   flutter run
   
   # Build para produção
   flutter build apk --release
   ```

## 🔧 Configuração do AdMob

Para configurar seus próprios anúncios:

1. Acesse [Google AdMob](https://apps.admob.com/)
2. Crie uma conta e adicione seu aplicativo
3. Crie unidades de anúncio (Banner)
4. Edite `lib/constants/ad_ids.dart` com seus IDs
5. Atualize `android/app/src/main/AndroidManifest.xml` com seu App ID

### IDs de teste incluídos

O projeto vem configurado com IDs de teste do Google AdMob que mostram anúncios de exemplo.

## 💳 Configuração de Compras (In-App Purchase)

Para ativar compras dentro do app:

1. Configure sua conta no [Google Play Console](https://play.google.com/console/)
2. Crie produtos de compra
3. Configure o arquivo `google-services.json` (se necessário)
4. Atualize os IDs dos produtos no código

## 🎨 Estrutura do Projeto

```
lib/
├── constants/          # Constantes (cores, strings, IDs)
├── database/          # Gerenciamento do banco de dados
├── models/            # Modelos de dados
├── providers/         # Gerenciadores de estado
├── screens/           # Telas do aplicativo
├── services/          # Serviços (quiz, leitura, compras)
├── utils/             # Utilitários
├── widgets/           # Widgets reutilizáveis
└── main.dart          # Arquivo principal
```

## 🛠️ Tecnologias Utilizadas

- **Flutter/Dart** - Framework principal
- **Provider** - Gerenciamento de estado
- **SQFlite** - Banco de dados local
- **Google Mobile Ads** - Monetização
- **In App Purchase** - Compras dentro do app
- **Shared Preferences** - Armazenamento local
- **FL Chart** - Gráficos e estatísticas

## 📊 Banco de Dados

O aplicativo utiliza um banco SQLite local contendo:
- Versículos bíblicos
- Estatísticas do usuário
- Histórico de leitura
- Configurações personalizadas

## 🤝 Contribuindo

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 📧 Contato

- GitHub: [@andrellopes](https://github.com/andrellopes)
- Email: seu-email@exemplo.com

## � Fonte dos Dados da Bíblia

Os bancos de dados SQLite da Bíblia foram obtidos do repositório [damarals/biblias](https://github.com/damarals/biblias), licenciado sob MIT. Este projeto referencia e utiliza esses dados conforme a licença.

## 🙏 Agradecimentos

- [damarals/biblias](https://github.com/damarals/biblias) pelos dados bíblicos em formato SQLite
- Comunidade Flutter pelos packages utilizados
- Google pela plataforma AdMob

---

**⭐ Se este projeto foi útil para você, considere dar uma estrela no repositório!**
