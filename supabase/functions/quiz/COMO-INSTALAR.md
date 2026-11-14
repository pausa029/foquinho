# Instalar o quiz com IA (uma vez só, no PC)

1. Entre em supabase.com → projeto **Foquinho** → menu **Edge Functions**.
2. **Secrets** (ou "Manage secrets") → adicione:
   - `GEMINI_API_KEY` = a chave do Google AI Studio
   - `ALLOWED_EMAILS` = o seu e-mail da conta do Foquinho (só ele poderá usar)
3. **Deploy a new function** → "Via Editor" → nome: `quiz`.
4. Apague o exemplo e cole todo o conteúdo de `index.ts` (esta pasta) → **Deploy**.
5. Nas configurações da função `quiz`, desligue **"Verify JWT"** (a própria função já confere o login).
6. No app: entre na conta → Início → **Quiz com IA**.

Para liberar para mais alguém: acrescente o e-mail em `ALLOWED_EMAILS`, separado por vírgula.
A chave nunca vai para o app nem para o GitHub.
