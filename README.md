# LuminaPlan | Android (Flutter + Dart)

Aplicativo **offline** para agenda pessoal e gestão de entradas/saídas. Interface em português brasileiro, design Material 3, modo escuro/claro, calendário por mês/semana/dia, alertas opcionais no próprio Android e visão financeira.

## Recursos

- **Agenda flexível:** dias, semanas, meses, compromissos com horário e eventos de dia inteiro.
- **Movimentações financeiras:** entradas e saídas em R$, com categoria, anotação e data.
- **Repetição:** diária, semanal e mensal; editar uma recorrência modifica a série.
- **Previsto x realizado:** toque no círculo da transação para marcar recebimento/pagamento.
- **Alertas:** ligar/desligar globalmente, por tipo ou por lançamento, com aviso na hora, 5/10/30/60 minutos ou um dia antes.
- **Financeiro:** balanço mensal, entradas/saídas e resumo por categoria.
- **Privacidade:** dados locais no dispositivo; não acessa contas bancárias e não precisa de internet para funcionar.
- **Backup:** copiar/exportar conteúdo em JSON, importar pela seção Ajustes.

### IMPORTANTE: alertas

O Android pode atrasar alarmes inexatos para poupar bateria. O app usa alarmes **inexatos**, não solicita acesso a alarmes exatos. As recorrências são agendadas para os próximos 90 dias e são renovadas ao abrir o aplicativo. Permita notificações nas configurações do Android. Configurações do sistema, economia de bateria e modo Não Perturbe também afetam alertas. Alguns dispositivos podem interromper agendamentos.

### IMPORTANTE: armazenamento

O protótipo usa `shared_preferences` e **não** sincroniza em nuvem. É indispensável guardar backups periodicamente; limpar os dados, trocar de celular ou desinstalar o aplicativo pode apagar os registros. Não use como única fonte de dados financeiros importantes. Saldo mensal não representa saldo bancário real.

## Como gerar o APK sem computador, pelo celular

Você precisa de uma conta GitHub, navegador no celular e acesso a um **Codespace**. A compilação é feita nos servidores GitHub Actions (não no telefone). O fluxo é:

1. Entre em <https://github.com/new> e crie um repositório chamado `LuminaPlan` (pode ser **privado**). Marque **Add a README file**, escolha `main`.
2. Abra o repositório em **Code → Codespaces → Create codespace on main**. Se o menu móvel não aparecer, ative **Site para computador** no navegador.
3. No editor do Codespace aberto no navegador, use o explorador de arquivos → **Upload Files** para subir o ZIP `LuminaPlan_Flutter.zip` que foi enviado pelo ChatGPT para a pasta do repositório.
4. No terminal do Codespace, execute:

   ```bash
   unzip -o LuminaPlan_Flutter.zip
   rm LuminaPlan_Flutter.zip
   git add .
   git commit -m "Adicionar Planner Financeiro Flutter"
   git push
   ```

5. Na página do GitHub, abra **Actions → Build LuminaPlan APK**, entre na execução do commit e, ao concluir, baixe o artefato **LuminaPlan-APK**.
6. Extraia o arquivo ZIP de artefatos gerado pelo GitHub e toque em `app-release.apk` para instalar no Android. Permita a instalação desse arquivo nas configurações do sistema quando solicitado.

> Um APK ainda NÃO acompanha esta distribuição: não é possível compilá-lo sem o Flutter SDK e o Android SDK. O workflow incluído usa a versão estável do Flutter, instala dependências e gera o APK Android automaticamente. Sua execução precisa ser concluída no GitHub Actions.

**Se o ZIP for extraído dentro de outra subpasta no Codespace:** execute `unzip -l LuminaPlan_Flutter.zip | head` e confira se `pubspec.yaml` está na raiz. A raiz do projeto precisa conter `pubspec.yaml`, `lib/`, `tool/` e `.github/`.

## Como compilar no PC ou Codespace com Flutter

```bash
flutter create --platforms=android --org=com.luminaplan .
python3 tool/prepare_android.py
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release
```

Arquivo gerado: `build/app/outputs/flutter-apk/app-release.apk`.

## Arquitetura

- `lib/main.dart`: navegação, calendário e telas.
- `lib/models/plan_item.dart`: eventos e transações, serialização e recorrência.
- `lib/services/planner_store.dart`: persistência e cálculos de saldo.
- `lib/services/reminder_service.dart`: lembretes do Android.
- `lib/widgets/`: formulário e cartões de evento.
- `tool/prepare_android.py`: permissões, Gradle, ícone.
- `.github/workflows/android-apk.yml`: compilação remota do APK.

**Nota:** este é um projeto preparado para compilação, mas o compilador Flutter e um emulador Android não estavam disponíveis no ambiente em que o código foi criado. O APK precisa passar pela compilação e pelos testes no fluxo do GitHub antes de ser considerado validado.


## Identidade visual

- Nome Android: **LuminaPlan**.
- Ícone: coruja turquesa/esmeralda no fundo azul-marinho, sem bordas.
- Marca original: `assets/branding/luminaplan_wordmark.jpg`.
- Paleta: azul-noturno `#081522`, verde-menta `#28DFB1`, azul para eventos, verde para entradas e rosa para saídas.

O repositório não deve conter informações financeiras reais ou tokens de acesso. O app ainda não passou em testes reais de compilação Android.
