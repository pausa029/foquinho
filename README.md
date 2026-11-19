# Foquinho

**Menos tela. Mais estudo e movimento.**

Aplicativo escolar, em português do Brasil, para ajudar estudantes a trocar parte do tempo de celular por estudo e atividade física. Feito em **Flutter** (Android, iOS e web com o mesmo código), com tom positivo, sem culpa, sem broncas e sem competição.

> Este repositório também publica, na raiz do site, a **página de apresentação** e a **versão web** do Foquinho (HTML, pasta `web_site/`, em `/web/`). O app Flutter fica em `/app/` no site e gera o APK.

## O que o app faz

| Área | Implementado |
|---|---|
| Perfil | Nome/apelido, série, matérias, matérias difíceis, assuntos, provas/trabalhos com data, esportes, metas de estudo/exercício/tela, janela de lembretes e período de silêncio. Tudo opcional, editável e apagável. Sem e-mail, telefone ou senha. |
| Painel | Metas do dia com progresso em texto + barra, tempo de tela **manual** (identificado como manual), próxima prova/trabalho, ações rápidas *Estudar agora*, *Pausa ativa*, *Ver plano*, sugestões personalizadas e lembrete gentil dentro do app. |
| Plano | Tarefas em *A estudar / Em andamento / Concluído*, com matéria, assunto, duração e prazo; matérias com dificuldade e assuntos; provas e trabalhos. |
| Planejamento | Aba Plano → Agenda. Quadro semanal ou mensal montado a partir das matérias, assuntos, dificuldades, provas e da disponibilidade informada (dias, horários, limite diário, duração e intervalo, datas bloqueadas). Regras fixas e sem IA: no máximo 80% do tempo livre, prova próxima primeiro, matéria difícil com o dobro de sessões, no máximo 2 sessões da mesma matéria por dia e nunca seguidas, revisão na véspera da prova. Criar, editar, mover (com aviso de conflito e horários alternativos), fixar, concluir, marcar incompleta ou não realizada, excluir; gerar de novo com prévia do que muda, preservando concluídas, fixadas e manuais; pausar e apagar. Aviso 10 min antes de cada sessão (app Android). |
| Sessões | Temporizador de estudo simples ou com intervalos (25/5, 50/10, personalizado); iniciar, pausar, retomar, cancelar, concluir; registro com minutos ajustáveis e observação; tarefa pode ser marcada como concluída. O tempo é contado pelo relógio do aparelho e sobrevive ao fechar o app. |
| Movimento | Lista editável de atividades (caminhada, alongamento, corrida, dança, bicicleta, futebol, exercício em casa e outras) com filtros de tempo e local; sugestões priorizam os esportes do estudante; temporizador e registro. |
| Sugestões | Só a partir do que foi cadastrado: prova próxima → matéria difícil → tarefa pendente → assuntos anotados. Sem dados inventados. |
| Sequência | Foguinho de dias seguidos com pelo menos uma sessão registrada. Um dia de folga por semana não quebra; sem punição ao recomeçar; mostra o recorde. |
| Histórico | Resumo semanal, gráfico por dia, dia sem registro aparece como *sem dados*, lista de sessões (com exclusão) e botão *Apagar histórico*. |
| Acessibilidade | Tema claro/escuro, segue o tamanho de fonte do sistema, rótulos para leitor de tela, progresso nunca só por cor, botões grandes. |
| Privacidade | Tudo fica no aparelho (`shared_preferences`, JSON). Sem servidor, sem conta, sem rastreadores. Botão para apagar perfil e dados. |

## O que **não** faz (de propósito, nesta versão)

- **Não lê o tempo de tela automaticamente.** No Android isso exige a permissão especial *Acesso a dados de uso* (`PACKAGE_USAGE_STATS`), ativada manualmente nas configurações; no iOS exige as APIs de *Screen Time* da Apple, com entitlement e aprovação especiais. Nenhuma das duas foi implementada, então o app **não afirma** monitorar nada: o tempo é informado pelo estudante e marcado como manual.
- **Não bloqueia nem limita outros apps.** Orienta a usar *Bem-estar digital* (Android) e *Tempo de Uso* (iPhone).
- **Notificações e alarme (app Android):** opcionais, ligadas em *Ajustes → Notificações e alarme* depois de uma explicação. Alarme no fim de cada fase do temporizador, lembretes diários de estudo e movimento, avisos de pausa de tela, tarefas com prazo e provas. Tudo agendado no aparelho (plugin `flutter_local_notifications`), sem servidor, para 7 dias, renovado ao abrir o app. Na versão web não há notificações com o app fechado. A permissão `USE_EXACT_ALARM` é usada para o alarme; na Play Store ela exige declarar o app como alarme/temporizador.
- **Não tem login nem nuvem.** Logo, não há senha para armazenar nem sincronização para fingir.

## Estrutura

