// Verify the existing share RPC before signing any private storage object.
// Deploy with --no-verify-jwt: anonymous visitors authenticate with the share
// slug/password or recipient token, never with an owner's session.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export async function handleShareMedia(
  request: Request,
  env: (key: string) => string | undefined,
  fetcher: typeof fetch = fetch,
): Promise<Response> {
  const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
    status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
  if (request.method === "OPTIONS") return new Response(null, { headers: cors });
  if (request.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  try {
    const raw = await request.text();
    if (raw.length > 8192) return reply({ error: "Request too large" }, 413);
    const { resolver, params } = JSON.parse(raw);
    const keys: Record<string, string[]> = {
      resolve_share_by_slug: ["p_slug"],
      resolve_share_with_password: ["p_slug", "p_password"],
      resolve_share_by_token: ["p_token"],
    };
    if (!Object.hasOwn(keys, resolver) || !params ||
        !keys[resolver].every((key) => typeof params[key] === "string" && params[key].length > 0 && params[key].length <= 1024)) {
      return reply({ error: "Invalid share request" }, 400);
    }
    const url = env("SUPABASE_URL");
    const anon = env("SUPABASE_ANON_KEY");
    const service = env("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !anon || !service) return reply({ error: "Media service unavailable" }, 503);
    const verified = await fetcher(`${url}/rest/v1/rpc/${resolver}`, {
      method: "POST",
      headers: { apikey: anon, Authorization: `Bearer ${anon}`, "Content-Type": "application/json" },
      body: JSON.stringify(Object.fromEntries(keys[resolver].map((key) => [key, params[key]]))),
    });
    if (!verified.ok) return reply({ error: "Share unavailable" }, 403);
    const payload = await verified.json();
    if (!payload?.document || !payload?.profile) return reply({ error: "Share unavailable" }, 403);
    if (payload.document.profileSnapshot) payload.profile = payload.document.profileSnapshot;
    const owner = payload.document.ownerId;
    if (typeof owner !== "string" || payload.profile.id !== owner) return reply({ error: "Share unavailable" }, 403);
    const sections = payload.document.design?.sections ?? [];
    const projectSections = sections.filter((s: any) => s.kind === "projects" && s.visible !== false);
    const included = payload.document.includedProjectIds;
    const allowedProjects = (payload.profile.projects ?? []).filter((p: any) =>
      p.visible !== false && (!Array.isArray(included) || included.includes(p.id)) &&
      projectSections.some((s: any) => !(s.hiddenEntryIds ?? []).includes(p.id)));
    const paths = new Map<string, string>();
    const collect = (path: unknown) => {
      if (typeof path !== "string") return;
      let stored = path;
      // Older app versions persisted a getPublicUrl() or a temporary signed
      // URL even though this bucket is private. Only repair our own origin.
      if (/^https?:\/\//i.test(path)) {
        try {
          const source = new URL(path);
          if (source.origin !== new URL(url).origin) return;
          const match = source.pathname.match(/^\/storage\/v1\/object\/(?:public|sign|authenticated)\/document-media\/(.+)$/);
          if (!match) return;
          const segments = match[1].split('/').map(decodeURIComponent);
          if (segments.some((part) => /[/\\]/.test(part))) return;
          stored = segments.join('/');
        } catch (_) { return; }
      }
      if (stored.startsWith(`${owner}/`) && !stored.includes('\\') &&
          !stored.split('/').some((part) => part === '..' || part === '.' || part === '')) {
        paths.set(path, stored);
      }
    };
    for (const project of allowedProjects) for (const path of project.media ?? []) collect(path);
    const customSections = payload.profile.custom_sections ?? payload.profile.customSections ?? [];
    for (const section of customSections) {
      const matching = sections.filter((s: any) => s.kind === "custom" && s.customSectionId === section.id);
      const configs = matching.filter((s: any) => s.visible !== false);
      for (const entry of section.entries ?? []) {
        if (entry.visible !== false && (matching.length === 0 || configs.some((s: any) => !(s.hiddenEntryIds ?? []).includes(entry.id)))) collect(entry.imageUrl);
      }
    }
    // Portfolio photos are settings on this document, never CV profile content.
    const avatar = payload.document.design?.portfolioAvatar;
    if (payload.document.type === "portfolio") {
      if (avatar?.visible !== false) collect(avatar?.path ?? payload.profile.details?.avatarUrl);
    } else {
      collect(payload.profile.details?.avatarUrl);
    }
    if (paths.size > 200) return reply({ error: "Too many media objects" }, 422);
    const signed: Record<string, string> = {};
    // One Storage request signs all authorized objects, instead of making the
    // page wait for multiple sequential batches of individual signing calls.
    if (paths.size > 0) {
      const result = await fetcher(`${url}/storage/v1/object/sign/document-media`, {
        method: "POST", headers: { apikey: service, Authorization: `Bearer ${service}`, "Content-Type": "application/json" },
        body: JSON.stringify({ expiresIn: 3600, paths: [...new Set(paths.values())] }),
      });
      if (result.ok) {
        const body = await result.json();
        if (Array.isArray(body)) for (const item of body) {
          if (item.error || typeof item.path !== "string" || typeof item.signedURL !== "string") continue;
          // Accept only paths we authorized, including legacy URL aliases.
          for (const [original, path] of paths) if (path === item.path) {
            const destination = new URL(item.signedURL.startsWith('/')
              ? `${url}/storage/v1${item.signedURL}` : item.signedURL);
            if (destination.origin === new URL(url).origin &&
                destination.pathname.startsWith('/storage/v1/object/sign/document-media/')) {
              signed[original] = destination.toString();
            }
          }
        }
      }
    }
    // Return only the authorised path->URL mapping. Never return service keys,
    // hashes, arbitrary user-supplied paths or additional profile records.
    return reply({ urls: signed });
  } catch (_) {
    return reply({ error: "Media service unavailable" }, 500);
  }
}

if (import.meta.main) Deno.serve((request) => handleShareMedia(request, (key) => Deno.env.get(key)));
