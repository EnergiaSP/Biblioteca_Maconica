#!/usr/bin/env python3
"""Auditoria determinística de conteúdo e capacidades comuns iOS/Android."""

from __future__ import annotations

import hashlib
import json
import plistlib
import re
import sys
from collections import Counter
from pathlib import Path

from validar_icloud import document_entitlement_errors


ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "BibliotecaMaconica_Dev"
ANDROID = ROOT / "projetos/BreviarioMaconicoAndroid"

failures: list[str] = []
warnings: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def require_file(path: Path) -> str:
    if not path.is_file():
        fail(f"Arquivo ausente: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8")


def require_markers(path: Path, markers: list[str], capability: str) -> None:
    text = require_file(path)
    missing = [marker for marker in markers if marker not in text]
    if missing:
        fail(f"{capability}: marcadores ausentes em {path.relative_to(ROOT)}: {', '.join(missing)}")


def reject_markers(path: Path, markers: list[str], capability: str) -> None:
    text = require_file(path)
    found = [marker for marker in markers if marker in text]
    if found:
        fail(f"{capability}: padrões proibidos em {path.relative_to(ROOT)}: {', '.join(found)}")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def duplicate_values(values: list[str]) -> list[str]:
    return sorted(value for value, count in Counter(values).items() if count > 1)


ios_daily = IOS / "Resources/breviario.json"
android_daily = ANDROID / "app/src/main/assets/breviario.json"
ios_catalog = IOS / "Resources/rag_catalogo.json"
android_catalog = ANDROID / "app/src/main/assets/rag_catalogo.json"

contract = json.loads(require_file(ROOT / "Paridade/contrato-paridade.json"))
for name, source in contract.get("sharedSources", {}).items():
    if not source.get("mustBeIdentical"):
        continue
    paths = [ROOT / source[platform] for platform in ("ios", "android")]
    if source.get("canonical"):
        paths.append(ROOT / source["canonical"])
    if not all(path.is_file() for path in paths):
        fail(f"Fonte do contrato ausente: {name}")
    elif len({sha256(path) for path in paths}) != 1:
        fail(f"Fonte do contrato divergente: {name}")

for left, right, label in [
    (ios_daily, android_daily, "breviario.json"),
    (ios_catalog, android_catalog, "rag_catalogo.json"),
]:
    if not left.is_file() or not right.is_file():
        fail(f"Fonte compartilhada ausente: {label}")
    elif sha256(left) != sha256(right):
        fail(f"Fonte compartilhada divergente: {label}")

if ios_daily.is_file():
    daily = json.loads(ios_daily.read_text(encoding="utf-8"))
    items = daily.get("itens", [])
    dates = [str(item.get("data", "")) for item in items]
    ids = [str(item.get("id", "")) for item in items]
    if len(items) != 365:
        fail(f"Breviário deve conter 365 leituras; contém {len(items)}")
    if duplicate_values(dates):
        fail(f"Datas duplicadas no breviário: {duplicate_values(dates)[:8]}")
    if duplicate_values(ids):
        fail(f"IDs duplicados no breviário: {duplicate_values(ids)[:8]}")
    malformed = [date for date in dates if not re.fullmatch(r"(0[1-9]|[12][0-9]|3[01])/(0[1-9]|1[0-2])", date)]
    if malformed:
        fail(f"Datas inválidas: {malformed[:8]}")
    for index, item in enumerate(items):
        for field in ("id", "data", "titulo", "texto"):
            if not str(item.get(field, "")).strip():
                fail(f"Leitura {index + 1} sem campo obrigatório: {field}")
    known_dates = set(dates)
    for entry in daily.get("indiceRemissivo", []):
        if not str(entry.get("termo", "")).strip():
            fail("Índice remissivo contém termo vazio")
        missing_dates = sorted(set(entry.get("datas", [])) - known_dates)
        if missing_dates:
            fail(f"Índice '{entry.get('termo')}' aponta para datas inexistentes: {missing_dates}")

