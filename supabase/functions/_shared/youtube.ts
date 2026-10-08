// Links do YouTube: para qual vídeo o link aponta e o endereço canônico dele.
// ESPELHA MaterialRules.youTubeVideoId (lib/features/ia_quiz/domain).

const VIDEO_ID = /^[A-Za-z0-9_-]{11}$/;

function host(url: URL): string {
  return url.hostname.toLowerCase().replace(/^(www|m|music)\./, "");
}

export function isYouTube(url: URL): boolean {
  const h = host(url);
  return h === "youtube.com" || h === "youtu.be" ||
    h === "youtube-nocookie.com" || h.endsWith(".youtube.com");
}

export type YouTubeLink =
  | { type: "video"; id: string; url: string }
  | { type: "playlist" }
  | { type: "channel" }
  | { type: "other" };

/** O que um link do YouTube aponta; `null` se o link não é do YouTube. */
export function parseYouTube(url: URL): YouTubeLink | null {
  if (!isYouTube(url)) return null;
  const parts = url.pathname.split("/").filter(Boolean);
  const first = parts[0] ?? "";

  let id: string | null = null;
  if (host(url) === "youtu.be") id = first;
  else if (first === "watch") id = url.searchParams.get("v");
  else if (["shorts", "live", "embed", "v", "e"].includes(first)) id = parts[1] ?? null;

  if (id && VIDEO_ID.test(id)) {
    return { type: "video", id, url: `https://www.youtube.com/watch?v=${id}` };
  }
  if (url.searchParams.has("list")) return { type: "playlist" };
  if (first.startsWith("@") || ["channel", "c", "user"].includes(first)) {
    return { type: "channel" };
  }
  return { type: "other" };
}
