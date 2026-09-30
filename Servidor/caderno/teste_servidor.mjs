#!/usr/bin/env node
// Checks the notebook server at the given URL (local `wrangler dev` or the published Worker):
//   node Servidor/caderno/teste_servidor.mjs http://127.0.0.1:8787
import { randomBytes } from "node:crypto";

const base = (process.argv[2] || "http://127.0.0.1:8787").replace(/\/$/, "");
const account = randomBytes(16).toString("hex");
const credential = randomBytes(32).toString("hex");
const other = randomBytes(32).toString("hex");
const url = `${base}/v1/caderno/${account}`;
const auth = (c) => ({ Authorization: `Bearer ${c}` });
let failures = 0;
const check = (name, ok, detail = "") => {
  console.log(`${ok ? "ok  " : "FALHA"} ${name}${detail ? ` (${detail})` : ""}`);
  if (!ok) failures++;
};

let r = await fetch(url);
check("sem credencial: 401", r.status === 401, r.status);
r = await fetch(url, { headers: auth(credential) });
check("conta nova: 404", r.status === 404, r.status);
r = await fetch(url, { method: "PUT", headers: auth(credential), body: "x" });
check("primeiro envio sem If-None-Match: 412", r.status === 412, r.status);
const first = randomBytes(64);
r = await fetch(url, { method: "PUT", headers: { ...auth(credential), "If-None-Match": "*" }, body: first });
const etag = r.headers.get("ETag");
check("primeiro envio: 204 com ETag", r.status === 204 && !!etag, r.status);
r = await fetch(url, { headers: auth(credential) });
const got = Buffer.from(await r.arrayBuffer());
check("leitura devolve o mesmo arquivo", r.status === 200 && got.equals(first) && r.headers.get("ETag") === etag, r.status);
r = await fetch(url, { headers: auth(other) });
check("outra credencial: 403", r.status === 403, r.status);
r = await fetch(url, { method: "PUT", headers: { ...auth(other), "If-Match": etag }, body: "y" });
check("outra credencial nao grava: 403", r.status === 403, r.status);
const second = randomBytes(80);
r = await fetch(url, { method: "PUT", headers: { ...auth(credential), "If-Match": etag }, body: second });
const etag2 = r.headers.get("ETag");
check("segundo envio com a versao certa: 204", r.status === 204 && etag2 && etag2 !== etag, r.status);
r = await fetch(url, { method: "PUT", headers: { ...auth(credential), "If-Match": etag }, body: "z" });
check("envio com versao antiga: 412", r.status === 412, r.status);
r = await fetch(url, { method: "PUT", headers: { ...auth(credential), "If-Match": etag2 }, body: Buffer.alloc(5_000_001) });
check("arquivo grande demais: 413", r.status === 413, r.status);
r = await fetch(url, { headers: auth(credential) });
check("continua a segunda versao", Buffer.from(await r.arrayBuffer()).equals(second));
r = await fetch(`${base}/v1/caderno/../outra`, { headers: auth(credential) });
check("caminho invalido: 404", r.status === 404, r.status);
console.log(failures ? `${failures} falha(s)` : "Servidor do caderno: todas as verificacoes passaram.");
process.exit(failures ? 1 : 0);