if ios_catalog.is_file():
    catalog = json.loads(ios_catalog.read_text(encoding="utf-8"))
    packages = catalog.get("pacotes", [])
    package_files = [str(package.get("arquivo", "")) for package in packages]
    package_urls = [str(package.get("url", "")) for package in packages]
    work_ids: list[str] = []
    for package in packages:
        if not re.fullmatch(r"[0-9a-f]{64}", str(package.get("sha256", ""))):
            fail(f"Pacote sem SHA-256 válido: {package.get('titulo')}")
        if not str(package.get("url", "")).startswith("https://"):
            fail(f"Pacote sem URL HTTPS: {package.get('titulo')}")
        works = package.get("obras", [])
        if not works:
            fail(f"Pacote sem obra: {package.get('titulo')}")
        work_ids.extend(str(work.get("id", "")) for work in works)
    if duplicate_values(package_files):
        fail(f"Arquivos de pacote duplicados: {duplicate_values(package_files)[:8]}")
    if duplicate_values(package_urls):
        fail(f"URLs de pacote duplicadas: {duplicate_values(package_urls)[:8]}")
    if duplicate_values(work_ids):
        fail(f"IDs de obra duplicados: {duplicate_values(work_ids)[:8]}")
    declared = catalog.get("totais", {}).get("pacotes")
    if declared is not None and declared != len(packages):
        fail(f"Total declarado de pacotes ({declared}) diverge do catálogo ({len(packages)})")

pbx = require_file(IOS / "BreviarioMaconicoXXI.xcodeproj/project.pbxproj")
gradle = require_file(ANDROID / "app/build.gradle.kts")
wear_gradle = require_file(ANDROID / "wear/build.gradle.kts")
ios_versions = re.findall(r"MARKETING_VERSION = ([^;]+);", pbx)
ios_builds = re.findall(r"CURRENT_PROJECT_VERSION = ([^;]+);", pbx)
android_match = re.search(r'versionName\s*=\s*"([^"]+)"', gradle)
android_code = re.search(r"versionCode\s*=\s*(\d+)", gradle)
wear_match = re.search(r'versionName\s*=\s*"([^"]+)"', wear_gradle)
wear_code = re.search(r"versionCode\s*=\s*(\d+)", wear_gradle)
if not ios_versions or not android_match:
    fail("Não foi possível identificar as versões das duas plataformas")
elif ios_versions[0].strip() != android_match.group(1):
    fail(f"Versões divergentes: iOS {ios_versions[0].strip()} e Android {android_match.group(1)}")
if len(set(version.strip() for version in ios_versions)) != 1:
    fail(f"Targets iOS possuem versões divergentes: {sorted(set(ios_versions))}")
if len(set(build.strip() for build in ios_builds)) != 1:
    fail(f"Targets iOS possuem builds divergentes: {sorted(set(ios_builds))}")
if not wear_match or wear_match.group(1) != android_match.group(1):
    fail("Wear OS e aplicativo Android possuem versões divergentes")
if not android_code or not wear_code or android_code.group(1) != wear_code.group(1):
    fail("Wear OS e aplicativo Android possuem códigos de build divergentes")

