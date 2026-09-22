#!/usr/bin/env python3
"""Segunda etapa de modularizacao, idempotente e sem alterar comportamento."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def split_swift_extension(relative_path: str, parts: list[tuple[str, str]]) -> None:
    source = ROOT / relative_path
    text = source.read_text(encoding="utf-8")
    extension_marker = "extension HomeView {\n"
    if extension_marker not in text or any(marker not in text for _, marker in parts[1:]):
        return

    imports, body = text.split(extension_marker, 1)
    body = body.rstrip()
    if body.endswith("}"):
        body = body[:-1].rstrip()

    positions = [0] + [body.index(marker) for _, marker in parts[1:]] + [len(body)]
    for index, (filename, _) in enumerate(parts):
        chunk = body[positions[index]:positions[index + 1]].strip()
        target = source.with_name(filename)
        target.write_text(f"{imports}{extension_marker}{chunk}\n}}\n", encoding="utf-8")


def split_swift_top_level(relative_path: str, parts: list[tuple[str, str]]) -> None:
    source = ROOT / relative_path
    text = source.read_text(encoding="utf-8")
    if any(marker not in text for _, marker in parts):
        return
    first_position = text.index(parts[0][1])
    imports = text[:first_position]
    positions = [text.index(marker) for _, marker in parts] + [len(text)]
    for index, (filename, _) in enumerate(parts):
        body = text[positions[index]:positions[index + 1]].strip()
        source.with_name(filename).write_text(f"{imports}{body}\n", encoding="utf-8")


def split_kotlin(relative_path: str, parts: list[tuple[str, str]]) -> None:
    source = ROOT / relative_path
    text = source.read_text(encoding="utf-8")
    if any(marker not in text for _, marker in parts):
        return
    first_position = text.index(parts[0][1])
    header = text[:first_position]
    positions = [text.index(marker) for _, marker in parts] + [len(text)]
    for index, (filename, _) in enumerate(parts):
        body = text[positions[index]:positions[index + 1]].strip()
        source.with_name(filename).write_text(f"{header}{body}\n", encoding="utf-8")


def main() -> None:
    split_swift_extension(
        "BibliotecaMaconica_Dev/Views/LibraryScreens.swift",
        [
            ("LibraryScreens.swift", "    @ViewBuilder\n    var leituraDoDiaContainer"),
            ("OfflineCatalogScreens.swift", "    var acervoOfflineView"),
            ("LibraryStudyScreens.swift", "    var indicesBibliotecaView"),
            ("ReadingDetailScreens.swift", "    var detalhe: some View"),
        ],
    )
    split_swift_extension(
        "BibliotecaMaconica_Dev/Views/HomeActions.swift",
        [
            ("HomeActions.swift", "    func importarPDF"),
            ("ReadingNavigationActions.swift", "    func abrirData"),
            ("PreferencesActions.swift", "    func salvarConfiguracaoNotificacao"),
            ("LibrarySearchActions.swift", "    func gerarDossieEstudo"),
            ("LibraryRequestActions.swift", "    func carregarIndicesBiblioteca"),
        ],
    )
    split_swift_extension(
        "BibliotecaMaconica_Dev/Views/HomePresentation.swift",
        [
            ("HomePresentation.swift", "    func avisoGlobal"),
            ("ReadingProgressPresentation.swift", "    var painelProgressoAnual"),
            ("RecentReadingPresentation.swift", "    var leiturasRecentesCard"),
        ],
    )
    split_swift_extension(
        "BibliotecaMaconica_Dev/Views/SettingsScreens.swift",
        [
            ("SettingsScreens.swift", "    var configuracoes"),
            ("AppLifecycleActions.swift", "    func prepararCachesIniciais"),
            ("PremiumContentActions.swift", "    func atualizarConteudoPremiumCache"),
        ],
    )
    split_swift_top_level(
        "BibliotecaMaconica_Dev/Views/ReadingComponents.swift",
        [
            ("ReadingComponents.swift", "struct IAResumoView"),
            ("JustifiedTextComponents.swift", "struct JustifiedTextView"),
            ("ReadingEditorComponents.swift", "struct IndiceRemissivoView"),
        ],
    )

    android = "projetos/BreviarioMaconicoAndroid/app/src/main/java/com/renatocamargo/breviariomaconico/"
    split_kotlin(
        android + "LibraryUi.kt",
        [
            ("LibraryUi.kt", "@Composable\ninternal fun BreviarioScreen"),
            ("LibraryReaderUi.kt", "@Composable\ninternal fun LibraryReaderScreen"),
            ("LibrarySearchUi.kt", "@OptIn(ExperimentalLayoutApi::class)\n@Composable\ninternal fun StructuredSearchScreen"),
            ("LibraryReferenceUi.kt", "@OptIn(ExperimentalLayoutApi::class)\n@Composable\ninternal fun GlobalIndexScreen"),
            ("LibraryAIUi.kt", "@Composable\ninternal fun ReadingAIScreen"),
        ],
    )
    split_kotlin(
        android + "HomeUi.kt",
        [
            ("HomeUi.kt", "@Composable\ninternal fun HomeScreen"),
            ("ReaderUi.kt", "@Composable\ninternal fun ReaderScreen"),
        ],
    )
    split_kotlin(
        android + "StudyUi.kt",
        [
            ("StudyUi.kt", "@Composable\ninternal fun IndexScreen"),
            ("SettingsUi.kt", "@OptIn(ExperimentalLayoutApi::class)\n@Composable\ninternal fun SettingsScreen"),
        ],
    )
    split_kotlin(
        android + "MainActivity.kt",
        [
            ("MainActivity.kt", "class MainActivity"),
            ("AppEntryUi.kt", "@Composable\ninternal fun SplashScreen"),
        ],
    )


if __name__ == "__main__":
    main()
