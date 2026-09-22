#!/usr/bin/env python3
"""Separa serviços iOS extensos em extensões coesas, preservando a lógica."""

from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def split_type(
    relative_path: str,
    type_declaration: str,
    parts: list[tuple[str, str]],
    trailing_marker: str | None = None,
) -> None:
    source = ROOT / relative_path
    text = source.read_text(encoding="utf-8")

    declaration_position = text.index(type_declaration)
    imports = text[:declaration_position]
    body_start = text.index("{", declaration_position) + 1
    if trailing_marker and trailing_marker in text:
        class_end = text.index(trailing_marker)
        trailing = text[class_end:]
        body_end = text.rfind("}", body_start, class_end) + 1
    else:
        trailing = ""
        body_end = text.rfind("}") + 1

    body = text[body_start:body_end - 1]
    body = re.sub(r"\bprivate\(set\)\s+", "", body)
    body = re.sub(r"\bprivate\s+", "", body)
    if any(marker not in body for _, marker in parts[1:]):
        return
    positions = [0] + [body.index(marker) for _, marker in parts[1:]] + [len(body)]
    type_name_match = re.search(r"(?:class|enum|struct)\s+([A-Za-z_][A-Za-z0-9_]*)", type_declaration)
    if type_name_match is None:
        raise ValueError(f"Declaração de tipo inválida: {type_declaration}")
    type_name = type_name_match.group(1)

    for index, (filename, _) in enumerate(parts):
        chunk = body[positions[index]:positions[index + 1]].strip()
        if index == 0:
            content = f"{imports}{type_declaration} {{\n{chunk}\n}}\n"
        else:
            content = f"{imports}extension {type_name} {{\n{chunk}\n}}\n"
        if index == len(parts) - 1 and trailing:
            content += trailing.lstrip("\n")
        source.with_name(filename).write_text(content, encoding="utf-8")


def main() -> None:
    split_type(
        "BibliotecaMaconica_Dev/PDF/PDFService.swift",
        "class PDFService",
        [
            ("PDFService.swift", "\n\n    enum PDFError"),
            ("PDFLayoutRenderer.swift", "    static func desenharCapa("),
            ("PDFTextRenderer.swift", "    static func desenharTextoPaginado("),
        ],
    )
    split_type(
        "BibliotecaMaconica_Dev/Services/BreviarioImportService.swift",
        "enum BreviarioImportService",
        [
            ("BreviarioImportService.swift", "\n\n    static let cabecalho"),
            ("BreviarioIndexImportService.swift", "    static func criarEntradasIndice("),
            ("BreviarioOCRTextNormalizer.swift", "    static func corrigirSubstituicoesOCR("),
            ("BreviarioTitleIndexBuilder.swift", "    static func tituloGenerico("),
        ],
        trailing_marker="\nprivate extension String",
    )
    split_type(
        "BibliotecaMaconica_Dev/Services/BreviarioStore.swift",
        "final class BreviarioStore: ObservableObject",
        [
            ("BreviarioStore.swift", "\n\n    @Published"),
            ("BreviarioStoreSearch.swift", "    func buscarBiblioteca("),
            ("BreviarioStorePersistence.swift", "    func restaurarDadosEmbutidos()"),
            ("BreviarioStoreCatalog.swift", "    func atualizarCatalogo()"),
        ],
        trailing_marker="\nprivate extension String",
    )

    # `nilSeVazio` é compartilhado entre importação e catálogo. Após a
    # separação, deve existir uma única vez com acesso interno ao módulo.
    title_index = ROOT / "BibliotecaMaconica_Dev/Services/BreviarioTitleIndexBuilder.swift"
    title_index.write_text(
        title_index.read_text(encoding="utf-8").replace(
            "private extension String", "extension String"
        ),
        encoding="utf-8",
    )
    store_catalog = ROOT / "BibliotecaMaconica_Dev/Services/BreviarioStoreCatalog.swift"
    store_catalog.write_text(
        re.sub(
            r"\nprivate extension String \{.*?\n\}\s*$",
            "\n",
            store_catalog.read_text(encoding="utf-8"),
            flags=re.DOTALL,
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
