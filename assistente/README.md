# Assistente Pessoal — Central + Agentes (Claude Code)

Você conversa com a **central** (`CLAUDE.md`), que delega para os agentes especialistas:

| Agente | Cuida de |
|---|---|
| `financeiro` | gastos, receitas, metas, orçamento, investimentos, bolsa e cripto (Giro Rápido, Material de construção, Cacau, Pessoal) |
| `agenda` | reuniões, compromissos, lembretes, tarefas (Google Agenda + `memoria/agenda.md`) |

```
assistente/
├── .claude/agents/financeiro.md   # subagente de finanças
├── .claude/agents/agenda.md       # subagente de agenda
├── CLAUDE.md                      # central (orquestrador)
├── tools/google_calendar.py       # integração Google Agenda (OAuth)
├── memoria/*.modelo.md            # modelos (versionados)
├── memoria/financeiro.md          # dados reais (ignorado pelo git)
├── memoria/agenda.md              # dados reais (ignorado pelo git)
├── requirements.txt
└── .env.example
```

## 1. Instalar

```bash
cd assistente
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
cp memoria/financeiro.modelo.md memoria/financeiro.md
cp memoria/agenda.modelo.md memoria/agenda.md
```

## 2. Google Cloud — gerar `credentials.json`

1. Acesse <https://console.cloud.google.com/> e crie um projeto (ex.: "Assistente Alberto").
2. **APIs e serviços > Biblioteca** → busque **Google Calendar API** → **Ativar**.
3. **APIs e serviços > Tela de consentimento OAuth** → tipo **Externo** → preencha nome e e-mail → em **Usuários de teste**, adicione o seu e-mail do Google.
4. **APIs e serviços > Credenciais > Criar credenciais > ID do cliente OAuth** → tipo **App para computador** → Criar.
5. Clique em **Fazer download do JSON**, renomeie para `credentials.json` e coloque na pasta `assistente/`.

## 3. Primeiro login

```bash
python tools/google_calendar.py login
```

Abre o navegador → escolha a conta → autorize (se aparecer "app não verificado", clique em *Avançado > Acessar*). O `token.json` é gerado e os próximos usos não pedem login.

Teste:

```bash
python tools/google_calendar.py listar --dias 7
```

**Erro de autenticação?** Apague `token.json` e rode `login` de novo. O próprio script mostra esse passo a passo quando falha.

## 4. Usar a central

```bash
cd assistente
source .venv/bin/activate
claude
```

O Claude Code carrega o `CLAUDE.md` (central) e os agentes de `.claude/agents/`. Exemplos:

- "Lança saída de R$ 3.200 no Giro Rápido, categoria fornecedor, hoje."
- "Resumo de novembro do material de construção comparado com outubro."
- "Bitcoin: sobe ou cai essa semana?"
- "O que tenho hoje?" / "Minha semana."
- "Marca reunião com o contador sexta às 10h e me diz quanto gastei com fornecedor no mês."

A central confirma data/hora antes de criar eventos e nunca apaga nada sem sua confirmação.

## CLI da agenda

```bash
python tools/google_calendar.py listar --dias 7 [--json]
python tools/google_calendar.py criar --titulo "Reunião" --inicio 2026-11-25T14:00 --fim 2026-11-25T15:00 --lembrete 30
python tools/google_calendar.py atualizar --id ID --inicio 2026-11-25T15:00 --fim 2026-11-25T16:00
python tools/google_calendar.py cancelar --id ID
```

Fuso fixo: `America/Sao_Paulo`.

## Segurança

`credentials.json`, `token.json`, `.env` e `memoria/*.md` (exceto modelos) estão no `.gitignore` — nunca vão para o repositório.