require_markers(
    IOS / "Services/UserDataPersistenceService.swift",
    ["comentario_", "reflexao_", "leituras_concluidas", "destaques_", "edicoes_textos_diarios", "backup_solicitacoes_obras", "backup_fontes_oficiais"],
    "Backup iOS",
)
require_markers(
    IOS / "Services/BibliotecaRAGCatalogService.swift",
    ['"breviario_maconico_rizzardo_da_camino"', "pacotesPermitidos"],
    "Exclusão do breviário não autorizado no iOS",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/data/BibliotecaCatalog.kt",
    ['it.id == "breviario_maconico_rizzardo_da_camino"'],
    "Exclusão do breviário não autorizado no Android",
)
reject_markers(
    IOS / "Models/BibliotecaObra.swift",
    ["static let breviarioRizzardo", 'id: "breviario_rizzardo"'],
    "Resíduo do breviário excluído no iOS",
)
require_markers(
    ANDROID / "app/src/main/res/xml/data_extraction_rules.xml",
    ['domain="sharedpref"', 'path="secure_secrets.xml"'],
    "Backup Android",
)
require_markers(
    ANDROID / "app/src/main/AndroidManifest.xml",
    ["RECEIVE_BOOT_COMPLETED", "singleTop", "NotificationBootReceiver"],
    "Notificação e deep link Android",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/data/LocalPdfOcrImporter.kt",
    ["detectFootnoteDivider", "rag_fts", "Dispatchers.Main.immediate", "insertFootnotes", "insertImage"],
    "OCR Android",
)
require_markers(
    IOS / "OCR/PDFOCRService.swift",
    ["detectarLinhaRodape", "linhaRodape"],
    "OCR iOS",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/widget/BreviarioWidgetProvider.kt",
    ["OPTION_APPWIDGET_MIN_WIDTH", 'putExtra("obraId"', 'putExtra("data"'],
    "Widget Android",
)
require_markers(
    IOS / "Widgets/BreviarioWidget.swift",
    ["systemSmall", "systemMedium", "systemLarge", "widgetURL"],
    "Widget iOS",
)
require_markers(
    ANDROID / "wear/src/main/java/com/renatocamargo/breviariomaconico/wear/WearNotificationService.kt",
    ["scheduleDaily", "scheduleTest", "WearBootReceiver"],
    "Wear OS",
)
require_markers(
    IOS / "Watch/WatchNotificationService.swift",
    ["agendarNotificacaoDiaria", "agendarTeste"],
    "watchOS",
)
require_markers(
    IOS / "App/BreviarioMaconicoXXIApp.swift",
    ["PhoneWatchProgressSync", "ReadingProgressSyncTransport", "transport.start", "transport.enviar"],
    "Sincronização iPhone-watchOS",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/WearProgressListenerService.kt",
    ["PhoneWearProgressSync", "WearableListenerService", "ProgressTransport.send", "ProgressTransport.receive", "onDataChanged", "ACTION_PROGRESS_CHANGED"],
    "Sincronização Android-Wear OS",
)
require_markers(
    ANDROID / "wear/src/main/java/com/renatocamargo/breviariomaconico/wear/WearPhoneProgressListenerService.kt",
    ["WearableListenerService", "onMessageReceived", "onDataChanged", "ProgressTransport.DATA_PATH", "ProgressTransport.receive"],
    "Sincronização Wear OS-Android",
)
require_markers(
    IOS / "Shared/ReadingProgressSync.swift",
    ["WCSessionDelegate", "didReceiveMessage", "didReceiveUserInfo", "transferUserInfo", "ReadingProgressLedger", "persistLocked", "ledger.receive"],
    "Transporte duravel compartilhado iOS-watchOS",
)
require_markers(
    ANDROID / "progress-shared/ProgressTransport.kt",
    ["/reading-progress-state", "PutDataMapRequest", "ledger.receive", "ledger.delivered", "save(app, ledger)"],
    "Transporte duravel compartilhado Android-Wear OS",
)
for module in ["app", "wear"]:
    require_markers(ANDROID / f"{module}/build.gradle.kts", ['java.srcDir("../progress-shared")'], "Inclusao do transporte compartilhado " + module)
