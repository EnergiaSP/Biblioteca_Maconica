#!/usr/bin/env python3
import csv
import json
import os
import select
import signal
import shutil
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INPUT_DIR = ROOT / "ImportacaoLivrosPDF"
OUTPUT_DIR = ROOT / "ImportacaoLivrosPDF_OCR"
REPORT_DIR = OUTPUT_DIR / "_relatorios"
STAGING_DIR = OUTPUT_DIR / "_processando"
CONVERTER = ROOT / "Tools" / "converter_pdfs_para_ocr.swift"
CONVERTER_BINARY = Path(os.environ.get("OCR_CONVERTER_BINARY", ROOT / "DerivedData" / "ocr-converter"))
TIMEOUT_SECONDS = int(os.environ.get("OCR_TIMEOUT_SECONDS", "360"))
ONLY_FAILURES = os.environ.get("OCR_ONLY_FAILURES", "0") == "1"
ONLY_PARTIALS = os.environ.get("OCR_ONLY_PARTIALS", "0") == "1"
RETRY_FAILURES = os.environ.get("OCR_RETRY_FAILURES", "0") == "1"
FORCE_FULL_OCR = os.environ.get("OCR_FORCE_FULL", "0") == "1"
TARGETS_FILE = os.environ.get("OCR_TARGETS_FILE")
SUMMARY_ONLY = os.environ.get("OCR_SUMMARY_ONLY", "0") == "1"
SUCCESS_STATUSES = {
    "ja_existia",
    "ja_possui_ocr_preservado",
    "ocr_concluido",
    "ocr_parcial",
}


def file_size_mb(path: Path) -> float:
    if not path.exists():
        return 0.0
    return round(path.stat().st_size / 1024 / 1024, 2)


def load_single_report(report_dir: Path) -> list[dict]:
    report_path = report_dir / "relatorio_ocr_conversao.json"
    if not report_path.exists():
        return []
    try:
        return json.loads(report_path.read_text(encoding="utf-8"))
    except Exception:
        return []


def load_safe_report() -> list[dict]:
    report_path = REPORT_DIR / "relatorio_ocr_seguro.json"
    if not report_path.exists():
        return []
    try:
        rows = json.loads(report_path.read_text(encoding="utf-8"))
        return rows if isinstance(rows, list) else []
    except Exception:
        return []


