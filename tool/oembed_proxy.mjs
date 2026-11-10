// Yerel CORS proxy: TikTok/YouTube oEmbed + kısa link.
// TikTok oEmbed çoğu videoda title vermiyor → tikwm fallback.
import http from "node:http";

const PORT = 8787;

function send(res, status, body, type = "application/json; charset=utf-8") {
  res.writeHead(status, {
    "Content-Type": type,
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "*",
    "Cache-Control": "no-store",
  });
  res.end(body);
}

async function fetchJson(url) {
  const r = await fetch(url, {
    redirect: "follow",
    headers: { "User-Agent": "Mozilla/5.0 BuzdolabiSefiProxy/1.0" },
  });
  const text = await r.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch (_) {}
  return { ok: r.ok, status: r.status, url: r.url, text, json };
}

async function tikwmInfo(videoUrl) {
  const r = await fetchJson(
    `https://www.tikwm.com/api/?url=${encodeURIComponent(videoUrl)}`,
  );
  if (!r.ok || !r.json || r.json.code !== 0 || !r.json.data) return null;
  const d = r.json.data;
  const title = (d.title || d.desc || "").trim();
  if (!title) return null;
  return {
    version: "1.0",
    type: "video",
    title,
    author_unique_id: d.author?.unique_id || d.author?.nickname,
    author_name: d.author?.nickname,
    thumbnail_url: d.cover || d.origin_cover,
    provider_name: "TikTok",
    provider_url: "https://www.tiktok.com",
  };
}

async function tiktokOembed(videoUrl) {
  const endpoint = `https://www.tiktok.com/oembed?url=${encodeURIComponent(videoUrl)}`;
  const r = await fetchJson(endpoint);
  if (r.ok && r.json && typeof r.json.title === "string" && r.json.title.trim()) {
    return r.json;
  }
  // oEmbed boş title / eksik alan → tikwm
  const alt = await tikwmInfo(videoUrl);
  if (alt) return alt;
  return r.json; // kapak vs. varsa yine dön
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    send(res, 204, "");
    return;
  }
  try {
    const u = new URL(req.url || "/", `http://127.0.0.1:${PORT}`);
    if (u.pathname === "/oembed") {
      const target = u.searchParams.get("url");
      if (!target) {
        send(res, 400, JSON.stringify({ error: "url required" }));
        return;
      }
      const isYt = /youtube\.com|youtu\.be/i.test(target);
      if (isYt) {
        const endpoint = `https://www.youtube.com/oembed?url=${encodeURIComponent(target)}&format=json`;
        const r = await fetchJson(endpoint);
        send(res, r.ok ? 200 : r.status, r.text);
        return;
      }
      const info = await tiktokOembed(target);
      if (!info) {
        send(res, 404, JSON.stringify({ error: "no info" }));
        return;
      }
      send(res, 200, JSON.stringify(info));
      return;
    }
    if (u.pathname === "/resolve") {
      const target = u.searchParams.get("url");
      if (!target) {
        send(res, 400, JSON.stringify({ error: "url required" }));
        return;
      }
      const r = await fetch(target, {
        redirect: "follow",
        headers: { "User-Agent": "Mozilla/5.0" },
      });
      send(res, 200, JSON.stringify({ url: r.url }));
      return;
    }
    send(res, 404, JSON.stringify({ error: "not found" }));
  } catch (e) {
    send(res, 502, JSON.stringify({ error: String(e) }));
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`oembed_proxy on 0.0.0.0:${PORT}`);
});