require_markers(
    IOS / "Views/HomeView.swift",
    ["publisher(for: .progressoLeituraSincronizado)", "atualizarProgressoLeitura()"],
    "Atualização imediata iPhone-watchOS",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/MainActivity.kt",
    ["ACTION_PROGRESS_CHANGED", "ContextCompat.RECEIVER_NOT_EXPORTED"],
    "Atualização imediata Android-Wear OS",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/LibraryReaderUi.kt",
    ["withContext(Dispatchers.IO)", "AsyncPageImage", "decodePageImage"],
    "Operações assíncronas Android",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/LibrarySearchUi.kt",
    ["var buscando", "var montando", "libraryQuery", "consultaJob?.cancel()"],
    "Busca assíncrona Android",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/MainActivity.kt",
    ["appScope.launch", "paginasDaObra(obraId)", "libraryQuery"],
    "Abertura assíncrona de obras Android",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/LibraryQueryRunner.kt",
    ["withContext(Dispatchers.IO)", "throw cancelled", "Result.failure(error)"],
    "Tratamento de falhas e cancelamento de consultas Android",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/data/RagSQLite.kt",
    ["BundledSQLiteDriver", "SQLITE_OPEN_READONLY", "SQLITE_OPEN_FULLMUTEX"],
    "Motor SQLite Android independente do sistema",
)
require_markers(ANDROID / "app/build.gradle.kts", ["androidx.sqlite:sqlite-bundled:"], "Dependencia FTS5 Android")
require_markers(
    IOS / "UITests/BibliotecaMaconicaUITests.swift",
    [
        "testRapidTabSwitchingRemainsStable",
        "testStructuredSearchOpensFromHome",
        "testBackgroundAndForegroundKeepsNavigationAvailable",
        "testRepeatedSettingsRoundTripsRemainStable",
    ],
    "Teste de estabilidade de navegação iOS",
)
require_markers(
    ANDROID / "app/src/androidTest/java/com/renatocamargo/breviariomaconico/NavigationFlowTest.kt",
    [
        "rapidTabSwitchingRemainsStable",
        "structuredSearchOpensFromHome",
        "activityRecreationKeepsNavigationAvailable",
        "repeatedSettingsRoundTripsRemainStable",
    ],
    "Teste de estabilidade de navegação Android",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/data/PreferencesStore.kt",
    ["runCatching", "getOrDefault(AppThemeMode.Dark)", "optJSONObject"],
    "Tolerância de persistência Android",
)
require_markers(
    IOS / "Views/LibraryComponents.swift",
    ["AsyncOriginalPageImage", "CGImageSourceCreateThumbnailAtIndex", "Task.detached", "kCGImageSourceThumbnailMaxPixelSize"],
    "Carregamento assíncrono e limitado de imagens iOS",
)
reject_markers(
    IOS / "Views/ReadingDetailScreens.swift",
    ["UIImage(contentsOfFile:"],
    "Decodificação síncrona de imagem na interface iOS",
)
for entitlement in [
    IOS / "App/BreviarioMaconicoXXI.entitlements",
    IOS / "Widgets/BreviarioWidgetExtension.entitlements",
    IOS / "Watch/BreviarioWatch.entitlements",
]:
    require_markers(
        entitlement,
        [
            "group.com.renatocamargo.BreviarioMaconicoSeculoXXIPrivado",
            "com.apple.developer.ubiquity-kvstore-identifier",
        ],
        "App Group e restauração iCloud iOS",
    )
    try:
        entitlements = plistlib.loads(entitlement.read_bytes())
        for error in document_entitlement_errors(entitlements):
            fail(f"iCloud Documents: {entitlement.relative_to(ROOT)}: {error}")
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        fail(f"iCloud Documents: plist invalido em {entitlement.relative_to(ROOT)}: {error}")

if re.search(r"platformFilters?\s*=\s*(?:\(\s*)?iphoneos", pbx):
    fail("Filtro de plataforma invalido: usar ios, nao iphoneos, para incorporar o Watch.")

ios_production = "\n".join(
    path.read_text(encoding="utf-8")
    for path in IOS.rglob("*.swift")
    if "Tools" not in path.parts and "Tests" not in path.parts and "UITests" not in path.parts
)
android_production = "\n".join(
    path.read_text(encoding="utf-8")
    for path in (ANDROID / "app/src/main").rglob("*.kt")
)
for marker in ("try!", " as! ", "DispatchQueue.main.sync"):
    if marker in ios_production:
        fail(f"Segurança de execução iOS: padrão proibido encontrado: {marker}")
for marker in ("runBlocking", "GlobalScope", "allowMainThreadQueries"):
    if marker in android_production:
        fail(f"Segurança de execução Android: padrão proibido encontrado: {marker}")

for secret_pattern in (r"sk-proj-[A-Za-z0-9_-]+", r"AIzaSy[A-Za-z0-9_-]{20,}"):
    if re.search(secret_pattern, ios_production + "\n" + android_production):
        fail(f"Segurança: possível chave de API incorporada ao código: {secret_pattern}")

for source_root in (IOS / "App", IOS / "Views", IOS / "Services", ANDROID / "app/src/main", ANDROID / "wear/src/main"):
    if source_root.is_dir():
        for residue in source_root.rglob("*"):
            if residue.is_file() and (residue.name == ".DS_Store" or residue.suffix in {".bak", ".orig", ".tmp"}):
                fail(f"Resíduo de desenvolvimento em produção: {residue.relative_to(ROOT)}")

