// Função "quiz" do Foquinho (Supabase Edge Function).
// Recebe matéria e assunto (e, se quiser, um trecho do caderno), pede ao Gemini
// questões de múltipla escolha e devolve para o app.
//
// Segredos (Supabase → Edge Functions → Secrets), colados pelo dono do projeto:
//   GEMINI_API_KEY   chave do Google AI Studio (nunca vai para o app nem para o GitHub)
//   ALLOWED_EMAILS   e-mails que podem usar, separados por vírgula. Vazio = ninguém.
//   GEMINI_MODEL     (opcional) modelos em ordem, separados por vírgula
//   QUIZ_DAILY_MAX   (opcional) quizzes por pessoa por dia; padrão: 30

// Só o site do Foquinho pode chamar pelo navegador (o app Android não manda "Origin").
const ORIGENS = new Set(["https://foquinho.com.br", "https://www.foquinho.com.br"]);
function corsPara(origin: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origin && ORIGENS.has(origin) ? origin : "https://foquinho.com.br",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}
// Até 3 fotos de ~3 MB em base64 + texto: acima disso, recusa sem ler.
const MAX_CORPO = 12 * 1024 * 1024;

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" },
  });
}
const fail = (status: number, error: string, message: string) => reply(status, { error, message });

// Contador simples por instância (protege contra cliques repetidos; o limite real é o do Google).
const usage = new Map<string, { day: string; n: number }>();

// Cada resposta recebe os cabeçalhos de CORS do próprio pedido (nada compartilhado entre pedidos).
Deno.serve(async (req) => {
  const res = await atender(req);
  const h = new Headers(res.headers);
  for (const [k, v] of Object.entries(corsPara(req.headers.get("origin")))) h.set(k, v);
  return new Response(res.body, { status: res.status, headers: h });
});

