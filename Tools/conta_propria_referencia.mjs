#!/usr/bin/env node
// Reference implementation of the own-account notebook sync shared by iOS and Android: the sync code,
// what is derived from it and the encrypted file. The native apps must reproduce these results
// exactly; Paridade/casos_conta_propria_v1.json holds the golden cases.
//
//   node Tools/conta_propria_referencia.mjs --atualizar   # regenerate expected outputs
//   node Tools/conta_propria_referencia.mjs --check       # verify cases are up to date
import { createCipheriv, createHash } from "node:crypto";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const CONFIG = join(ROOT, "Paridade/conta_propria_v1.json");
const CASES = join(ROOT, "Paridade/casos_conta_propria_v1.json");
const config = JSON.parse(readFileSync(CONFIG, "utf8"));

export function formatCode(bytes) {
  let bits = 0, value = 0, out = "";
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += config.alfabeto[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += config.alfabeto[(value << (5 - bits)) & 31];
  return out.match(new RegExp(`.{1,${config.tamanhoGrupo}}`, "g")).join("-");
}

/** Upper case, without hyphens and spaces; null unless it has the exact length and only alphabet letters. */
export function normalize(code) {
  const clean = code.toUpperCase().replace(/[-\s]/g, "");
  const length = Math.ceil((config.bytesCodigo * 8) / 5);
  if (clean.length !== length || [...clean].some((c) => !config.alfabeto.includes(c))) return null;
  return clean;
}

const sha = (text) => createHash("sha256").update(text, "utf8");

export function derive(code) {
  return {
    conta: sha(config.prefixoConta + code).digest("hex").slice(0, 32),
    credencial: sha(config.prefixoCredencial + code).digest("hex"),
    chave: sha(config.prefixoChave + code).digest("hex"),
  };
}

/** nonce (12 bytes) + ciphertext + tag (16 bytes), AES-256-GCM. */
export function encrypt(keyHex, nonceHex, plaintext) {
  const cipher = createCipheriv("aes-256-gcm", Buffer.from(keyHex, "hex"), Buffer.from(nonceHex, "hex"));
  const body = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  return Buffer.concat([Buffer.from(nonceHex, "hex"), body, cipher.getAuthTag()]).toString("hex");
}

function buildCases() {
  const codes = [
    formatCode(Buffer.from("000102030405060708090a0b0c0d0e0f10111213", "hex")),
    formatCode(Buffer.alloc(20, 0xff)),
    formatCode(Buffer.from("9f3c0a77e41d2b58c6a0f19e3d7b55c2e8014a6d", "hex")),
  ];
  const normalization = [
    [codes[2], normalize(codes[2])],
    [codes[2].toLowerCase(), normalize(codes[2])],
    [codes[2].replace(/-/g, " "), normalize(codes[2])],
    [codes[2].slice(0, -1), null],
    [codes[2].replace(/.$/, "1"), null],
    ["", null],
  ];
  const derivations = codes.map((code) => ({ codigo: normalize(code), ...derive(normalize(code)) }));
  const key = derivations[2].chave;
  const vectors = [
    ["caderno curto", "000000000000000000000000", '{"formato":"caderno-biblioteca-maconica","versao":1}'],
    ["acentos e simbolos", "0102030405060708090a0b0c", "Escada de Jacó — ∴ acácia"],
    ["vazio", "ffffffffffffffffffffffff", ""],
  ].map(([nome, nonce, texto]) => ({ nome, chave: key, nonce, texto, cifrado: encrypt(key, nonce, texto) }));
  return {
    schemaVersion: 1,
    descricao: "Casos de referencia da conta propria (Paridade/conta_propria_v1.json), gerados por " +
      "node Tools/conta_propria_referencia.mjs --atualizar. iOS e Android devem reproduzir cada resultado.",
    formatacao: [
      { bytes: "000102030405060708090a0b0c0d0e0f10111213", codigo: codes[0] },
      { bytes: "ffffffffffffffffffffffffffffffffffffffff", codigo: codes[1] },
      { bytes: "9f3c0a77e41d2b58c6a0f19e3d7b55c2e8014a6d", codigo: codes[2] },
    ],
    normalizacao: normalization.map(([entrada, esperado]) => ({ entrada, esperado })),
    derivacao: derivations,
    cifragem: vectors,
  };
}

const expected = JSON.stringify(buildCases(), null, 2) + "\n";
if (process.argv.includes("--atualizar")) {
  writeFileSync(CASES, expected);
  console.log("Casos da conta propria atualizados.");
} else if (!existsSync(CASES) || readFileSync(CASES, "utf8") !== expected) {
  console.error("Casos da conta propria desatualizados em relacao a implementacao de referencia.");
  process.exit(1);
} else {
  console.log("Casos da conta propria: verificados.");
}
