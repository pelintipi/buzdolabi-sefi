// Şef+ "yapay zekayla video tarifi" (Supabase Edge Function, Deno).
//
// Uygulama (lib/services/ai_recipe_client.dart) buraya video adresini,
// varsa açıklamasını ya da cihazda yazıya çevrilmiş konuşmasını ve katalogdaki
// malzeme kimliklerini gönderir. Fonksiyon:
//   1. Videoyu kimliğine göre önbellekte arar; varsa yapay zekayı hiç çağırmaz.
//   2. Yoksa Claude'a tarifi JSON şemasıyla çıkarttırır. Malzeme alanı yalnızca
//      gönderilen kimliklerden biri olabilir; katalogda olmayanlar "unmatched".
//   3. Sonucu saklar; aynı videoyu paylaşan sonraki herkes anında alır.
//
// Gizli anahtarlar (supabase secrets set ...): ANTHROPIC_API_KEY.
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Supabase tarafından verilir.
import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

const anthropic = new Anthropic(); // ANTHROPIC_API_KEY ortam değişkeninden
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

type Body = {
  url: string;
  caption?: string;
  transcript?: string;
  ingredients: { id: string; name: string }[];
};

const MEASURES = [
  "gram", "kilogram", "ml", "litre", "adet", "suBardagi", "cayBardagi",
  "yemekKasigi", "tatliKasigi", "cayKasigi", "kase", "tutam", "paket", "dis",
  "demet", "dilim",
];

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });

/** Kısa linki (vm.tiktok.com) açar, videonun sayısal kimliğini anahtar yapar. */
async function videoKey(url: string): Promise<{ key: string; resolved: string }> {
  let resolved = url;
  try {
    const res = await fetch(url, { method: "HEAD", redirect: "follow" });
    resolved = res.url || url;
  } catch (_) {
    // Ağ hatasında verilen adresle devam.
  }
  const id = resolved.match(/\/video\/(\d+)/)?.[1];
  const u = new URL(resolved);
  return { key: id ? `tiktok:${id}` : `${u.host}${u.pathname}`, resolved };
}

async function oembedCaption(url: string): Promise<string | undefined> {
  try {
    const res = await fetch(
      `https://www.tiktok.com/oembed?url=${encodeURIComponent(url)}`,
    );
    if (!res.ok) return undefined;
    return (await res.json()).title as string | undefined;
  } catch (_) {
    return undefined;
  }
}

function recipeSchema(ingredientIds: string[]) {
  return {
    type: "object",
    additionalProperties: false,
    required: [
      "isRecipe", "title", "minutes", "difficulty", "servings", "appliances",
      "techniques", "items", "steps", "tip", "unmatched",
    ],
    properties: {
      isRecipe: { type: "boolean" },
      title: { type: "string" },
      minutes: { type: "integer" },
      difficulty: { type: "string", enum: ["kolay", "orta", "zor"] },
      servings: { type: "integer" },
      appliances: {
        type: "array",
        items: { type: "string", enum: ["ocak", "firin", "airfryer", "blender"] },
      },
      techniques: {
        type: "array",
        items: {
          type: "string",
          enum: ["cig", "haslama", "sote", "kizartma", "firin", "karistirma"],
        },
      },
      items: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["ingredient", "amount", "measure", "role"],
          properties: {
            ingredient: { type: "string", enum: ingredientIds },
            amount: { type: "number" },
            measure: { type: "string", enum: MEASURES },
            role: { type: "string", enum: ["main", "side", "optional"] },
          },
        },
      },
      steps: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["text", "timerMinutes"],
          properties: {
            text: { type: "string" },
            timerMinutes: { type: "integer" },
          },
        },
      },
      tip: { type: "string" },
      unmatched: { type: "array", items: { type: "string" } },
    },
  };
}

