#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path.cwd()
REPORTS = ROOT / "ImportacaoLivrosPDF_OCR" / "_relatorios"
PACKAGES = REPORTS / "RAGPackages"
CATALOG = ROOT / "Resources" / "rag_catalogo.json"
REPORT_JSON = REPORTS / "rag_pacotes_relatorio.json"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepara o catalogo RAG para Cloudflare R2.")
    parser.add_argument(
        "--base-url",
        required=True,
        help="URL publica base dos pacotes no R2. Ex.: https://acervo.exemplo.com/rag/v1",
    )
    args = parser.parse_args()
    base_url = args.base_url.rstrip("/")

    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    data["baseURL"] = base_url
    data.pop("origem", None)

    total = len(data["pacotes"])
    for index, pacote in enumerate(data["pacotes"], start=1):
        arquivo = pacote["arquivo"]
        path = PACKAGES / arquivo
        if not path.exists():
            raise SystemExit(f"Pacote nao encontrado: {path}")

        pacote["url"] = f"{base_url}/{arquivo}"
        pacote["sha256"] = sha256_file(path)
        pacote["tamanhoBytes"] = path.stat().st_size
        print(f"{index}/{total} {arquivo}")

    encoded = json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True)
    CATALOG.write_text(encoded + "\n", encoding="utf-8")
    REPORT_JSON.write_text(encoded + "\n", encoding="utf-8")
    print(f"Catalogo atualizado: {CATALOG}")


if __name__ == "__main__":
    main()