```
lib/
  main.dart                 app, tema, navegação principal
  models/models.dart        modelos + JSON (perfil, matérias, provas, tarefas, atividades, sessões)
  data/app_state.dart       estado + persistência local + lógica do temporizador
  logic/stats.dart          resumos diários/semanais
  logic/suggestions.dart    sugestões personalizadas
  logic/planner.dart        planejamento de estudos (distribuição, conflitos, alternativas)
  logic/reminders.dart      o que agendar como notificação
  logic/streak.dart         sequência de dias
  models/plan.dart          disponibilidade e sessões planejadas
  services/notifier.dart    notificações locais
  ui/screens/               onboarding, início, plano, movimento, histórico, ajustes, sessão
  ui/widgets/common.dart    componentes compartilhados
test/                       testes unitários e de widget
web_site/                   página de apresentação (raiz) e versão web do app (/web/)
.github/workflows/build.yml compilação automática (APK, AAB, site)
```

As pastas `android/`, `ios/` e `web/` são geradas por `flutter create .` (o GitHub Actions faz isso e envia de volta ao repositório no primeiro build).

## Compilar na nuvem (sem instalar nada) — recomendado

1. Envie o código para a branch `main` (ou abra **Actions → Build Foquinho → Run workflow**).
2. Ao terminar, em **Actions → última execução → Artifacts** baixe:
   - `foquinho-apk-debug` → `app-debug.apk` (instala direto no Android)
   - `foquinho-aab-release` → `app-release.aab` (para a Play, depois de assinar; veja abaixo)
3. O site é publicado automaticamente no GitHub Pages: `https://<usuario>.github.io/foquinho/` (página de apresentação) e `https://<usuario>.github.io/foquinho/app/` (Foquinho web).

## Compilar no computador

Requisitos: Flutter 3.22 ou mais novo (o build na nuvem usa **3.27.4**), Android Studio com SDK e Java 17.

```bash
flutter create --org com.pausa029 --project-name foquinho --platforms android,ios,web .
flutter pub get
flutter test
flutter run                         # com um celular ligado por USB (depuração USB ativa) ou emulador
flutter build apk --debug           # build/app/outputs/flutter-apk/app-debug.apk
flutter build appbundle --release   # build/app/outputs/bundle/release/app-release.aab
flutter build web --release         # build/web/
```

Depois do `flutter create`, ajuste em `android/app/build.gradle` (ou `.kts`): `minSdk = 21` e, em `android/app/src/main/AndroidManifest.xml`, `android:label="Foquinho"`.

## Instalar o APK no Android

1. Baixe `app-debug.apk` no celular.
2. Abra o arquivo. O Android pede para permitir *instalar apps de fontes desconhecidas* para o navegador ou gerenciador de arquivos: permita só desta vez.
3. Toque em **Instalar**. O ícone *Foquinho* aparece na lista de apps.

APK de depuração serve para testar e distribuir diretamente; não serve para a Play Store.

## Versão mínima do Android

**Android 5.0 (API 21)**: é o mínimo que o Flutter 3.27 suporta, então o app compila para qualquer aparelho a partir daí. Nada abaixo disso é possível com Flutter. **Não foi testado em aparelhos reais** (veja "O que foi testado").

## Assinatura para a Play Store

O AAB gerado pelo robô usa a chave de **depuração**, que a Play rejeita. Para publicar:

