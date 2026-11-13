# Lembra Aí

Agenda de compromissos para Android, feita para quem é esquecido e não tem costume com celular.
O app avisa **várias vezes**, tocando e vibrando, só no horário permitido (padrão 7h às 22h), até chegar a hora do compromisso.

- Tudo em português, letras e botões grandes, sem gestos escondidos.
- Funciona sem internet. Sem login, sem cadastro, sem anúncio. Os dados ficam só no celular.
- Android 8.0 ou mais novo.

---

## 1. Como baixar e instalar o APK

1. No celular, abra a página **Releases** do repositório e toque no lançamento mais recente chamado **"Lembra Aí 1.0.X"**.
2. Toque em **LembraAi.apk** para baixar.
3. Abra o arquivo baixado (pela notificação do download ou pelo app **Arquivos**).
4. Se aparecer *"Por segurança, seu celular não permite instalar apps desta fonte"*:
   toque em **Configurações**, ligue **Permitir desta fonte** e volte.
5. Toque em **Instalar** e depois em **Abrir**.

Para atualizar, é só instalar o APK novo por cima: a agenda continua lá (todos os APKs usam a mesma assinatura).

## 2. Como dar as permissões

Na primeira vez o app explica e pede uma permissão de cada vez. Toque em **PERMITIR** em todas:

| Permissão | Para que serve |
|---|---|
| Avisos (notificações) | Para o celular poder te avisar. |
| Alarmes | Para avisar na hora certinha. |
| Tela cheia | Para o aviso aparecer mesmo com o celular bloqueado. |
| Bateria sem restrição | Para o celular não desligar os avisos. |

Se alguma for negada, aparece um **aviso amarelo** no topo de *MEUS COMPROMISSOS* com o botão **ABRIR CONFIGURAÇÕES**, até ela ser dada.

**Xiaomi, Samsung e Motorola** costumam fechar apps em segundo plano. Em *⚙ Ajustes → Permissões e bateria* toque em **ABRIR AJUSTES DE BATERIA DO CELULAR** e:
- Xiaomi: ligue **Início automático** e escolha **Sem restrições** em Economia de bateria.
- Samsung: em Bateria escolha **Sem restrição** e tire o app de **Apps em suspensão**.
- Motorola: em Bateria do app escolha **Sem restrição**.

## 3. Como usar

- **📅 MEUS COMPROMISSOS**: calendário do mês (com *MÊS ANTERIOR*, *PRÓXIMO MÊS*, *HOJE* e *ESCOLHER MÊS*) e, embaixo, a lista do dia escolhido. Toque num compromisso para ver detalhes, **JÁ FIZ**, **EDITAR** ou **APAGAR**.
- **+ AGENDAR**: tudo já vem preenchido. Escolha o nome, o dia e a hora e toque em **SALVAR**. O app mostra um resumo para conferir, fala a confirmação e volta para o calendário no dia do compromisso.
- **Tela de alarme**: aparece na hora do compromisso e 1 hora antes (ou nos avisos especiais que você escolher), com **✓ JÁ FIZ / JÁ ESTOU INDO** e **LEMBRAR EM 10 MINUTOS**. Toca por até 2 minutos. Se ninguém responder, avisa de novo em 10 minutos, até 3 vezes.

## 4. Como testar

1. Abra **⚙ Ajustes → TESTAR AVISO AGORA**.
2. Bloqueie o celular e espere 10 segundos: o alarme de teste deve aparecer em tela cheia, tocar, vibrar e falar.
3. Agende um compromisso para daqui a uns minutos com *Avisar antes: 15 min* e confira os avisos.

### Testes automáticos (feitos)

Cálculo dos avisos, em `core/src/test` (rodam a cada envio no GitHub Actions). **25 de 25 passando.**

| Teste | Resultado |
|---|---|
| Exemplo obrigatório: sexta 10h30, 1 dia antes, de 1 em 1 hora. Quinta de 7h a 22h (16 avisos). Sexta: 7h, 8h, 9h, **9h30**, **10h30** | ✅ |
| Janela 7h–22h respeitada | ✅ |
| Compromisso fora da janela (6h e 23h), com e sem "avisar mesmo assim" | ✅ |
| Começar no mesmo dia com compromisso às 8h: só 7h e 8h | ✅ |
| Repetido a menos de 15 min de um aviso especial não toca | ✅ |
| Modo intervalo, inclusive personalizado (1h30) e mínimo de 15 min | ✅ |
| Modo quantidade (3 vezes → 7h, 14h30, 22h; máximo 20) | ✅ |
| Modo horários escolhidos, sem passar da hora do compromisso | ✅ |
| Janela diferente por compromisso | ✅ |
| Repetição semanal, dias da semana, a cada X dias, com data final | ✅ |
| Repetição mensal: dia 31 vira o último dia do mês; anual: 29/02 vira 28/02 | ✅ |
| Repetidos: avisos dos próximos 60 dias | ✅ |
| "Já fiz" cancela os avisos da ocorrência; a próxima repetição continua | ✅ |
| Edição recalcula; exclusão cancela | ✅ |
| Dois compromissos no mesmo dia: um aviso só ("Hoje você tem: Consulta às 10h30 e Banco às 15h.") | ✅ |
| Bom dia com os compromissos do dia | ✅ |
| Virada de mês e de ano | ✅ |
| Frases (datas por extenso, "Falta 1 hora e 20 minutos", resumo ao salvar, agenda para WhatsApp) | ✅ |

