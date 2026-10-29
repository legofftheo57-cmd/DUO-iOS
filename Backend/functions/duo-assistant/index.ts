// OPTIONAL server-side conversational assistant for DUO.
// Deploy only with explicit approval, service secrets and an actual provider budget.
// The app never embeds or receives the provider API key.
import { withSupabase } from "npm:@supabase/server@1";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return Response.json({ message: "Méthode non autorisée." }, { status: 405 });
    const apiKey = Deno.env.get("OPENAI_API_KEY");
    const model = Deno.env.get("DUO_AI_MODEL");
    if (!apiKey || !model) return Response.json({ message: "IA en ligne non activée." }, { status: 503 });
    let body: unknown;
    try { body = await req.json(); } catch { return Response.json({ message: "JSON invalide." }, { status: 400 }); }
    const question = typeof body === "object" && body !== null && "question" in body ? (body as {question?: unknown}).question : undefined;
    if (typeof question !== "string" || question.trim().length < 1 || question.length > 800) {
      return Response.json({ message: "Question absente ou trop longue." }, { status: 400 });
    }
    // The caller JWT is checked by withSupabase; SQL applies a per-user limit.
    const { data: allowed, error } = await ctx.supabase.rpc("consume_ai_quota");
    if (error) return Response.json({ message: "Quota IA indisponible." }, { status: 503 });
    if (allowed !== true) return Response.json({ message: "Limite quotidienne atteinte (5 questions)." }, { status: 429 });
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 16000);
    try {
      const upstream = await fetch("https://api.openai.com/v1/responses", {
        method: "POST", signal: controller.signal,
        headers: {"Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json"},
        body: JSON.stringify({
          model,
          max_output_tokens: 350,
          store: false,
          instructions: "Tu es DUO, assistant de vie à deux. Réponds en français, de manière courte et pratique. Donne des recettes simples, des critères d'achat et des idées d'organisation. Tu ne connais pas les prix, stocks ou promotions en temps réel. Ne les invente pas. Tu n'as pas accès au planning, aux données médicales ni aux achats du foyer. Ne prétends jamais modifier les données; aucune action n'est autorisée.",
          input: question.trim()
        })
      });
      if (!upstream.ok) return Response.json({ message: "Service IA temporairement indisponible." }, { status: 502 });
      const result = await upstream.json();
      const answer = (result.output ?? []).flatMap((entry: any) => entry.content ?? [])
        .filter((part: any) => part.type === "output_text")
        .map((part: any) => part.text ?? "").join("\n").slice(0, 4000);
      if (!answer) return Response.json({ message: "Réponse IA vide." }, { status: 502 });
      return Response.json({ answer }, { headers: { "Cache-Control": "no-store" } });
    } catch {
      return Response.json({ message: "Service IA inaccessible." }, { status: 504 });
    } finally { clearTimeout(timeout); }
  })
};