```bash
keytool -genkey -v -keystore foquinho-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Crie `android/key.properties` (não entra no Git) com `storePassword`, `keyPassword`, `keyAlias=upload`, `storeFile=../foquinho-upload.jks`, configure `signingConfigs.release` no `android/app/build.gradle` conforme a [documentação do Flutter](https://docs.flutter.dev/deployment/android#signing-the-app) e rode `flutter build appbundle --release`. Guarde a chave: sem ela não há como atualizar o app na loja.

Conta Google Play: US$ 25 (uma vez). Contas pessoais novas precisam de teste fechado com testadores antes da publicação.

## iOS (iPhone)

- `flutter create --platforms ios .` gera a pasta `ios/`; abra `ios/Runner.xcworkspace` no **Xcode** (só em macOS).
- Compilar para um iPhone de verdade e distribuir exige conta **Apple Developer** (US$ 99/ano), certificados e, para outras pessoas, **TestFlight** ou **App Store**. Sem isso, não há como instalar em iPhone de terceiros.
- Alternativa sem custo usada aqui: a **versão web** no Safari → *Compartilhar → Adicionar à Tela de Início*. Funciona como app, com os mesmos dados locais. **APK é só Android.**
- Recursos de *Screen Time* (ler tempo de uso, limitar apps) dependem das APIs `FamilyControls`/`DeviceActivity`, de entitlement concedido pela Apple e de revisão: não estão nesta versão.

## O que foi testado — e o que não foi

- **Ambiente de desenvolvimento usado para escrever o código**: não tinha Flutter, Dart nem Android SDK, e a rede bloqueava o download deles. Por isso **nenhum arquivo foi compilado nem executado nesse ambiente**: nem APK, nem AAB, nem os testes.
- **Testes escritos** (`test/`): modelos e JSON, estatísticas, sugestões, estado do app e temporizador, e um teste de widget do fluxo inicial. Eles rodam no GitHub Actions (`flutter test`); o resultado aparece no log da execução.
- **Versões**: o build na nuvem usa Flutter 3.27.4, Java 17, `minSdk 21`, `compileSdk`/`targetSdk` padrão do Flutter 3.27.
- **Aparelhos físicos**: nenhum testado até o momento. Considere a primeira versão do APK como versão de teste.

## Privacidade (resumo)

Os dados ficam só no aparelho, no armazenamento privado do app. Não há envio para servidor, anúncios ou rastreadores. Desinstalar o app ou usar *Ajustes → Apagar perfil e todos os dados* remove tudo. O app não pede idade e não coleta dados de ninguém; menores de 18 anos devem combinar o uso com os responsáveis.

## Segurança

### O que já está protegido (automático)
- **Páginas do site** (`tool/seguranca_site.py`, roda a cada publicação): cada página recebe uma *Content-Security-Policy* que só deixa rodar os scripts da própria página (conferidos por hash SHA-256) e só conversar com o próprio site, o Supabase do Foquinho e as fontes do Google. Um script injetado não roda. Também recebe proteção contra *clickjacking* (a página se esconde se outro site a colocar dentro de um quadro) e *Referrer-Policy*.
- **Versão web (Flutter)** compilada com `--no-web-resources-cdn`: o motor gráfico vem do próprio site, não de um servidor de fora.
- **Dados na nuvem**: cada conta só lê e altera a própria linha (regras RLS em `supabase/schema.sql`). A chave que aparece no app e no site é a *publicável*, feita para ficar pública. A chave secreta nunca está no repositório.
- **Login**: com Google usa PKCE (o código de volta não serve para quem não tem o segredo guardado no aparelho). A página `conta.html` tira o código de acesso da barra de endereço logo que abre.
- **Quiz com IA** (`supabase/functions/quiz`): só e-mails liberados **e confirmados**, limite diário que conta também as tentativas que falham, pedido de no máximo 12 MB, e no navegador só aceita chamadas do próprio site.
- **GitHub Actions**: as ações de terceiros estão presas a uma versão exata (hash do commit), cada tarefa tem só a permissão de que precisa, e o Dependabot avisa quando houver atualização (`.github/dependabot.yml`).

### O que só o dono pode ligar (uma vez)
**Supabase** (supabase.com → projeto Foquinho):
1. *Authentication → Providers → Email*: **Confirm email** ligado e **Secure password change** ligado.
2. *Authentication → Policies / Passwords*: senha mínima de **8** caracteres e **Leaked password protection** ligado (bloqueia senhas vazadas).
3. *Authentication → URL Configuration*: **Site URL** `https://foquinho.com.br` e, em **Redirect URLs**, só `https://foquinho.com.br/conta.html` e `foquinho://login-callback`. Assim ninguém usa o seu login para mandar a pessoa para outro site.
4. *Authentication → Rate Limits*: deixe os limites padrão (ou mais baixos) para envio de e-mail e login.
5. *Edge Functions → quiz*: depois de colar o `index.ts` novo, clique em **Deploy** de novo (as proteções novas só valem depois disso).
6. *Advisors → Security Advisor*: rode e corrija o que aparecer em vermelho.

**GitHub** (Settings do repositório):
1. *Pages*: **Enforce HTTPS** ligado.
2. *Branches*: regra para a `main` (exigir pull request; bloquear *force push* e exclusão).
3. *Code security*: **Secret scanning** e **Push protection** ligados.
4. Sua conta do GitHub com **verificação em duas etapas** (2FA).

**Domínio** (onde o `foquinho.com.br` foi registrado): ligue o **DNSSEC** e o bloqueio de transferência.

### Chave de assinatura dos APKs (importante)
Os APKs de teste são assinados com chaves que estão **dentro do repositório** (`android/app/foquinho-teste.jks` e `lembra-ai/app/lembra-teste.jks`). Como o repositório é público, qualquer pessoa consegue assinar um APK falso que o Android aceita como "atualização" do Foquinho ou do Lembra Aí, se alguém for enganado a instalar.

Para fechar isso, os workflows já aceitam uma chave privada guardada nos **Secrets** do GitHub:
- Foquinho: `FOQUINHO_KEYSTORE_B64` (arquivo `.jks` em base64), `FOQUINHO_KEYSTORE_SENHA`, `FOQUINHO_KEY_ALIAS`.
- Lembra Aí: `LEMBRA_KEYSTORE_B64`, `LEMBRA_KEYSTORE_SENHA`, `LEMBRA_KEY_ALIAS`.

Ao trocar para a chave privada, quem já instalou precisa **desinstalar e instalar de novo uma vez** (o Android não aceita assinatura diferente), e no Lembra Aí é preciso trocar a impressão digital em `web_site/.well-known/assetlinks.json`. Sem os Secrets, tudo continua como antes, com um aviso no log da compilação.
