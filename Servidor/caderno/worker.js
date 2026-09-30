// Own-account notebook sync (Paridade/conta_propria_v1.json). Keeps only the encrypted notebook of each
// account and the SHA-256 of its credential; it never sees the sync code, the key or the content.
//
//   GET  /v1/caderno/{conta}   -> 200 encrypted file + ETag, or 404
//   PUT  /v1/caderno/{conta}   -> 204 + ETag; If-Match (or If-None-Match: * on the first upload),
//                                 412 when another device uploaded in between
// Authorization: Bearer {credencial} (64 hexadecimal characters).

const MAX_BYTES = 5_000_000;

const answer = (status, body = null, headers = {}) =>
  new Response(body === null ? null : JSON.stringify(body), {
    status,
    headers: { "Cache-Control": "no-store", ...(body === null ? {} : { "Content-Type": "application/json" }), ...headers },
  });

async function sha256Hex(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export default {
  async fetch(request, env) {
    const match = new URL(request.url).pathname.match(/^\/v1\/caderno\/([0-9a-f]{32})$/);
    if (!match) return answer(404, { erro: "caminho" });
    const authorization = request.headers.get("Authorization") || "";
    const credential = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
    if (!/^[0-9a-f]{64}$/.test(credential)) return answer(401, { erro: "credencial" });
    const owner = await sha256Hex(credential);
    const key = `cadernos/${match[1]}`;

    if (request.method === "GET") {
      const object = await env.CADERNOS.get(key);
      if (!object) return answer(404, { erro: "sem caderno" });
      if (object.customMetadata?.dono !== owner) return answer(403, { erro: "credencial" });
      return new Response(object.body, {
        headers: { "Content-Type": "application/octet-stream", ETag: object.httpEtag, "Cache-Control": "no-store" },
      });
    }

    if (request.method === "PUT") {
      const body = await request.arrayBuffer();
      if (body.byteLength === 0 || body.byteLength > MAX_BYTES) return answer(413, { erro: "tamanho" });
      const current = await env.CADERNOS.head(key);
      if (current && current.customMetadata?.dono !== owner) return answer(403, { erro: "credencial" });
      const ifMatch = request.headers.get("If-Match");
      const ifNoneMatch = request.headers.get("If-None-Match");
      if (current ? ifMatch !== current.httpEtag : ifNoneMatch !== "*") return answer(412, { erro: "versao" });
      const options = { customMetadata: { dono: owner }, ...(current ? { onlyIf: { etagMatches: current.etag } } : {}) };
      const stored = await env.CADERNOS.put(key, body, options);
      if (!stored) return answer(412, { erro: "versao" });
      return answer(204, null, { ETag: stored.httpEtag });
    }

    return answer(405, { erro: "metodo" }, { Allow: "GET, PUT" });
  },
};
