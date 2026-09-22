#!/usr/bin/env python3
import csv
import hashlib
import json
import os
import re
import subprocess
import unicodedata
from pathlib import Path
from typing import Optional


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ImportacaoLivrosPDF"
OUTPUT = SOURCE / "_catalogo"


STOPWORDS = {
    "a", "as", "o", "os", "de", "da", "do", "das", "dos", "e", "em", "para",
    "por", "com", "sem", "um", "uma", "no", "na", "nos", "nas", "ao", "aos",
    "pdf", "vol", "volume", "v1", "v2", "versao", "versão"
}


ASSUNTOS = {
    "Ritualística": ["ritual", "rito", "reaa", "emulação", "emulacao", "instrução", "instrucao"],
    "Simbologia": ["simbolo", "símbolo", "simbologia", "abóbada", "abobada", "geometria", "número", "numero", "templo"],
    "História": ["historia", "história", "brasil", "portugal", "republica", "abolição", "abolicao", "ditadura", "francesa"],
    "Filosofia": ["filosofia", "sócrates", "socrates", "aristoteles", "aristóteles", "platão", "platao", "ética", "etica"],
    "Esoterismo": ["cabala", "zohar", "hermetismo", "hermética", "hermetica", "magia", "templário", "templario", "templarios"],
    "Religião e Bíblia": ["bíblia", "biblia", "salmo", "jesus", "salomão", "salomao", "judeus", "cristianismo"],
    "Legislação": ["lei", "leis", "regular", "norma", "regulamento", "constituição", "constituicao", "vade mecum"],
    "Dicionário": ["dicionario", "dicionário", "verbete", "termo", "glossario", "glossário"],
}


def normalizar(texto: str) -> str:
    texto = unicodedata.normalize("NFKD", texto)
    texto = "".join(ch for ch in texto if not unicodedata.combining(ch))
    return texto.lower()


def slug(texto: str) -> str:
    base = normalizar(texto)
    base = re.sub(r"[^a-z0-9]+", "_", base).strip("_")
    return base[:80] or "obra_importada"


def hash_arquivo(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for bloco in iter(lambda: f.read(1024 * 1024), b""):
            h.update(bloco)
    return h.hexdigest()


def pdf_paginas(path: Path) -> Optional[int]:
    try:
        resultado = subprocess.run(
            ["pdfinfo", str(path)],
            check=False,
            capture_output=True,
            text=True,
            timeout=20,
        )
    except Exception:
        return None

    for linha in resultado.stdout.splitlines():
        if linha.startswith("Pages:"):
            try:
                return int(linha.split(":", 1)[1].strip())
            except ValueError:
                return None
    return None


def autor_por_nome(nome: str) -> Optional[str]:
    partes = re.split(r"\s+-\s+", nome)
    if len(partes) < 2:
        return None

    candidato = partes[-1].rsplit(".", 1)[0].strip()
    if len(candidato) < 4:
        return None

    if re.search(r"\b(vol|v\d+|vers[aã]o|completo|pdf)\b", normalizar(candidato)):
        return None

    return candidato


def tipo_area(nome: str) -> tuple[str, str]:
    n = normalizar(nome)

    if any(palavra in n for palavra in ["dicionario", "glossario", "verbete"]):
        return "dicionario", "dicionariosMaconicos"

    if any(palavra in n for palavra in ["vade mecum", "lei", "leis", "regular", "norma", "regulamento", "constituicao", "codigo"]):
        return "judiciario", "judiciarioMaconico"

    if any(palavra in n for palavra in ["instrucao", "material didatico", "aula", "apostila"]):
        return "apostila", "bibliotecaMaconica"

    return "livro", "bibliotecaMaconica"


def assuntos_por_nome(nome: str) -> list[str]:
    n = normalizar(nome)
    encontrados = [
        assunto for assunto, palavras in ASSUNTOS.items()
        if any(normalizar(palavra) in n for palavra in palavras)
    ]
    return encontrados or ["Estudo maçônico"]


def titulo_limpo(path: Path) -> str:
    titulo = path.stem.replace("_", " ")
    titulo = re.sub(r"\s+", " ", titulo).strip()
    return titulo


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    pdfs = sorted(p for p in SOURCE.iterdir() if p.is_file() and p.suffix.lower() == ".pdf")

    registros = []
    hashes = {}
    for index, path in enumerate(pdfs, 1):
        titulo = titulo_limpo(path)
        digest = hash_arquivo(path)
        hashes.setdefault(digest, []).append(path.name)
        assuntos = assuntos_por_nome(path.name)
        tipo, area = tipo_area(path.name)
        paginas = pdf_paginas(path)
        registros.append({
            "id": f"obra_{slug(titulo)}",
            "arquivo": path.name,
            "titulo": titulo,
            "autorProvavel": autor_por_nome(path.name),
            "area": area,
            "tipo": tipo,
            "assuntos": assuntos,
            "paginas": paginas,
            "tamanhoMB": round(path.stat().st_size / (1024 * 1024), 2),
            "sha256": digest,
            "ordem": index,
            "statusImportacao": "pronto_para_pdf",
        })

    duplicados = [
        {"sha256": digest, "arquivos": nomes}
        for digest, nomes in hashes.items()
        if len(nomes) > 1
    ]

    resumo = {
        "totalPDFs": len(pdfs),
        "totalDuplicadosPorConteudo": sum(len(d["arquivos"]) - 1 for d in duplicados),
        "gruposDuplicados": len(duplicados),
        "tamanhoTotalMB": round(sum(p.stat().st_size for p in pdfs) / (1024 * 1024), 2),
        "observacoes": [
            "Catalogo preliminar gerado por nome de arquivo e metadados tecnicos.",
            "Duplicados por SHA-256 devem ser revisados antes da importacao final.",
            "Importacao em massa deve ser sequencial para evitar travamentos.",
            "Texto sem OCR nao sera ocultado: a pagina original permanece preservada.",
        ],
    }

    with (OUTPUT / "catalogo_obras.json").open("w", encoding="utf-8") as f:
        json.dump(registros, f, ensure_ascii=False, indent=2)

    with (OUTPUT / "duplicados_por_conteudo.json").open("w", encoding="utf-8") as f:
        json.dump(duplicados, f, ensure_ascii=False, indent=2)

    with (OUTPUT / "resumo_importacao.json").open("w", encoding="utf-8") as f:
        json.dump(resumo, f, ensure_ascii=False, indent=2)

    with (OUTPUT / "catalogo_obras.csv").open("w", encoding="utf-8", newline="") as f:
        campos = ["ordem", "arquivo", "titulo", "autorProvavel", "area", "tipo", "assuntos", "paginas", "tamanhoMB", "sha256", "statusImportacao"]
        writer = csv.DictWriter(f, fieldnames=campos)
        writer.writeheader()
        for registro in registros:
            linha = dict(registro)
            linha["assuntos"] = "; ".join(registro["assuntos"])
            writer.writerow({campo: linha.get(campo) for campo in campos})

    print(json.dumps(resumo, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