async function atender(req: Request): Promise<Response> {
  const origin = req.headers.get("origin");
  if (req.method === "OPTIONS") return new Response("ok");
  if (req.method !== "POST") return fail(405, "method", "Use POST.");
  // Navegador de outro site: recusa (sem "Origin" é o app, que é permitido).
  if (origin && !ORIGENS.has(origin)) return fail(403, "origin", "Pedido de um site não autorizado.");
  const tamanho = Number(req.headers.get("content-length") ?? "0");
  if (tamanho > MAX_CORPO) return fail(413, "grande", "As fotos estão grandes demais. Tente com menos fotos.");

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
  // E-mail precisa estar confirmado: impede alguém de criar conta com um e-mail liberado que não é dele.
  if (!user?.email_confirmed_at) return fail(403, "not_allowed", "Confirme o seu e-mail antes de usar o quiz.");

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
    const texto = await req.text();
    if (texto.length > MAX_CORPO) return fail(413, "grande", "As fotos estão grandes demais. Tente com menos fotos.");
    const j = JSON.parse(texto);
    if (!j || typeof j !== "object" || Array.isArray(j)) return fail(400, "body", "Pedido inválido.");
    body = j as Record<string, unknown>;
  } catch {
    return fail(400, "body", "Pedido inválido.");
  }
  const clean = (v: unknown, len: number) => String(v ?? "").replace(/\s+/g, " ").trim().slice(0, len);
  const subject = clean(body.subject, 80);
  const topic = clean(body.topic, 160);
  const notes = String(body.text ?? "").trim().slice(0, 8000);
  const level = clean(body.level, 60) || "ensino médio";
  const count = Math.min(10, Math.max(3, Number(body.count) || 5));
  // Fotos do caderno ou do livro (até 3, já reduzidas pelo app).
  const images = (Array.isArray(body.images) ? body.images : [])
    .map((x) => x as { mime?: unknown; data?: unknown })
    .filter((x) => typeof x.data === "string" && (x.data as string).length > 100 && (x.data as string).length < 3_000_000)
    .slice(0, 3)
    .map((x) => ({ inline_data: { mime_type: /^image\/(jpeg|png|webp|heic)$/.test(String(x.mime)) ? String(x.mime) : "image/jpeg", data: x.data as string } }));
  if (!subject && !topic && !notes && images.length === 0) return fail(400, "empty", "Diga a matéria e o assunto.");

  const prompt = [
    `Você é um professor brasileiro criando um quiz para um aluno do ${level}.`,
    `Matéria: ${subject || "não informada"}.`,
    `Assunto: ${topic || "o conteúdo abaixo"}.`,
    notes ? `Baseie as questões neste material do aluno (use só o que estiver correto):\n"""\n${notes}\n"""` : "",
    images.length
      ? [
        `${images.length === 1 ? "A imagem é uma foto" : "As imagens são fotos"} do caderno do aluno (o que o professor passou no quadro) ou do livro.`,
        "Primeiro leia com muita atenção, palavra por palavra. A letra pode ser feia, torta ou ter abreviações: use o contexto da matéria para entender cada palavra, sem inventar conteúdo que não está lá.",
        "Coloque em 'transcript' o texto que você leu, organizado e corrigido (no máximo 1500 caracteres). Se alguma parte estiver ilegível, escreva [ilegível].",
        "Depois faça as questões bem parecidas com o que está escrito, usando as mesmas palavras, exemplos e definições do caderno, como uma atividade básica do módulo, para o aluno lembrar do que copiou.",
      ].join("\n")
      : "",
    `Crie ${count} questões de múltipla escolha, em português do Brasil, com exatamente 4 alternativas cada e só uma correta.`,
    "Varie a dificuldade (fácil, média e difícil), evite pegadinhas sobre detalhes sem importância e misture a posição da alternativa correta.",
    "Em 'explain', explique em 1 ou 2 frases simples por que a resposta certa está certa.",
  ].filter(Boolean).join("\n\n");

  // Tenta modelos em ordem: o mais rápido primeiro; se estiver lotado, passa para o próximo.
  const models = (Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-lite-latest,gemini-2.5-flash-lite,gemini-flash-latest")
    .split(",").map((m) => m.trim()).filter(Boolean);
  const payload = JSON.stringify({
    contents: [{ role: "user", parts: [{ text: prompt }, ...images] }],
    generationConfig: {
      temperature: 0.7,
      responseMimeType: "application/json",
      responseSchema: {
        type: "OBJECT",
        properties: {
          transcript: { type: "STRING" },
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
  });
  // Conta a tentativa antes de chamar a IA: pedidos que falham também gastam a cota do Google.
  usage.set(email, { day: today, n: n + 1 });
  let gr: Response | null = null;
  let busy = false;
  // Foto de caderno pede leitura caprichada: começa pelo modelo que lê melhor letra de mão.
  const order = images.length ? ["gemini-flash-latest", "gemini-flash-lite-latest"] : models;
  for (const model of order) {
    try {
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey },
        body: payload,
        signal: AbortSignal.timeout(images.length ? 35000 : 15000),
      });
      if (r.ok) {
        gr = r;
        break;
      }
      console.error("gemini", model, r.status, (await r.text()).slice(0, 300));
      if (r.status === 429 || r.status >= 500) busy = true;
    } catch (e) {
      console.error("gemini", model, "timeout/erro", String(e));
      busy = true;
    }
  }
  if (!gr) {
    return busy
      ? fail(503, "busy", "A IA está muito ocupada agora. Tente de novo em 1 minuto.")
      : fail(502, "ai", "A IA não respondeu agora. Tente de novo em instantes.");
  }
  const gj = await gr.json();
  const raw = gj?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? "").join("") ?? "";
  let parsed: { questions?: unknown[]; transcript?: unknown } = {};
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

  const transcript = images.length && typeof parsed.transcript === "string" ? parsed.transcript.slice(0, 2000) : "";
  return reply(200, { questions, transcript });
}