for modular_file in [
    IOS / "Models/AppNavigationController.swift",
    IOS / "Models/ReadingMetricsController.swift",
    IOS / "UITests/BibliotecaMaconicaUITests.swift",
    IOS / "Views/HomeViewComponents.swift",
    IOS / "Views/LibraryComponents.swift",
    IOS / "Views/ReadingComponents.swift",
    IOS / "Views/ExportComponents.swift",
    IOS / "Views/HomePresentation.swift",
    IOS / "Views/LibraryScreens.swift",
    IOS / "Views/SettingsScreens.swift",
    IOS / "Views/HomeActions.swift",
    IOS / "Views/AppLifecycleActions.swift",
    IOS / "Views/JustifiedTextComponents.swift",
    IOS / "Views/LibraryRequestActions.swift",
    IOS / "Views/LibrarySearchActions.swift",
    IOS / "Views/LibraryStudyScreens.swift",
    IOS / "Views/OfflineCatalogScreens.swift",
    IOS / "Views/PreferencesActions.swift",
    IOS / "Views/PremiumContentActions.swift",
    IOS / "Views/ReadingDetailScreens.swift",
    IOS / "Views/ReadingEditorComponents.swift",
    IOS / "Views/ReadingNavigationActions.swift",
    IOS / "Views/ReadingProgressPresentation.swift",
    IOS / "Views/RecentReadingPresentation.swift",
    IOS / "PDF/PDFLayoutRenderer.swift",
    IOS / "PDF/PDFTextRenderer.swift",
    IOS / "Services/BreviarioIndexImportService.swift",
    IOS / "Services/BreviarioOCRTextNormalizer.swift",
    IOS / "Services/BreviarioTitleIndexBuilder.swift",
    IOS / "Services/BreviarioStoreCatalog.swift",
    IOS / "Services/BreviarioStorePersistence.swift",
    IOS / "Services/BreviarioStoreSearch.swift",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/HomeUi.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/LibraryUi.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/LibraryReaderUi.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/LibrarySearchUi.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/LibraryReferenceUi.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/LibraryAIUi.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/ReaderUi.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/SettingsUi.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/AppEntryUi.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/StudyUi.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/ExportSupport.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/AppNavigationController.kt",
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/ReadingMetricsController.kt",
    ANDROID / "app/src/androidTest/java/com/renatocamargo/breviariomaconico/NavigationFlowTest.kt",
]:
    require_file(modular_file)

# Interfaces extensas voltam a concentrar responsabilidades e tornam a paridade
# frágil. O limite é falha deliberada, não apenas aviso informativo.
for source_root, suffix, limit, label in [
    (IOS / "Views", "*.swift", 750, "iOS Views"),
    (IOS / "PDF", "*.swift", 900, "iOS PDF"),
    (IOS / "Services", "*.swift", 900, "iOS Services"),
    (ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico", "*.kt", 600, "Android UI"),
    (ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/data", "*.kt", 600, "Android Data"),
]:
    for path in source_root.glob(suffix):
        line_count = len(path.read_text(encoding="utf-8").splitlines())
        if line_count > limit:
            fail(
                f"Arquitetura {label}: {path.name} possui {line_count} linhas; "
                f"limite modular é {limit}."
            )

require_markers(
    IOS / "Services/BibliotecaNotasSearch.swift",
    ["notes_fts", "?mode=ro", "cache_meta", "Task.checkCancellation", "obra_id != ?"],
    "Busca em notas iOS",
)
require_markers(
    ANDROID / "app/src/main/java/com/renatocamargo/breviariomaconico/data/NotesSearchIndex.kt",
    ["notes_fts", "readOnly = true", "cache_meta", "checkCancellation", "obra_id != ?"],
    "Busca em notas Android",
)

if not list((ANDROID / "app/src/test").rglob("*.kt")):
    warnings.append("Android ainda não possui testes unitários próprios.")
if "BreviarioMaconicoXXITests" not in pbx:
    warnings.append("iOS ainda não possui target XCTest próprio.")

if "--release" in sys.argv:
    contract = json.loads(require_file(ROOT / "Paridade/contrato-paridade.json"))
    audit = contract.get("functionalAudit", {})
    if audit.get("status") != "verified" or audit.get("openGaps"):
        fail("Liberacao bloqueada: auditoria funcional pendente. Consultar o relatorio e resolver as diferencas abertas.")

print("AUDITORIA ESTRUTURAL DE PARIDADE")
print(f"Falhas: {len(failures)}")
print(f"Alertas: {len(warnings)}")
for message in failures:
    print(f"FALHA: {message}")
for message in warnings:
    print(f"ALERTA: {message}")

sys.exit(1 if failures else 0)
