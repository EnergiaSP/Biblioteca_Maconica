#!/usr/bin/env python3
"""Divide interfaces monolíticas em arquivos de domínio sem alterar sua lógica."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def modularizar_ios() -> None:
    source = ROOT / "BibliotecaMaconica_Dev/Views/HomeView.swift"
    components = ROOT / "BibliotecaMaconica_Dev/Views/HomeViewComponents.swift"
    text = source.read_text(encoding="utf-8")
    marker = "private struct Compartilhamento: Identifiable {"
    if marker not in text:
        return
    head, tail = text.split(marker, 1)
    tail = marker + tail
    tail = re.sub(r"(?m)^private (struct|enum|extension) ", r"\1 ", tail)
    components.write_text(
        "import SwiftUI\nimport UIKit\n\n" + tail,
        encoding="utf-8",
    )
    source.write_text(head.rstrip() + "\n", encoding="utf-8")


def dividir_componentes_ios() -> None:
    source = ROOT / "BibliotecaMaconica_Dev/Views/HomeViewComponents.swift"
    if not source.exists():
        return
    text = source.read_text(encoding="utf-8")
    markers = [
        ("LibraryComponents.swift", "struct LeituraListaRow: View {"),
        ("ReadingComponents.swift", "struct IAResumoView: View {"),
        ("ExportComponents.swift", "struct ExportacaoMultiplaView: View {"),
    ]
    if any(marker not in text for _, marker in markers):
        return
    header = "import SwiftUI\nimport UIKit\n\n"
    positions = [(name, text.index(marker)) for name, marker in markers]
    first = positions[0][1]
    source.write_text(text[:first].rstrip() + "\n", encoding="utf-8")
    boundaries = [position for _, position in positions] + [len(text)]
    for index, (name, _) in enumerate(positions):
        body = text[boundaries[index]:boundaries[index + 1]]
        source.with_name(name).write_text(header + body.lstrip(), encoding="utf-8")


def dividir_nucleo_ios() -> None:
    source = ROOT / "BibliotecaMaconica_Dev/Views/HomeView.swift"
    text = source.read_text(encoding="utf-8")
    first_marker = "    private func avisoGlobal(_ mensagem: String) -> some View {"
    if first_marker not in text:
        return
    markers = [
        ("HomePresentation.swift", first_marker),
        ("LibraryScreens.swift", "    private var leituraDoDiaContainer: some View {"),
        ("SettingsScreens.swift", "    private var configuracoes: some View {"),
        ("HomeActions.swift", "    private func importarPDF(resultado: Result<[URL], Error>) {"),
    ]
    positions = [(name, text.index(marker)) for name, marker in markers]
    head = text[:positions[0][1]]
    head = head.replace("private ", "")
    source.write_text(head.rstrip() + "\n}\n", encoding="utf-8")

    final_body = text[positions[-1][1]:].rstrip()
    if final_body.endswith("}"):
        final_body = final_body[:-1].rstrip()
    bodies = []
    for index, (name, position) in enumerate(positions):
        if index == len(positions) - 1:
            body = final_body
        else:
            body = text[position:positions[index + 1][1]].rstrip()
        bodies.append((name, body.replace("private ", "")))

    header = "import SwiftUI\nimport UniformTypeIdentifiers\nimport UIKit\n\nextension HomeView {\n"
    for name, body in bodies:
        source.with_name(name).write_text(header + body + "\n}\n", encoding="utf-8")


def modularizar_android() -> None:
    source = ROOT / "projetos/BreviarioMaconicoAndroid/app/src/main/java/com/renatocamargo/breviariomaconico/MainActivity.kt"
    text = source.read_text(encoding="utf-8")
    if "private fun HomeScreen(" not in text:
        return

    package_end = text.index("\n", text.index("package ")) + 1
    first_decl = text.index("class MainActivity")
    imports = text[package_end:first_decl]
    package = text[:package_end]

    markers = [
        ("LibraryUi.kt", "@Composable\nprivate fun BreviarioScreen("),
        ("StudyUi.kt", "@Composable\nprivate fun IndexScreen("),
        ("ExportSupport.kt", "private fun copyText("),
    ]
    positions = [(name, text.index(marker)) for name, marker in markers]
    home_start = text.index("@Composable\nprivate fun HomeScreen(")
    boundaries = [home_start] + [position for _, position in positions] + [len(text)]
    names = ["HomeUi.kt"] + [name for name, _ in positions]

    main = text[:home_start]
    main = re.sub(r"(?m)^private (enum class|data class|fun) ", r"internal \1 ", main)
    source.write_text(main.rstrip() + "\n", encoding="utf-8")

    for index, name in enumerate(names):
        body = text[boundaries[index]:boundaries[index + 1]]
        body = re.sub(
            r"(?m)^private (enum class|data class|object|fun) ",
            r"internal \1 ",
            body,
        )
        target = source.with_name(name)
        target.write_text(package + imports + body.lstrip(), encoding="utf-8")


if __name__ == "__main__":
    modularizar_ios()
    dividir_componentes_ios()
    dividir_nucleo_ios()
    modularizar_android()