const SYSTEM = `Türkçe yemek videolarının açıklamasından ya da konuşmasından tarif çıkarıyorsun.
Kurallar:
- Malzemeleri yalnızca verilen listedeki kimliklerle yaz. Listede karşılığı olmayan malzemeleri tarife ekleme; videoda yazdığı gibi "unmatched" listesine koy.
- Miktarı videoda geçen ölçüyle yaz (2 su bardağı → amount 2, measure suBardagi). Miktar hiç söylenmiyorsa tipik bir ev miktarı seç.
- En önemli bir-üç malzeme "main", tuz/baharat/yağ gibi destekleyiciler "side", "isteğe bağlı" denenler "optional".
- Adımları kısa, emir kipinde ve videodaki sırayla yaz. Bir adımda süre geçiyorsa timerMinutes'a dakika olarak yaz, yoksa 0.
- Metinde tarif yoksa (sadece "çok güzel oldu" gibi) isRecipe false döndür, diğer alanları boş bırak.
- tip: videoda verilen bir püf noktası varsa bir cümle, yoksa boş metin.`;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST bekleniyor" }, 405);
  let body: Body;
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: "Geçersiz JSON" }, 400);
  }
  if (!body.url || !Array.isArray(body.ingredients) || body.ingredients.length === 0) {
    return json({ error: "url ve ingredients gerekli" }, 400);
  }

  const { key, resolved } = await videoKey(body.url);

  // 1) Önbellek: konuşmadan çıkarılmış sonuç açıklamadan daha iyidir; konuşma
  // geldiyse ve önbellektekisi açıklamadansa yeniden çıkar.
  const { data: cached } = await db
    .from("video_recipes")
    .select("recipe, unmatched, source")
    .eq("video_key", key)
    .maybeSingle();
  if (cached && !(body.transcript && cached.source === "caption")) {
    await db.rpc("bump_video_recipe_hits", { p_key: key });
    return json({ recipe: cached.recipe, unmatched: cached.unmatched, cached: true });
  }

  const caption = body.caption ?? (await oembedCaption(resolved));
  if (!caption && !body.transcript) {
    return json({ error: "Videonun açıklamasına ulaşılamadı" }, 422);
  }

  const ingredientList = body.ingredients.map((i) => `${i.id}: ${i.name}`).join("\n");
  const userText = [
    `Kullanılabilir malzeme kimlikleri:\n${ingredientList}`,
    caption ? `Video açıklaması:\n${caption}` : "",
    body.transcript ? `Videodaki konuşma:\n${body.transcript}` : "",
  ].filter(Boolean).join("\n\n");

  let response;
  try {
    response = await anthropic.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: {
        effort: "low",
        format: {
          type: "json_schema",
          schema: recipeSchema(body.ingredients.map((i) => i.id)),
        },
      },
      system: SYSTEM,
      messages: [{ role: "user", content: userText }],
    });
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) {
      return json({ error: "Yoğunluk var, biraz sonra dene" }, 429);
    }
    if (error instanceof Anthropic.APIError) {
      console.error(`Claude API ${error.status}: ${error.message}`);
      return json({ error: "Tarif çıkarılamadı" }, 502);
    }
    throw error;
  }

  if (response.stop_reason === "refusal") {
    return json({ error: "Bu içerik işlenemedi" }, 422);
  }
  if (response.stop_reason === "max_tokens") {
    return json({ error: "Tarif çok uzun, çıkarılamadı" }, 422);
  }
  const text = response.content.find((b) => b.type === "text");
  if (!text || text.type !== "text") return json({ error: "Boş yanıt" }, 502);

  const out = JSON.parse(text.text);
  if (!out.isRecipe || out.items.length < 2) {
    return json({ error: "Bu videoda tarif bulunamadı" }, 422);
  }

  // Uygulamanın Recipe.fromJson biçimi (lib/models/recipe.dart).
  const recipe = {
    title: out.title,
    minutes: Math.max(5, out.minutes),
    difficulty: out.difficulty,
    servings: Math.min(12, Math.max(1, out.servings)),
    appliances: out.appliances,
    techniques: out.techniques,
    tags: [],
    items: out.items,
    steps: out.steps.map((s: { text: string; timerMinutes: number }) =>
      s.timerMinutes > 0 && s.timerMinutes <= 240
        ? { text: s.text, timerMinutes: s.timerMinutes, timerLabel: "Zamanlayıcı" }
        : { text: s.text }
    ),
    ...(out.tip ? { tip: out.tip } : {}),
  };

  await db.from("video_recipes").upsert({
    video_key: key,
    url: resolved,
    recipe,
    unmatched: out.unmatched,
    source: body.transcript ? "transcript" : "caption",
  });

  return json({ recipe, unmatched: out.unmatched, cached: false });
});