def write_reports(rows: list[dict]) -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    (REPORT_DIR / "relatorio_ocr_seguro.json").write_text(
        json.dumps(rows, ensure_ascii=False, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    fields = [
        "arquivo",
        "status",
        "paginas",
        "paginasOCR",
        "paginasSemTextoVisual",
        "paginasSomenteImagem",
        "palavrasReconhecidas",
        "tamanhoOrigemMB",
        "tamanhoOCRMB",
        "tempoSegundos",
        "observacao",
    ]
    with (REPORT_DIR / "relatorio_ocr_seguro.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fields})

    summary: dict[str, int] = {}
    for row in rows:
        summary[row["status"]] = summary.get(row["status"], 0) + 1
    summary["total_processado"] = len(rows)
    (REPORT_DIR / "resumo_ocr_seguro.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True),
        encoding="utf-8",
    )


def convert_one(pdf: Path) -> dict:
    started = time.time()
    staging_output_dir = STAGING_DIR / pdf.stem
    staging_report_dir = staging_output_dir / "_relatorios"
    staging_pdf = staging_output_dir / pdf.name
    final_pdf = OUTPUT_DIR / pdf.name

    if staging_output_dir.exists():
        shutil.rmtree(staging_output_dir)
    staging_output_dir.mkdir(parents=True, exist_ok=True)

    if CONVERTER_BINARY.exists():
        command = [
            str(CONVERTER_BINARY),
            "--file",
            str(pdf),
            "--output",
            str(staging_output_dir),
            "--force",
        ]
    else:
        command = [
            "/usr/bin/env",
            "CLANG_MODULE_CACHE_PATH=/private/tmp/clang-module-cache",
            "swift",
            str(CONVERTER),
            "--file",
            str(pdf),
            "--output",
            str(staging_output_dir),
            "--force",
        ]
    if FORCE_FULL_OCR:
        command.append("--ocr-all")

    process = subprocess.Popen(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )

    stdout_chunks: list[str] = []
    stderr_chunks: list[str] = []
    deadline = time.monotonic() + TIMEOUT_SECONDS

    streams = [stream for stream in [process.stdout, process.stderr] if stream]
    while True:
        readable, _, _ = select.select(streams, [], [], 0.5)
        for stream in readable:
            line = stream.readline()
            if not line:
                continue
            if stream is process.stdout:
                stdout_chunks.append(line)
                stripped = line.rstrip()
                if not SUMMARY_ONLY or stripped.startswith("[") or stripped.startswith("->") or stripped.startswith("{") or stripped.startswith("}"):
                    print("    " + stripped, flush=True)
            else:
                stderr_chunks.append(line)
                if not SUMMARY_ONLY:
                    print("    aviso: " + line.rstrip(), flush=True)

        if process.poll() is not None:
            if process.stdout:
                remainder = process.stdout.read()
                if remainder:
                    stdout_chunks.append(remainder)
                    for line in remainder.splitlines():
                        if not SUMMARY_ONLY or line.startswith("[") or line.startswith("->") or line.startswith("{") or line.startswith("}"):
                            print("    " + line, flush=True)
            if process.stderr:
                remainder = process.stderr.read()
                if remainder:
                    stderr_chunks.append(remainder)
                    for line in remainder.splitlines():
                        if not SUMMARY_ONLY:
                            print("    aviso: " + line, flush=True)
            break

        if time.monotonic() > deadline:
            try:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
            except Exception:
                pass
            if staging_pdf.exists():
                try:
                    staging_pdf.unlink()
                except Exception:
                    pass
            return {
                "arquivo": pdf.name,
                "status": "falha_tempo_limite",
                "paginas": 0,
                "paginasOCR": 0,
                "paginasSemTextoVisual": 0,
                "paginasSomenteImagem": 0,
                "palavrasReconhecidas": 0,
                "tamanhoOrigemMB": file_size_mb(pdf),
                "tamanhoOCRMB": file_size_mb(final_pdf),
                "tempoSegundos": round(time.time() - started, 1),
                "observacao": f"Tempo limite de {TIMEOUT_SECONDS}s atingido. Arquivo pulado para nao travar o lote.",
            }

        time.sleep(0.1)

    stderr = "".join(stderr_chunks)

    rows = load_single_report(staging_report_dir)
    if rows:
        row = rows[-1]
        row["tempoSegundos"] = round(time.time() - started, 1)
        row["tamanhoOCRMB"] = file_size_mb(staging_pdf) or file_size_mb(final_pdf)
        if process.returncode != 0:
            row["status"] = "falha"
            row["observacao"] = (row.get("observacao") or "") + " Conversor retornou erro."
        elif row.get("status") in SUCCESS_STATUSES and staging_pdf.exists():
            if final_pdf.exists():
                final_pdf.unlink()
            shutil.move(str(staging_pdf), str(final_pdf))
            row["tamanhoOCRMB"] = file_size_mb(final_pdf)
        return row

    return {
        "arquivo": pdf.name,
        "status": "falha",
        "paginas": 0,
        "paginasOCR": 0,
        "paginasSemTextoVisual": 0,
        "paginasSomenteImagem": 0,
        "palavrasReconhecidas": 0,
        "tamanhoOrigemMB": file_size_mb(pdf),
        "tamanhoOCRMB": file_size_mb(final_pdf),
        "tempoSegundos": round(time.time() - started, 1),
        "observacao": stderr.strip()[-500:] or "Conversao nao gerou relatorio individual.",
    }


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    pdfs = sorted(INPUT_DIR.glob("*.pdf"), key=lambda item: item.name.casefold())
    if TARGETS_FILE:
        target_path = Path(TARGETS_FILE)
        target_names = {
            line.strip()
            for line in target_path.read_text(encoding="utf-8").splitlines()
            if line.strip()
        }
        pdfs = [pdf for pdf in pdfs if pdf.name in target_names]
    force_target_list = bool(TARGETS_FILE and FORCE_FULL_OCR)

    rows: list[dict] = load_safe_report()
    processed = {row.get("arquivo"): row for row in rows if row.get("arquivo")}
    failed_names = {
        row.get("arquivo")
        for row in rows
        if row.get("status") not in SUCCESS_STATUSES and row.get("arquivo")
    }
    partial_names = {
        row.get("arquivo")
        for row in rows
        if row.get("status") == "ocr_parcial" and row.get("arquivo")
    }

    if ONLY_FAILURES:
        pdfs = [pdf for pdf in pdfs if pdf.name in failed_names]
    if ONLY_PARTIALS:
        pdfs = [pdf for pdf in pdfs if pdf.name in partial_names]

    total = len(pdfs)

    print(f"Iniciando OCR seguro: {total} arquivo(s).", flush=True)
    print(f"Tempo limite por arquivo: {TIMEOUT_SECONDS}s.", flush=True)
    if TARGETS_FILE:
        print("Modo: reprocessar lista especifica de arquivos.", flush=True)
    if ONLY_FAILURES:
        print("Modo: reprocessar somente arquivos que falharam.", flush=True)
    if ONLY_PARTIALS:
        print("Modo: reprocessar somente arquivos com OCR parcial.", flush=True)
    if rows:
        convertidos = sum(1 for item in rows if item["status"] in SUCCESS_STATUSES)
        falhas = len(rows) - convertidos
        faltam = total if (ONLY_FAILURES or force_target_list) else max(0, total - len(processed))
        print(
            f"Retomando lote: {len(rows)} ja registrados | convertidos {convertidos} | falhas {falhas} | faltam {faltam}",
            flush=True,
        )

    for index, pdf in enumerate(pdfs, start=1):
        existing = processed.get(pdf.name)
        pode_refazer_parcial = FORCE_FULL_OCR and existing and existing.get("status") == "ocr_parcial"
        if existing and existing.get("status") in SUCCESS_STATUSES and (OUTPUT_DIR / pdf.name).exists() and ONLY_PARTIALS == False and pode_refazer_parcial == False and force_target_list == False:
            convertidos = sum(1 for item in rows if item["status"] in SUCCESS_STATUSES)
            falhas = len(rows) - convertidos
            faltam = total - index
            print(
                f"[{index}/{total}] ja processado: {pdf.name} | convertidos {convertidos} | falhas {falhas} | faltam {faltam}",
                flush=True,
            )
            continue

        if existing and existing.get("status") == "falha_tempo_limite" and RETRY_FAILURES == False:
            convertidos = sum(1 for item in rows if item["status"] in SUCCESS_STATUSES)
            falhas = len(rows) - convertidos
            faltam = total - index
            print(
                f"[{index}/{total}] pulado por falha anterior: {pdf.name} | convertidos {convertidos} | falhas {falhas} | faltam {faltam}",
                flush=True,
            )
            continue

        faltam_antes = total - index + 1
        print(f"[{index}/{total}] Iniciando: {pdf.name} | faltam incluindo este: {faltam_antes}", flush=True)
        row = convert_one(pdf)
        processed[row["arquivo"]] = row
        rows = [item for item in rows if item.get("arquivo") != row["arquivo"]]
        rows.append(row)
        write_reports(rows)

        convertidos = sum(1 for item in rows if item["status"] in SUCCESS_STATUSES)
        falhas = len(rows) - convertidos
        faltam = total - index
        print(
            f"[{index}/{total}] {row['status']}: {pdf.name} | convertidos {convertidos} | falhas {falhas} | faltam {faltam}",
            flush=True,
        )

    print("OCR seguro concluido.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