### Testes manuais (fazer no celular e anotar aqui)

| Teste | Resultado |
|---|---|
| Reiniciar o celular e ver se o alarme ainda toca | ⬜ a fazer |
| Celular bloqueado | ⬜ a fazer |
| No silencioso | ⬜ a fazer |
| No modo vibrar | ⬜ a fazer |
| Em economia de bateria | ⬜ a fazer |
| Em Não Perturbe | ⬜ a fazer |
| Adiar 10 minutos | ⬜ a fazer |
| Mudar a hora do celular | ⬜ a fazer |

## 5. Como funciona por dentro

```
core/            regras puras em Kotlin (sem Android), com os testes
  domain/        Modelo, Ocorrencias (repetição), CalculoAvisos, Mensagens, Texto
app/
  data/          Room (compromissos e avisos avulsos), Ajustes, cópia da agenda
  alarm/         Agendador (AlarmManager), Receptores (disparo, botões, reinício, mudança de hora),
                 AlarmeService (som de alarme, vibração e voz), AlarmeActivity (tela cheia), Notificacoes
  ui/            telas em Jetpack Compose: Boas-vindas, Meus compromissos, Agendar, Detalhes, Ajustes
```

- O Android limita quantos alarmes um app pode ter. Por isso o app agenda **só o próximo aviso**. Quando ele toca, o app mostra o que venceu e agenda o seguinte. A lista é recalculada a partir do banco, para os próximos 60 dias, a cada mudança, ao ligar o celular, ao mudar a hora ou o fuso e uma vez por dia (WorkManager).
- Avisos especiais usam `setAlarmClock`, e os repetidos usam `setExactAndAllowWhileIdle`.
- O banco fica no armazenamento que funciona antes do primeiro desbloqueio, então os alarmes voltam até antes de digitar a senha depois de reiniciar.
- O som do alarme sai pelo canal de **alarme** do Android: toca no silencioso e no modo vibrar. Na hora do alarme o volume de alarme vai para o nível escolhido em Ajustes e depois volta ao que era.
- No dia do compromisso, os lembretes repetidos param no primeiro aviso especial do dia (é o que faz o exemplo da sexta terminar em 9h, 9h30 e 10h30).

## 6. Compilar

Sem instalar nada: cada envio para a `main` roda o GitHub Actions (`.github/workflows/build.yml`), que testa, compila e publica o APK em **Releases**.

No computador (Android Studio ou JDK 17 + Android SDK):

```bash
./gradlew :core:test          # testes do cálculo dos avisos
./gradlew :app:assembleDebug  # APK em app/build/outputs/apk/debug/
```

### APK assinado (publicação)

O APK de Releases usa uma **chave de teste** (`app/lembra-teste.jks`), que está no repositório. Serve para instalar e atualizar sem perder a agenda, mas não para a Play Store. Para uma chave sua:

```bash
keytool -genkeypair -v -keystore minha-chave.jks -alias lembra -keyalg RSA -keysize 2048 -validity 10000
export LEMBRA_KEYSTORE=$PWD/minha-chave.jks LEMBRA_KEYSTORE_SENHA=... LEMBRA_KEY_ALIAS=lembra LEMBRA_KEY_SENHA=...
./gradlew :app:assembleRelease   # app/build/outputs/apk/release/app-release.apk
```

Guarde essa chave e as senhas em lugar seguro e **nunca** as envie para o repositório. Sem elas não dá para atualizar o app depois.

## 7. Limitações conhecidas

- Notificações não deixam o app escolher o tamanho da letra. O texto grande aparece na tela de alarme e dentro do app.
- Em alguns celulares a tela cheia só aparece com o celular bloqueado. Com ele desbloqueado, o alarme chega como aviso no topo, com os botões **JÁ FIZ** e **LEMBRAR EM 10 MIN**.
- Ditar o nome ("FALAR") depende do reconhecimento de voz do celular. Sem internet, só funciona se o pacote de voz em português estiver baixado.
- A voz depende do mecanismo de voz do celular com português instalado (normalmente o do Google).
- Em "Não perturbe" com **silêncio total**, o Android bloqueia até alarmes. O app mostra um aviso amarelo explicando como liberar.
- Editar um compromisso que repete muda todas as repetições. Não há edição de uma repetição só.
- O compromisso que repete é apagado inteiro (todas as repetições).

## 8. Melhorias futuras sugeridas (não feitas)

1. Widget na tela inicial com o próximo compromisso.
2. Contato de familiar: avisar um filho por SMS/WhatsApp quando um alarme ficar "Não respondido".
3. Editar ou pular uma única repetição.
4. Ler as notificações em voz com a tela bloqueada usando o alto-falante no volume máximo de forma gradual (aumentando aos poucos).
5. Cópia automática semanal da agenda para o Google Drive.
6. Modo "letra gigante" com só um compromisso por tela.
