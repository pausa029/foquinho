// Função "quiz" do Foquinho (Supabase Edge Function).
// Recebe matéria e assunto (e, se quiser, um trecho do caderno), pede ao Gemini
// questões de múltipla escolha e devolve para o app.
//
// Segredos (Supabase → Edge Functions → Secrets), colados pelo dono do projeto:
//   GEMINI_API_KEY   chave do Google AI Studio (nunca vai para o app nem para o GitHub)
//   ALLOWED_EMAILS   e-mails que podem usar, separados por vírgula. Vazio = ninguém.
//   GEMINI_MODEL     (opcional) padrão: gemini-flash-latest
//   QUIZ_DAILY_MAX   (opcional) quizzes por pessoa por dia; padrão: 30

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
const fail = (status: number, error: string, message: string) => reply(status, { error, message });

// Contador simples por instância (protege contra cliques repetidos; o limite real é o do Google).
const usage = new Map<string, { day: string; n: number }>();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail(405, "method", "Use POST.");

  const supaUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? req.headers.get("apikey") ?? "";
  const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  if (!geminiKey) return fail(503, "not_configured", "O quiz ainda não foi configurado no servidor.");

  // 1) Quem está pedindo? Confere o login direto no Supabase Auth.
  const auth = req.headers.get("authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) return fail(401, "login", "Entre na sua conta para usar o quiz.");
  const ur = await fetch(`${supaUrl}/auth/v1/user`, { headers: { Authorization: auth, apikey: anon } });
  if (!ur.ok) return fail(401, "login", "Sua sessão venceu. Entre de novo.");
  const user = await ur.json();
  const email = String(user?.email ?? "").toLowerCase();

  // 2) Só quem está na lista pode usar (por enquanto, só o dono).
  const allowed = (Deno.env.get("ALLOWED_EMAILS") ?? "").toLowerCase().split(",").map((s) => s.trim()).filter(Boolean);
  if (!email || !allowed.includes(email)) {
    return fail(403, "not_allowed", "O quiz com IA ainda está em teste e não está liberado para esta conta.");
  }

  const today = new Date().toISOString().slice(0, 10);
  const max = Number(Deno.env.get("QUIZ_DAILY_MAX") ?? "30") || 30;
  const u = usage.get(email);
  const n = u && u.day === today ? u.n : 0;
  if (n >= max) return fail(429, "limit", `Limite de ${max} quizzes por dia atingido. Volte amanhã.`);

  // 3) Pedido
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    return fail(400, "body", "Pedido inválido.");
  }
  const clean = (v: unknown, len: number) => String(v ?? "").replace(/\s+/g, " ").trim().slice(0, len);
  const subject = clean(body.subject, 80);
  const topic = clean(body.topic, 160);
  const notes = String(body.text ?? "").trim().slice(0, 8000);
  const level = clean(body.level, 60) || "ensino médio";
  const count = Math.min(10, Math.max(3, Number(body.count) || 5));
  if (!subject && !topic && !notes) return fail(400, "empty", "Diga a matéria e o assunto.");

  const prompt = [
    `Você é um professor brasileiro criando um quiz para um aluno do ${level}.`,
    `Matéria: ${subject || "não informada"}.`,
    `Assunto: ${topic || "o conteúdo abaixo"}.`,
    notes ? `Baseie as questões neste material do aluno (use só o que estiver correto):\n"""\n${notes}\n"""` : "",
    `Crie ${count} questões de múltipla escolha, em português do Brasil, com exatamente 4 alternativas cada e só uma correta.`,
    "Varie a dificuldade (fácil, média e difícil), evite pegadinhas sobre detalhes sem importância e misture a posição da alternativa correta.",
    "Em 'explain', explique em 1 ou 2 frases simples por que a resposta certa está certa.",
  ].filter(Boolean).join("\n\n");

  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";
  const gr = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.7,
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          properties: {
            questions: {
              type: "ARRAY",
              items: {
                type: "OBJECT",
                properties: {
                  q: { type: "STRING" },
                  options: { type: "ARRAY", items: { type: "STRING" } },
                  answer: { type: "INTEGER" },
                  explain: { type: "STRING" },
                },
                required: ["q", "options", "answer", "explain"],
              },
            },
          },
          required: ["questions"],
        },
      },
    }),
  });
  if (gr.status === 429) return fail(429, "limit", "A IA está ocupada ou o limite grátis do dia acabou. Tente mais tarde.");
  if (!gr.ok) {
    console.error("gemini", gr.status, (await gr.text()).slice(0, 500));
    return fail(502, "ai", "A IA não respondeu agora. Tente de novo em instantes.");
  }
  const gj = await gr.json();
  const raw = gj?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? "").join("") ?? "";
  let parsed: { questions?: unknown[] } = {};
  try {
    parsed = JSON.parse(raw);
  } catch {
    return fail(502, "ai", "A IA mandou uma resposta estranha. Tente de novo.");
  }
  const questions = (parsed.questions ?? [])
    .map((x) => x as { q?: unknown; options?: unknown; answer?: unknown; explain?: unknown })
    .filter((x) => typeof x.q === "string" && Array.isArray(x.options) && x.options.length === 4 && Number.isInteger(x.answer) && (x.answer as number) >= 0 && (x.answer as number) < 4)
    .map((x) => ({ q: String(x.q), options: (x.options as unknown[]).map(String), answer: x.answer as number, explain: String(x.explain ?? "") }))
    .slice(0, count);
  if (questions.length === 0) return fail(502, "ai", "A IA não conseguiu montar as questões. Tente outro assunto.");

  usage.set(email, { day: today, n: n + 1 });
  return reply(200, { questions });
});
