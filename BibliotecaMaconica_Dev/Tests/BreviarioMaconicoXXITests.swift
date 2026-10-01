import XCTest
import UserNotifications
import PDFKit
import UIKit
import SQLite3
import WatchConnectivity
@testable import BreviarioMaconicoXXI

final class BreviarioMaconicoXXITests: XCTestCase {
    @MainActor
    func testRemissiveIndexUsesExplicitWorkWithoutChangingActiveReading() async {
        let store = BreviarioStore()
        store.tarefaCarregamento?.cancel()
        store.tarefaCatalogo?.cancel()
        let other = BibliotecaObra(id: "index-empty-audit", titulo: "Sem índice editorial", autor: nil,
            area: .bibliotecaMaconica, tipo: .livro, recursoJSON: nil, descricao: "", assuntos: [], ativa: true)
        store.obras = [.breviarioSeculoXXI, other]
        store.obraSelecionada = .breviarioSeculoXXI
        let original = await store.montarIndiceRemissivoGlobal(escopo: .obraAtual, area: nil,
            obraID: ObraID.breviarioSeculoXXI)
        XCTAssertFalse(original.isEmpty)
        XCTAssertTrue(original.flatMap(\.ocorrencias).allSatisfy { $0.obra.id == ObraID.breviarioSeculoXXI })
        let absent = await store.montarIndiceRemissivoGlobal(escopo: .obraAtual, area: nil, obraID: other.id)
        let unknown = await store.montarIndiceRemissivoGlobal(escopo: .obraAtual, area: nil, obraID: "missing")
        let area = await store.montarIndiceRemissivoGlobal(escopo: .area, area: .bibliotecaMaconica)
        XCTAssertTrue(absent.isEmpty)
        XCTAssertTrue(unknown.isEmpty)
        XCTAssertTrue(area.isEmpty)
        XCTAssertEqual(store.obraSelecionada.id, ObraID.breviarioSeculoXXI)
    }

    func testMetadataFiltersFollowSharedCasesAndPrecedeSearchLimit() throws {
        struct Case: Decodable {
            let id: String; let author: String; let subject: String
            let workAuthor: String?; let topics: [String]; let matches: Bool
        }
        struct Fixture: Decodable { let metadataFilters: [Case] }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf:
            XCTUnwrap(Bundle.main.url(forResource: "casos_comuns_v1", withExtension: "json"))))
        for item in fixture.metadataFilters {
            let work = BibliotecaObra(id: item.id, titulo: "Obra", autor: item.workAuthor,
                area: .bibliotecaMaconica, tipo: .livro, recursoJSON: nil, descricao: "",
                assuntos: item.topics, ativa: true)
            XCTAssertEqual(BibliotecaFiltroMetadados(autor: item.author, assunto: item.subject).corresponde(work), item.matches, item.id)
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try BibliotecaSQLiteService(url: root.appendingPathComponent("filters.sqlite"))
        for id in ["a-excluded", "z-included"] {
            let included = id == "z-included"
            let work = BibliotecaRAGObra(id: id, area: .bibliotecaMaconica, tipo: .livro,
                titulo: "Obra \(id)", autor: included ? "José da Silva" : "Outro autor", origem: nil,
                edicao: nil, assuntos: included ? ["Ética"] : ["História"], dataImportacao: Date())
            let blocks = (1...60).map { BibliotecaRAGParagrafo(obraID: id, pagina: $0, ordem: 1,
                texto: "Vocabulário documental", capitulo: nil, secao: nil, temas: [], palavrasChave: []) }
            let notes = (1...60).map { BibliotecaRAGNotaRodape(obraID: id, pagina: $0, numero: "578", texto: "Termonota documental") }
            try db.substituirObra(obra: work, paginas: [], paragrafos: blocks, notas: notes, imagens: [])
        }
        let filter = BibliotecaFiltroMetadados(autor: "Jose", assunto: "etica")
        for query in ["vocabulário", "termonota"] {
            let hits = try db.buscarResultadosBiblioteca(termo: query, escopo: .appTodo, area: nil,
                obraID: nil, limite: 50, filtro: filter)
            XCTAssertEqual(hits.count, 50)
            XCTAssertTrue(hits.allSatisfy { $0.obra.id == "z-included" && $0.obra.autor == "José da Silva" && $0.obra.assuntos == ["Ética"] })
            XCTAssertTrue(try db.buscarResultadosBiblioteca(termo: query, escopo: .obraAtual, area: nil,
                obraID: "a-excluded", filtro: filter).isEmpty)
            XCTAssertTrue(try db.buscarResultadosBiblioteca(termo: query, escopo: .area, area: .judiciarioMaconico,
                obraID: nil, filtro: filter).isEmpty)
        }
        XCTAssertEqual(filter.descricao, "Autor: Jose • Assunto: etica")
    }
    func testReadingIntroDoesNotRepeatBodyPrefixesButKeepsDistinctQuotes() throws {
        let body = "A Croácia é um país do Leste Europeu.\n\nContinuação integral da leitura."
        let duplicate = BreviarioItem(id: 1, data: "21/09", titulo: "Teste", frase: "A Croácia é um país do Leste Europeu.", texto: body)
        XCTAssertNil(duplicate.fraseExibicao)
        XCTAssertEqual(duplicate.texto, body)
        XCTAssertEqual(duplicate.resumo, duplicate.frase, "Fixing the reader must not change the Home preview")
        let quote = BreviarioItem(id: 2, data: "22/09", titulo: "Teste", frase: "Uma citação editorial distinta.", texto: body)
        XCTAssertEqual(quote.fraseExibicao, "Uma citação editorial distinta.")
        struct Source: Decodable { let itens: [BreviarioItem] }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "breviario", withExtension: "json"))
        let readings = try JSONDecoder().decode(Source.self, from: Data(contentsOf: url)).itens
        XCTAssertGreaterThanOrEqual(readings.count, 365)
        for reading in readings {
            XCTAssertNil(reading.fraseExibicao, "Bundled intro must not repeat the original body: \(reading.data)")
        }
    }

    @MainActor
    func testContinuousReadingStartsAtSelectedPageAndKeepsTheRestOfTheWork() {
        let pages = (1...4).map { index in
            BreviarioItem(id: index, data: "P\(index)", titulo: "Página \(index)", frase: "",
                          texto: "Texto \(index)", rodape: "578 Nota \(index)", pagina: index, obraID: "book")
        }
        let other = BreviarioItem(id: 2, data: "P2", titulo: "Outra obra", frase: "", texto: "Outra obra", pagina: 2, obraID: "other")
        let result = HomeView.itensLeituraContinua([other] + pages.reversed(), aPartirDe: pages[1])
        XCTAssertEqual(result.map(\.chavePersistencia), Array(pages.dropFirst()).map(\.chavePersistencia))
        XCTAssertEqual(result.map(\.rodape), Array(pages.dropFirst()).map(\.rodape))
        XCTAssertEqual(HomeView.itensLeituraContinua([], aPartirDe: pages[1]).map(\.chavePersistencia), [pages[1].chavePersistencia])
        XCTAssertEqual(HomeView.itensLeituraContinua(pages, aPartirDe: pages[0]).count, 4)
    }

    func testImportedBooksDoNotInheritTheDailyWorksAuthor() throws {
        let base: [String: Any] = ["id": 1, "data": "P1", "titulo": "Livro", "texto": "Texto integral"]
        func decode(work: String?, author: String?) throws -> BreviarioItem {
            var json = base
            json["obraID"] = work
            json["autor"] = author
            return try JSONDecoder().decode(BreviarioItem.self, from: JSONSerialization.data(withJSONObject: json))
        }
        XCTAssertNil(try decode(work: "outro-livro", author: nil).autor)
        XCTAssertEqual(try decode(work: "outro-livro", author: "Autor documental").autor, "Autor documental")
        XCTAssertEqual(try decode(work: nil, author: nil).autor, BreviarioImportService.autorPadrao)
    }

    @MainActor
    func testUnknownAuthorshipRemainsUnknownInSharingAIAndPDFMetadata() throws {
        func reading(author: String?, work: String = "audit-authorship") -> BreviarioItem {
            BreviarioItem(id: 1, data: "P1", titulo: "Obra documental", frase: "",
                          texto: "Texto original integral", rodape: "578 Nota integral",
                          autor: author, pagina: 1, obraID: work)
        }
        for author in [nil, "", "  \n"] as [String?] {
            let item = reading(author: author)
            XCTAssertNil(item.autorDocumental)
            XCTAssertFalse(item.textoCompartilhavel.contains("Kennyo"))
            XCTAssertFalse(item.conteudoIntegralParaIA.contains("Kennyo"))
            XCTAssertFalse(item.conteudoIntegralParaIA.contains("Autor:"))
            XCTAssertTrue(item.conteudoIntegralParaIA.contains(item.texto))
            XCTAssertTrue(item.conteudoIntegralParaIA.contains("578 Nota integral"))
            let url = try HomeView.gerarArquivoTextoExportacao(itens: [item], incluirComentarios: false)
            defer { try? FileManager.default.removeItem(at: url) }
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.contains("Kennyo"))
            XCTAssertFalse(text.contains("Autor:"))
            XCTAssertTrue(text.contains("578 Nota integral"))
            XCTAssertNil(PDFService.formatoPDF(titulo: item.titulo, autor: item.autorDocumental)
                .documentInfo[kCGPDFContextAuthor as String])
        }
        let documented = reading(author: "Autora documental")
        XCTAssertTrue(documented.textoCompartilhavel.contains("Autor: Autora documental"))
        XCTAssertTrue(documented.conteudoIntegralParaIA.contains("Autor: Autora documental"))
        XCTAssertEqual(PDFService.autorPrincipal([documented, reading(author: nil), documented]), "Autora documental")
        XCTAssertEqual(PDFService.autorPrincipal([documented, reading(author: "Outro autor")]), "Autora documental; Outro autor")
        let original = reading(author: nil, work: ObraID.breviarioSeculoXXI)
        XCTAssertEqual(original.autorDocumental, BreviarioImportService.autorPadrao)
        XCTAssertEqual(original.cabecalhoDocumental, BreviarioImportService.cabecalho)
    }

    @MainActor
    func testHighlightSelectionKeepsNativeMenuAndSavesOnlyItsPage() throws {
        let work = "highlight-audit-\(UUID().uuidString)"
        let otherWork = "other-\(work)"
        defer {
            for id in [work, otherWork] {
                for page in ["P1", "P2"] { UserDefaults.standard.removeObject(forKey: "destaques_\(id)_\(page)") }
            }
        }
        DestaquesService.salvar("Marcador da primeira página", para: "P1", obraID: work)
        let coordinator = JustifiedTextUIView.Coordinator(aoSelecionarTexto: nil)
        coordinator.aoDestacarTexto = { DestaquesService.salvar($0, para: "P2", obraID: work) }
        let view = UITextView()
        view.text = "Trecho com acentuação e símbolo: □."
        let range = NSRange(view.text.startIndex..<view.text.endIndex, in: view.text)
        let copy = UIAction(title: "Copiar") { _ in }
        let menu = try XCTUnwrap(coordinator.textView(view, editMenuForTextIn: range, suggestedActions: [copy]))
        XCTAssertEqual(menu.children.map(\.title), ["Destacar", "Copiar"])
        XCTAssertNil(coordinator.textView(view, editMenuForTextIn: NSRange(location: 0, length: 0), suggestedActions: []))
        coordinator.destacar(view.text)
        XCTAssertEqual(DestaquesService.carregar(data: "P1", obraID: work).map(\.texto), ["Marcador da primeira página"])
        XCTAssertEqual(DestaquesService.carregar(data: "P2", obraID: work).map(\.texto), [view.text!])
        XCTAssertTrue(DestaquesService.carregar(data: "P2", obraID: otherWork).isEmpty)
        coordinator.ativo = false
        coordinator.destacar("Ação atrasada após fechar a leitura")
        XCTAssertEqual(DestaquesService.carregar(data: "P2", obraID: work).count, 1)
    }

    func testHighlightChangesNotifyOnlyTheirWorkAndPage() {
        let work = "highlight-notification-\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: "destaques_\(work)_P2") }
        let notified = expectation(forNotification: DestaquesService.alterados, object: nil) { notification in
            notification.userInfo?["obraID"] as? String == work && notification.userInfo?["data"] as? String == "P2"
        }
        DestaquesService.salvar("Trecho específico", para: "P2", obraID: work)
        wait(for: [notified], timeout: 2)
    }

    @MainActor
    func testProgressObserverCanQueueAnotherEditWithoutDeadlockOrLostUpdate() async throws {
        guard WCSession.isSupported() else { throw XCTSkip("WatchConnectivity unavailable") }
        let suite = "progress-reentry-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let previousDelegate = WCSession.default.delegate
        defer {
            WCSession.default.delegate = previousDelegate
            defaults.removePersistentDomain(forName: suite)
        }
        let transport = ReadingProgressSyncTransport(defaults: defaults)
        let observed = expectation(description: "Incoming event can trigger a local edit")
        await transport.start { event in
            transport.enviar(obraID: event.workID, data: "02/06", lido: true)
            observed.fulfill()
        }?.value
        let event = ReadingProgressEvent(workID: "reentry-test", date: "01/06", read: true,
                                         timestamp: 100, eventID: "incoming")
        transport.session(WCSession.default, didReceiveMessage: event.message)
        await fulfillment(of: [observed], timeout: 5)
        let ledger = try JSONDecoder().decode(ReadingProgressLedger.self,
            from: XCTUnwrap(defaults.data(forKey: "reading_progress_sync_v1")))
        XCTAssertEqual(ledger.latest[event.key], event)
        XCTAssertEqual(ledger.latest["reentry-test|02/06"]?.read, true)
        XCTAssertEqual(ledger.latest.count, 2)
    }

    func testImportedWorkIdentifiersKeepRepeatedTitlesIndependentAndBounded() {
        let title = String(repeating: "História maçônica ", count: 100)
        let identifiers = (0..<100).map { _ in BreviarioStore.criarIDObra(titulo: title) }
        XCTAssertEqual(Set(identifiers).count, 100)
        XCTAssertTrue(identifiers.allSatisfy { $0.utf8.count < 220 && !$0.contains("/") })
        XCTAssertFalse(BreviarioStore.criarIDObra(titulo: "🗂️").isEmpty)
    }

    func testNotesOnlySearchUsesCommonCasesAndInvalidatesCacheWithoutChangingOriginal() throws {
        struct Case: Decodable { let id: String; let query: String; let text: String; let matches: Bool }
        struct Fixture: Decodable { let search: [Case] }
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf:
            XCTUnwrap(Bundle.main.url(forResource: "casos_comuns_v1", withExtension: "json"))))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("notes.sqlite")
        var writer: BibliotecaSQLiteService? = try BibliotecaSQLiteService(url: url)
        let work = BibliotecaRAGObra(id: "notes", area: .dicionariosMaconicos, tipo: .livro,
            titulo: "Notas", autor: nil, origem: nil, edicao: nil, assuntos: [], dataImportacao: Date())
        for item in fixture.search {
            try XCTUnwrap(writer).substituirObra(obra: work, paginas: [], paragrafos: [],
                notas: [.init(obraID: work.id, pagina: 9, numero: "578", texto: item.text)], imagens: [])
            let hits = try XCTUnwrap(writer).buscarTexto(termo: item.query, obraID: work.id)
            XCTAssertEqual(hits.count, item.matches ? 1 : 0, item.id)
            if let hit = hits.first {
                XCTAssertEqual(hit.pagina, 9)
                XCTAssertTrue(hit.blocoID.hasPrefix("nota:"))
                XCTAssertEqual(hit.trecho, "578 " + item.text)
            }
        }
        let notes = (1...137).map { BibliotecaRAGNotaRodape(obraID: work.id, pagina: $0, numero: "578", texto: "Vocabulário exclusivo") }
        try XCTUnwrap(writer).substituirObra(obra: work, paginas: [], paragrafos: [], notas: notes, imagens: [])
        writer = nil
        let original = try Data(contentsOf: url)
        let reader = try BibliotecaSQLiteService(url: url, somenteLeitura: true)
        XCTAssertEqual(try reader.buscarTexto(termo: "vocabulário", area: .dicionariosMaconicos, limite: 200).count, 137)
        XCTAssertTrue(try reader.buscarTexto(termo: "vocabulário", area: .bibliotecaMaconica).isEmpty)
        XCTAssertTrue(try reader.buscarTexto(termo: "vocabulário", obrasExcluidas: [work.id]).isEmpty)
        XCTAssertTrue(try reader.buscarTexto(termo: "vocabulário", obraID: "other").isEmpty)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testReimportReplacesSearchIndexAndRepairsLegacyRows() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("local.sqlite")
        var database: BibliotecaSQLiteService? = try BibliotecaSQLiteService(url: url)
        let work = BibliotecaRAGObra(id: "reimport", area: .bibliotecaMaconica, tipo: .livro,
            titulo: "Obra", autor: nil, origem: nil, edicao: nil, assuntos: [], dataImportacao: Date())
        func replace(_ text: String) throws {
            let block = BibliotecaRAGParagrafo(obraID: work.id, pagina: 1, ordem: 1, texto: text,
                capitulo: nil, secao: nil, temas: [], palavrasChave: [])
            try database?.substituirObra(obra: work, paginas: [], paragrafos: [block], notas: [], imagens: [])
        }
        try replace("terminoantigo")
        try replace("terminonovo")
        try replace("terminonovo")
        XCTAssertTrue(try XCTUnwrap(database).buscarTexto(termo: "terminoantigo").isEmpty)
        XCTAssertEqual(try XCTUnwrap(database).buscarTexto(termo: "terminonovo").count, 1)
        database = nil
        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &raw), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(raw, "DELETE FROM rag_migracoes; UPDATE rag_fts SET texto = 'residuolegado';", nil, nil, nil), SQLITE_OK)
        sqlite3_close(raw)
        // A downloaded package must not be migrated or changed on a read-only open.
        let before = try Data(contentsOf: url)
        database = try BibliotecaSQLiteService(url: url, somenteLeitura: true)
        database = nil
        XCTAssertEqual(try Data(contentsOf: url), before)
        database = try BibliotecaSQLiteService(url: url)
        XCTAssertTrue(try XCTUnwrap(database).buscarTexto(termo: "residuolegado").isEmpty)
        XCTAssertEqual(try XCTUnwrap(database).buscarTexto(termo: "terminonovo").count, 1)
        database = nil
        database = try BibliotecaSQLiteService(url: url)
        XCTAssertEqual(try XCTUnwrap(database).buscarTexto(termo: "terminonovo").count, 1)
    }

    @MainActor
    func testDossierExportsEveryFullSourceNoteAndOptionalAnalysis() throws {
        struct Fixture: Decodable {
            struct Dossier: Decodable { let topic: String; let sourceCount: Int; let review: [String] }
            let dossier: Dossier
        }
        let fixtureURL = try XCTUnwrap(Bundle.main.url(forResource: "casos_comuns_v1", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: fixtureURL)).dossier
        let work = BibliotecaObra(id: "audit", titulo: "Obra de teste", autor: nil, area: .bibliotecaMaconica,
            tipo: .livro, recursoJSON: nil, descricao: "", assuntos: [], ativa: true)
        let hits = (1...fixture.sourceCount).map { index in
            BibliotecaResultadoBusca(obra: work, item: BreviarioItem(id: index, data: "P\(index)",
                titulo: "Fonte \(index)", frase: "", texto: String(repeating: "Texto documental integral. ", count: 40) + "FIMFONTE\(index)FIM",
                rodape: "578 NOTAFONTE\(index)FIM", pagina: index, obraID: "audit"), contexto: "Apenas resumo")
        }
        let review = BreviarioStore.revisaoEspacada(termo: fixture.topic)
        XCTAssertEqual(review, fixture.review)
        let terms = BreviarioStore.termosRelacionados(termo: fixture.topic, resultados: hits)
        let roadmap = BreviarioStore.roteiroEstudo(termo: fixture.topic, resultados: hits)
        let questions = BreviarioStore.perguntasFixacao(termo: fixture.topic, resultados: hits)
        let conceptMap = BreviarioStore.mapaConceitual(termo: fixture.topic, resultados: hits, termosRelacionados: terms)
        let crossings = BreviarioStore.cruzamentosEstudo(resultados: hits)
        let limits = BreviarioStore.limitesDaBase(resultados: hits)
        let plan = ["roadmap": roadmap, "questions": questions, "conceptMap": conceptMap,
                    "spacedReview": review, "crossReferences": crossings, "relatedTerms": terms, "limits": limits]
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try JSONEncoder().encode(plan).write(to: documents.appendingPathComponent("paridade-dossie-plano-ios.json"))
        let dossier = BibliotecaDossieEstudo(termo: fixture.topic, escopo: .appTodo, area: nil,
            resultados: hits, termosRelacionados: terms, obrasEnvolvidas: [work], roteiro: roadmap, perguntasFixacao: questions,
            mapaConceitual: conceptMap, revisaoEspacada: review, cruzamentos: crossings, limitesDaBase: limits,
            filtroMetadados: .init(autor: "José", assunto: "Ética"))
        let text = HomeView.textoDossieEstudo(dossier)
        XCTAssertEqual(text, "Dossiê de estudo\n\n" + PDFService.textoDossieEstudo(dossier))
        let prompt = HomeView.promptAnaliseDossie(dossier, fontesOficiais: [])
        let url = try PDFService.gerarPDFDossieEstudo(dossier, analise: "ANALISEINTEGRALFIM [F30]")
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("paridade-dossie-ios.pdf")
        if FileManager.default.fileExists(atPath: output.path) { try FileManager.default.removeItem(at: output) }
        try FileManager.default.copyItem(at: url, to: output)
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try XCTUnwrap(PDFDocument(url: output))
        let pdfText = try XCTUnwrap(pdf.string)
        for index in 1..<pdf.pageCount {
            XCTAssertTrue(try XCTUnwrap(pdf.page(at: index)?.string).contains("Biblioteca Maçônica"))
        }
        for content in [text, pdfText] {
            XCTAssertTrue(content.contains("Autor: José"))
            XCTAssertTrue(content.contains("Assunto: Ética"))
        }
        for index in 1...fixture.sourceCount {
            for content in [text, prompt, pdfText] {
                XCTAssertTrue(content.contains("[F\(index)]"))
                XCTAssertTrue(content.contains("FIMFONTE\(index)FIM"))
                XCTAssertTrue(content.contains("NOTAFONTE\(index)FIM"))
            }
        }
        XCTAssertTrue(pdfText.contains("ANALISEINTEGRALFIM"))
        XCTAssertFalse(text.contains("Análise por IA"))
    }

    func testProgressSyncSharedVersionedCases() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "progress_sync_v1", withExtension: "tsv"))
        let rows = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").dropFirst()
        XCTAssertEqual(rows.count, 9)
        for row in rows {
            let parts = row.split(separator: "\t").map(String.init)
            XCTAssertEqual(parts.count, 8)
            var ledger = ReadingProgressLedger()
            _ = ledger.receive(ReadingProgressEvent(workID: "obra", date: "20/09", read: parts[3] == "true", timestamp: Int64(parts[1])!, eventID: parts[2]))
            let event = ReadingProgressEvent(workID: "obra", date: "20/09", read: parts[6] == "true", timestamp: Int64(parts[4])!, eventID: parts[5])
            XCTAssertEqual(ledger.receive(event), parts[7] == "true", parts[0])
        }
    }

    func testBackupMergesIndependentOfflineEdits() throws {
        var first = UserBackupSnapshot()
        first.capture(["comentario_01/01": "Original", "temaApp": "claro"], now: Date(timeIntervalSince1970: 100), revision: "base")
        var second = first
        first.capture(["comentario_01/01": "Comentário novo", "temaApp": "claro"], now: Date(timeIntervalSince1970: 200), revision: "a")
        second.capture(["comentario_01/01": "Original", "temaApp": "sepia"], now: Date(timeIntervalSince1970: 201), revision: "b")
        first.merge(second); second.merge(first)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.values["comentario_01/01"] as? String, "Comentário novo")
        XCTAssertEqual(first.values["temaApp"] as? String, "sepia")
    }

    func testBackupReadSetsMergeAdditionsAndKeepDeletions() throws {
        var first = UserBackupSnapshot()
        first.capture(["leituras_concluidas": ["01/01", "02/01"]], now: Date(timeIntervalSince1970: 100), revision: "base")
        let stale = first
        var second = first
        first.capture(["leituras_concluidas": ["02/01"]], now: Date(timeIntervalSince1970: 200), revision: "a")
        second.capture(["leituras_concluidas": ["01/01", "02/01", "03/01"]], now: Date(timeIntervalSince1970: 201), revision: "b")
        first.merge(second); first.merge(stale)
        XCTAssertEqual(first.values["leituras_concluidas"] as? [String], ["02/01", "03/01"])
        first.capture([:])
        first.merge(stale)
        XCTAssertNil(first.values["leituras_concluidas"])
    }

    func testBackupMigrationRoundTripAndCorruptEnvelope() throws {
        let legacy = try PropertyListSerialization.data(fromPropertyList: [
            "versao": 2, "atualizadoEm": Date(timeIntervalSince1970: 100),
            "dados": ["comentario_01/01": "Texto íntegro", "leituras_favoritas": ["01/01"]]
        ], format: .xml, options: 0)
        let snapshot = try XCTUnwrap(UserBackupSnapshot.decode(legacy))
        XCTAssertEqual(snapshot.values["comentario_01/01"] as? String, "Texto íntegro")
        XCTAssertEqual(UserBackupSnapshot.decode(try snapshot.encoded()), snapshot)
        XCTAssertNil(UserBackupSnapshot.decode(Data("arquivo corrompido".utf8)))
        let incomplete = try PropertyListSerialization.data(fromPropertyList: ["versao": 3, "dados": ["temaApp": "claro"]], format: .xml, options: 0)
        XCTAssertNil(UserBackupSnapshot.decode(incomplete))
    }

    func testBackupUnchangedCaptureDoesNotAdvanceVersions() throws {
        var snapshot = UserBackupSnapshot()
        let values: [String: Any] = ["temaApp": "escuro", "leituras_favoritas": ["01/01", "02/01"], "edicoes_textos_diarios": ["01/01": "Texto", "02/01": "Outro"]]
        snapshot.capture(values)
        let before = snapshot
        snapshot.capture(values, now: Date().addingTimeInterval(100))
        XCTAssertEqual(snapshot, before)
    }

    func testBackupPreservesFieldsFromNewerAppVersions() {
        var snapshot = UserBackupSnapshot()
        snapshot.capture(["campo_futuro": "preservar", "comentario_01/01": "remover"])
        snapshot.capture([:], managedKeys: ["comentario_01/01"])
        XCTAssertEqual(snapshot.values["campo_futuro"] as? String, "preservar")
        XCTAssertNil(snapshot.values["comentario_01/01"])
    }

    func testProgressSyncOfflineMultipleWorksAndRestart() throws {
        var state = ReadingProgressLedger()
        _ = state.edit(work: "obra_a", date: "20/09", read: true, now: 100, id: "a")
        _ = state.edit(work: "obra_b", date: "20/09", read: true, now: 100, id: "b")
        _ = state.edit(work: "obra_a", date: "21/09", read: true, now: 100, id: "c")
        let restored = try JSONDecoder().decode(ReadingProgressLedger.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.pending.count, 3)
        XCTAssertEqual(restored.latest, state.latest)
    }

    func testProgressSyncRejectsDuplicateStaleAndLegacyMessages() throws {
        var state = ReadingProgressLedger()
        let first = try XCTUnwrap(state.edit(work: "obra", date: "20/09", read: true, now: 100, id: "a"))
        let last = try XCTUnwrap(state.edit(work: "obra", date: "20/09", read: false, now: 90, id: "b"))
        XCTAssertGreaterThan(last.timestamp, first.timestamp)
        XCTAssertFalse(state.receive(first))
        XCTAssertFalse(state.receive(last))
        XCTAssertFalse(state.receive(ReadingProgressEvent(workID: "obra", date: "20/09", read: true, timestamp: 0, eventID: "legacy")))
        XCTAssertEqual(state.latest[last.key], last)
        state.delivered(first)
        XCTAssertEqual(state.pending[last.key], last)
        state.delivered(last)
        XCTAssertTrue(state.pending.isEmpty)
    }

    func testProgressSyncTieBreakConvergesAndRoundTrips() throws {
        let a = ReadingProgressEvent(workID: "obra", date: "29/02", read: true, timestamp: 100, eventID: "a")
        let b = ReadingProgressEvent(workID: "obra", date: "29/02", read: false, timestamp: 100, eventID: "b")
        var first = ReadingProgressLedger(), second = ReadingProgressLedger()
        XCTAssertTrue(first.receive(a)); XCTAssertTrue(first.receive(b))
        XCTAssertTrue(second.receive(b)); XCTAssertFalse(second.receive(a))
        XCTAssertEqual(first.latest, second.latest)
        XCTAssertEqual(ReadingProgressEvent.parse(b.message), b)
        for date in ["31/04", "32/01", "00/09", "20/13", "1/09", "ab/cd", "01/+1"] {
            XCTAssertNil(first.edit(work: "obra", date: date, read: true, now: 100))
        }
        XCTAssertNil(ReadingProgressEvent.parse(["tipo": "progresso", "obraID": "obra", "data": "01/01"]))
        XCTAssertNil(first.edit(work: "obra", date: "01/01", read: true, now: .max))
        XCTAssertNil(first.edit(work: "obra", date: "01/01", read: true, now: 100, id: ""))
    }

    @MainActor
    func testThemeTextAndStatusContrast() {
        func components(_ color: UIColor) -> [Double] {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            return [red, green, blue, alpha].map(Double.init)
        }
        func blend(_ foreground: [Double], _ background: [Double]) -> [Double] {
            (0..<3).map { foreground[$0] * foreground[3] + background[$0] * (1 - foreground[3]) } + [1]
        }
        func luminance(_ rgba: [Double]) -> Double {
            let linear = rgba.prefix(3).map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
        }
        func contrast(_ first: [Double], _ second: [Double]) -> Double {
            let a = luminance(first), b = luminance(second)
            return (max(a, b) + 0.05) / (min(a, b) + 0.05)
        }
        XCTAssertEqual(contrast([1, 1, 1, 1], [0, 0, 0, 1]), 21, accuracy: 0.0001)
        for theme in TemaLeitura.allCases {
            let stops = theme.backgroundColors.map { components(UIColor($0)) }
            let panel = components(UIColor(theme.painel))
            let surfaces = stops + stops.map { blend(panel, $0) }
            let roles = [theme.textoPrincipal, theme.textoSecundario, theme.destaque, theme.sucesso]
            for surface in surfaces {
                for color in roles {
                    XCTAssertGreaterThanOrEqual(contrast(components(UIColor(color)), surface), 4.5, "Theme \(theme.rawValue)")
                }
                let selected = blend(components(UIColor(theme.sucesso.opacity(0.12))), surface)
                XCTAssertGreaterThanOrEqual(contrast(components(UIColor(theme.textoPrincipal)), selected), 4.5)
            }
            XCTAssertGreaterThanOrEqual(contrast(components(UIColor(theme.textoSobreDestaque)), components(UIColor(theme.fundoDestaque))), 4.5)
        }
    }

    func testNotificationReadingKeepsRequestedDateAndWork() throws {
        let item = try XCTUnwrap(BreviarioSnapshotProvider.leitura(data: "01/06", obraID: "breviario_seculo_xxi"))
        XCTAssertEqual(item.data, "01/06")
        XCTAssertEqual(item.obraID, "breviario_seculo_xxi")
        XCTAssertFalse(item.texto.isEmpty)
        XCTAssertTrue(item.rodape?.contains("578") == true)
        XCTAssertNil(BreviarioSnapshotProvider.leitura(data: "01/06", obraID: "obra_inexistente"))
        XCTAssertNil(BreviarioSnapshotProvider.leitura(data: "99/99", obraID: "breviario_seculo_xxi"))
    }

    func testWidgetLoadsBothPermanentBreviariesForTheDay() throws {
        let date = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 26)))
        let readings = BreviarioSnapshotProvider.leiturasDoDia(data: date)
        XCTAssertEqual(readings.count, 2)
        XCTAssertEqual(Set(readings.map(\.obraID)), Set(["breviario_seculo_xxi", "breviario_rizzardo_da_camino"]))
        XCTAssertTrue(readings.allSatisfy { $0.data == "26/09" && !$0.titulo.isEmpty && !$0.texto.isEmpty })
    }

    func testLiveGeminiGroundingAndMissingEvidence() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LIVE_GEMINI_TESTS"] == "1" else {
            throw XCTSkip("Live Gemini requires an explicitly configured test credential and opt-in.")
        }
        let key = GeminiAPIKeyStore.carregar()
        guard !key.isEmpty else { throw XCTSkip("No Gemini test key configured in this app's Keychain.") }
        let sources = "[F1] Documento sintético de teste: a sala de estudos tem sete cadeiras. [F2] Documento sintético de teste: a sala possui duas mesas."
        let response = try await GeminiAnaliseService.gerarTexto(
            prompt: "Use exclusivamente estas fontes: \(sources). Quantas cadeiras e mesas existem? Responda uma frase com números em algarismos e cite [F1] e [F2].", chaveAPI: key)
        try GeminiAnaliseService.validarCitacoes(response, quantidadeFontes: 2)
        XCTAssertTrue(response.contains("7") && response.contains("2"))
        XCTAssertTrue(response.contains("[F1]") && response.contains("[F2]"))
        let refusal = try await GeminiAnaliseService.gerarTexto(
            prompt: "Use exclusivamente estas fontes: \(sources). Em que ano a sala foi construída? Caso a fonte não informe o ano, retorne somente DOCUMENTO_INSUFICIENTE. Não invente informações.", chaveAPI: key)
        XCTAssertEqual(refusal.trimmingCharacters(in: .whitespacesAndNewlines), "DOCUMENTO_INSUFICIENTE")
    }
    func testFullCatalogBenchmarkWhenAuditCorpusIsInstalled() throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let catalogURL = documents.appendingPathComponent("rag_catalogo.json")
        guard FileManager.default.fileExists(atPath: catalogURL.path) else {
            throw XCTSkip("Install the validated audit corpus in the test simulator to run this benchmark.")
        }
        let service = try BibliotecaRAGCatalogService(catalogoURL: catalogURL)
        XCTAssertEqual(service.pacotes.count, 314)
        XCTAssertFalse(service.obras().contains { $0.id == "breviario_maconico_rizzardo_da_camino" })
        for package in service.pacotes {
            XCTAssertNotNil(service.urlOrigemPacote(package), package.arquivo)
        }
        var timings: [[String: Any]] = []
        for query in ["maçonaria", "\"grande loja\"", "ética virtude"] {
            let start = ProcessInfo.processInfo.systemUptime
            let hits = try service.buscar(termo: query, escopo: .appTodo, area: nil, obraID: nil, limite: 120)
            let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000
            XCTAssertFalse(hits.isEmpty)
            XCTAssertLessThanOrEqual(hits.count, 120)
            XCTAssertEqual(Set(hits.map(\.id)).count, hits.count)
            XCTAssertLessThan(milliseconds, 15_000)
            timings.append(["query": query, "milliseconds": milliseconds, "hits": hits.count])
        }
        for area in BibliotecaArea.allCases {
            XCTAssertTrue(try service.buscar(termo: "maçonaria", escopo: .area, area: area, obraID: nil).allSatisfy { $0.obra.area == area })
        }
        // Same books-only scope on both platforms; compared result by result across iOS and Android.
        var topResults: [String: [String]] = [:]
        for query in ["maçonaria", "\"grande loja\"", "ética virtude", "\"escada de jacó\""] {
            let hits = try service.buscar(termo: query, escopo: .area, area: .bibliotecaMaconica, obraID: nil, limite: 120)
            topResults[query] = hits.map { "\($0.obra.id):\($0.item.pagina ?? 0):\($0.blocoID ?? $0.item.data)" }
        }
        let largest = try XCTUnwrap(service.pacotes.flatMap(\.obras).max { $0.paginas < $1.paginas })
        let start = ProcessInfo.processInfo.systemUptime
        let pages = try service.carregarIndicePaginas(obraID: largest.id)
        XCTAssertEqual(pages.count, largest.paginas)
        let report: [String: Any] = [
            "environment": "iPhone simulator; not a physical-device certification",
            "packages": service.pacotes.count, "queries": timings, "topResults": topResults,
            "largestWorkPages": pages.count,
            "pageIndexMilliseconds": (ProcessInfo.processInfo.systemUptime - start) * 1000
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: documents.appendingPathComponent("medicao-acervo-ios.json"), options: .atomic)
    }

    /// Real-corpus dossier for "Escada de Jacó" in the books area, compared with Android item by item.
    func testCorpusDossierIsRecordedForParity() throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let catalogURL = documents.appendingPathComponent("rag_catalogo.json")
        guard FileManager.default.fileExists(atPath: catalogURL.path) else { throw XCTSkip("Audit corpus not installed") }
        let service = try BibliotecaRAGCatalogService(catalogoURL: catalogURL)
        let configuracao = try XCTUnwrap(DossieEstudoAnalise.Configuracao.compartilhada)
        let termo = "Escada de Jacó"
        let resultados = try service.buscar(termo: "\"\(termo)\"", escopo: .area, area: .bibliotecaMaconica, obraID: nil,
                                            limite: configuracao.limites.fontesAnalisadas, variantes: configuracao.variantes)
        XCTAssertFalse(resultados.isEmpty)
        let fontes = BreviarioStore.fontesDossie(resultados)
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "UTC")!
        let hoje = try XCTUnwrap(calendario.date(from: DateComponents(year: 2026, month: 9, day: 27)))
        let inicio = ProcessInfo.processInfo.systemUptime
        let analise = DossieEstudoAnalise.analisar(termo: termo, fontes: fontes, configuracao: configuracao, hoje: hoje, calendario: calendario)
        let milissegundos = (ProcessInfo.processInfo.systemUptime - inicio) * 1000
        XCTAssertFalse(analise.resumo.isEmpty)
        var relatorio = analise.json
        relatorio["exibicao"] = DossieEstudoAnalise.exibicao(termo: termo, resultado: analise, fontes: fontes, configuracao: configuracao).json
        relatorio["fontesIds"] = fontes.map(\.id)
        relatorio["milissegundosAnalise"] = milissegundos
        // The AI prompt for the excerpts shown in this dossier, compared byte by byte with Android.
        relatorio["promptIA"] = InterpretacaoAssistida.prompt(
            termo: termo, fontes: Array(fontes.prefix(configuracao.limites.fontesExibidas)), oficiais: [],
            configuracao: try XCTUnwrap(InterpretacaoAssistida.Configuracao.compartilhada), estudo: configuracao)
        try JSONSerialization.data(withJSONObject: relatorio, options: [.prettyPrinted, .sortedKeys])
            .write(to: documents.appendingPathComponent("dossie-acervo-ios.json"), options: .atomic)
    }

    func testFullCatalogStudyBatchesWhenAuditCorpusIsInstalled() throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let catalogURL = documents.appendingPathComponent("rag_catalogo.json")
        guard FileManager.default.fileExists(atPath: catalogURL.path) else { throw XCTSkip("Audit corpus not installed") }
        let catalog = try BibliotecaRAGCatalogService(catalogoURL: catalogURL)
        let rules = RegrasEstudo.compartilhadas
        let words = (rules.colecoes.map(\.palavrasChave) + rules.trilhas.map(\.palavrasChave))
            .map { RegrasEstudo.palavrasChave($0.map(RegrasEstudo.normalizar)) }
        let limits = Array(repeating: rules.collectionLimit, count: rules.colecoes.count) + Array(repeating: rules.pathLimit, count: rules.trilhas.count)
        let start = ProcessInfo.processInfo.systemUptime
        let works = Set(catalog.obras().map(\.id))
        let scored = try catalog.pontuarEstudo(obraIDs: works, regras: words, limites: limits)
        XCTAssertTrue(scored.falhas.isEmpty, "Packages failed: \(scored.falhas)")
        let selected = scored.pontuacoes
        let total = catalog.totaisPorObra().filter { works.contains($0.key) }.values.reduce(0, +)
        let maxBatch = 0
        for i in selected.indices {
            XCTAssertFalse(selected[i].isEmpty)
            XCTAssertLessThanOrEqual(selected[i].count, limits[i])
            XCTAssertTrue(selected[i].allSatisfy { $0.referencia.pagina > 0 })
        }
        let report: [String: Any] = ["pages": total, "maxBatch": maxBatch, "milliseconds": (ProcessInfo.processInfo.systemUptime - start) * 1000,
            "resultsPerRule": selected.map(\.count),
            "ruleIDs": rules.colecoes.map(\.id) + rules.trilhas.map(\.id),
            "selectedPages": selected.map { $0.map { "\($0.referencia.obraID):\($0.referencia.pagina)" } },
            "engine": "fts5vocab", "environment": "simulator, not physical certification"]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: documents.appendingPathComponent("medicao-estudos-ios.json"), options: .atomic)
    }

    func testVersionedCommonCases() throws {
        struct Cases: Decodable {
            struct Search: Decodable { let id: String; let query: String; let text: String; let matches: Bool }
            struct Notes: Decodable { let id: String; let text: String; let ids: [String]; let expected: String }
            struct Study: Decodable { let id: String; let text: String; let keywords: [String]; let matches: Bool }
            struct Citation: Decodable { let id: String; let text: String; let sources: Int; let valid: Bool }
            let schemaVersion: Int
            let search: [Search]
            let superscript: [Notes]
            let study: [Study]
            let citations: [Citation]
        }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_comuns_v1", withExtension: "json"))
        let cases = try JSONDecoder().decode(Cases.self, from: Data(contentsOf: url))
        XCTAssertEqual(cases.schemaVersion, 1)
        for item in cases.search {
            XCTAssertEqual(BibliotecaSQLiteService.corresponde(termo: item.query, texto: item.text), item.matches, item.id)
        }
        for item in cases.superscript {
            XCTAssertEqual(HomeView.converterChamadasRodapeParaSobrescrito(item.text, chamadasRodape: Set(item.ids)), item.expected, item.id)
        }
        for item in cases.study {
            XCTAssertEqual(RegrasEstudo.corresponde(texto: item.text, palavras: item.keywords), item.matches, item.id)
        }
        for item in cases.citations {
            if item.valid { XCTAssertNoThrow(try GeminiAnaliseService.validarCitacoes(item.text, quantidadeFontes: item.sources)) }
            else { XCTAssertThrowsError(try GeminiAnaliseService.validarCitacoes(item.text, quantidadeFontes: item.sources)) }
        }
    }

    func testGeminiRejectsIncompleteAndKeepsAllPublicParts() throws {
        let complete = Data(#"{"candidates":[{"finishReason":"STOP","content":{"parts":[{"text":"Interno","thought":true},{"text":"Primeira parte [F1]."},{"text":"Segunda parte [F2]."}]}}]}"#.utf8)
        XCTAssertEqual(try GeminiAnaliseService.extrairRespostaCompleta(complete), "Primeira parte [F1].\nSegunda parte [F2].")
        for reason in ["MAX_TOKENS", "SAFETY", "RECITATION", "OTHER"] {
            let data = Data("{\"candidates\":[{\"finishReason\":\"\(reason)\",\"content\":{\"parts\":[{\"text\":\"Parcial\"}]}}]}".utf8)
            XCTAssertThrowsError(try GeminiAnaliseService.extrairRespostaCompleta(data))
        }
    }

    func testStudySelectionSeparatesWorksSharingDates() {
        let a = BreviarioItem(id: 1, data: "01/06", titulo: "A", frase: "", texto: "ética", pagina: 1, obraID: "a")
        let b = BreviarioItem(id: 1, data: "01/06", titulo: "B", frase: "", texto: "história", pagina: 1, obraID: "b")
        let texts = [a.chavePersistencia: a.texto, b.chavePersistencia: b.texto]
        XCTAssertEqual(RegrasEstudo.selecionar([b, a], palavras: ["ética"], textos: texts, limite: 24).map(\.obraID), ["a"])
        XCTAssertEqual(RegrasEstudo.selecionar([b, a], palavras: ["ética", "história"], textos: texts, limite: 1).map(\.obraID), ["a"])
        let first = BreviarioItem(id: 1, data: "01/06", titulo: "Ética", frase: "", texto: "ética", pagina: nil, obraID: "zero")
        let second = BreviarioItem(id: 2, data: "02/06", titulo: "Ética", frase: "", texto: "ética", pagina: 0, obraID: "zero")
        let sameWorkTexts = Dictionary(uniqueKeysWithValues: [first, second].map { ($0.chavePersistencia, $0.texto) })
        XCTAssertEqual(RegrasEstudo.selecionar([second, first], palavras: ["ética"], textos: sameWorkTexts, limite: 1).first?.data, "01/06")
    }

    func testCatalogRestrictsWorkInsideMultiWorkPackage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try BibliotecaSQLiteService(url: root.appendingPathComponent("RAGPackages/test.sqlite"))
        for id in ["scope_a", "scope_b"] {
            let work = BibliotecaRAGObra(id: id, area: .bibliotecaMaconica, tipo: .livro, titulo: id, autor: nil, origem: nil, edicao: nil, assuntos: [], dataImportacao: Date())
            let paragraphs = (1...(id == "scope_a" ? 137 : 1)).map { BibliotecaRAGParagrafo(obraID: id, pagina: 1, ordem: $0, texto: "Simbolismo documental", capitulo: nil, secao: nil, temas: [], palavrasChave: []) }
            let page = BibliotecaRAGPagina(obraID: id, numeroOriginal: 1, titulo: "Teste", textoIntegral: paragraphs.map(\.texto).joined(separator: "\n"), largura: 595, altura: 842)
            let note = BibliotecaRAGNotaRodape(obraID: id, pagina: 1, numero: "578", texto: "Nota da obra \(id)")
            try db.substituirObra(obra: work, paginas: [page], paragrafos: paragraphs, notas: [note], imagens: [])
        }
        let works = ["scope_a", "scope_b"].map { BibliotecaRAGPacoteObra(id: $0, titulo: $0, autor: nil, tipo: .livro, paginas: 1, paragrafos: 1, notas: 0, assuntos: []) }
        let package = BibliotecaRAGPacote(area: .bibliotecaMaconica, titulo: "Multiobra", arquivo: "test.sqlite", url: nil, sha256: nil, nivel: nil, tamanhoBytes: 1, estatisticas: .init(obras: 2, paginas: 2, paragrafos: 2, notas: 0, imagens: 0, blocosFTS: 2), obras: works)
        let catalog = BibliotecaRAGCatalogo(versaoFormato: 1, estrategia: "teste", geradoEm: "teste", origem: nil, baseURL: nil, pacotes: [package], totais: .init(pacotes: 1, obras: 2, paginas: 2, paragrafos: 2, notas: 0, blocosFTS: 2, tamanhoBytes: 1))
        let url = root.appendingPathComponent("catalog.json")
        try JSONEncoder().encode(catalog).write(to: url)
        let service = try BibliotecaRAGCatalogService(catalogoURL: url)
        let hits = try service.buscar(termo: "simbolismo", escopo: .obraAtual, area: nil, obraID: "scope_a", limite: 200)
        XCTAssertEqual(hits.count, 137)
        XCTAssertTrue(hits.allSatisfy { $0.item.rodape == "578 Nota da obra scope_a" })
        XCTAssertEqual(hits.first?.obra.id, "scope_a")
        XCTAssertEqual(hits.first?.item.id, try db.carregarItensBiblioteca(obraID: "scope_a").first?.id)
        let all = try service.buscar(termo: "simbolismo", escopo: .appTodo, area: nil, obraID: nil, limite: 200)
        XCTAssertEqual(all.count, 138)
        let paged = try stride(from: 0, to: 150, by: 50).flatMap {
            try service.buscar(termo: "simbolismo", escopo: .appTodo, area: nil, obraID: nil, limite: 50, offset: $0)
        }
        XCTAssertEqual(paged.map(\.id), all.map(\.id))
        XCTAssertEqual(Set(paged.map(\.id)).count, 138)
        XCTAssertEqual(try service.buscar(termo: "simbolismo", escopo: .appTodo, area: nil, obraID: nil, limite: 1, obrasExcluidas: ["scope_a"]).first?.obra.id, "scope_b")
        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open(root.appendingPathComponent("RAGPackages/test.sqlite").path, &raw), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(raw, "DROP TABLE rag_fts", nil, nil, nil), SQLITE_OK)
        sqlite3_close(raw)
        XCTAssertThrowsError(try service.buscar(termo: "simbolismo", escopo: .appTodo, area: nil, obraID: nil))
    }

    /// Searching matches the reading itself, not the work's title, author or subjects, and local
    /// readings carry the same bm25 relevance as downloaded packages.
    @MainActor
    func testLibrarySearchMatchesReadingTextNotWorkMetadata() async throws {
        let store = BreviarioStore()
        // 21 since the reading of 02/04 ("Stolkin") came from the printed page: its notes cite "sua filosofia".
        for (termo, esperado) in [("filosofia", 21), ("ética", 4)] {
            let resultados = try await store.buscarBiblioteca(termo: termo, escopo: .obraAtual, area: nil,
                                                                limite: 500, obraID: ObraID.breviarioSeculoXXI)
            XCTAssertEqual(resultados.count, esperado, termo)
            XCTAssertTrue(resultados.allSatisfy { $0.ranking < 0 }, termo)
            XCTAssertEqual(resultados.map(\.ranking), resultados.map(\.ranking).sorted(), termo)
        }
    }

    func testLocalTextsUseTheSameFTSQueryAsPackages() throws {
        let textos = [(chave: "a", texto: "A Escada de Jacó e a escada."), (chave: "b", texto: "Leitura e lei."), (chave: "c", texto: "Escada simples")]
        let frase = try BibliotecaSQLiteService.pontuarTextosLocais(termo: "\"escada de jaco\"", textos: textos)
        XCTAssertEqual(Set(frase.keys), ["a"])
        XCTAssertEqual(Set(try BibliotecaSQLiteService.pontuarTextosLocais(termo: "escada", textos: textos).keys), ["a", "c"])
        // bm25 also weighs text length, so frequency is compared on texts of equal length.
        let mesmoTamanho = [(chave: "duas", texto: "escada escada neutro"), (chave: "uma", texto: "escada neutro neutro")]
        let frequencia = try BibliotecaSQLiteService.pontuarTextosLocais(termo: "escada", textos: mesmoTamanho)
        XCTAssertLessThan(try XCTUnwrap(frequencia["duas"]), try XCTUnwrap(frequencia["uma"]), "More occurrences rank first")
        XCTAssertTrue(try BibliotecaSQLiteService.pontuarTextosLocais(termo: "lei", textos: textos).keys.elementsEqual(["b"]))
    }

    /// The remissive index keeps the reading dates recorded in each breviary, as Android does.
    func testIntegratedBreviaryIndexKeepsRecordedDates() throws {
        for obra in BibliotecaObra.padroes where obra.recursoJSON != nil {
            let url = try XCTUnwrap(Bundle.main.url(forResource: obra.recursoJSON, withExtension: "json"))
            let gravado = try JSONDecoder().decode(BreviarioData.self, from: Data(contentsOf: url))
            let carregado = try BreviarioStore.carregarDadosDaObra(obra)
            let porID = Dictionary(uniqueKeysWithValues: carregado.indiceRemissivo.map { ($0.id, $0.datas) })
            for entrada in gravado.indiceRemissivo {
                XCTAssertEqual(porID[entrada.id], entrada.datas, "\(obra.id): \(entrada.termo)")
            }
        }
        let rizzardo = try BreviarioStore.carregarDadosDaObra(.breviarioRizzardo)
        XCTAssertEqual(rizzardo.indiceRemissivo.first { $0.termo == "TOLERANCIA" }?.datas, ["07/07"])
    }

    /// Success is not shown as an error, progress stays until replaced, errors stay longer.
    func testAppMessagesHaveTheirKindAndTime() {
        XCTAssertEqual(AvisoApp.tipo("Comentário salvo."), .sucesso)
        XCTAssertEqual(AvisoApp.tipo("Dossiê \"virtude\" excluído."), .sucesso)
        XCTAssertEqual(AvisoApp.tipo("Este dossiê salvo foi excluído."), .alerta)
        XCTAssertEqual(AvisoApp.tipo("Informe um tema para montar o dossiê."), .alerta)
        XCTAssertEqual(AvisoApp.tipo("Não foi possível concluir o dossiê."), .erro)
        XCTAssertEqual(AvisoApp.tipo("Gerando interpretação assistida..."), .progresso)
        XCTAssertNil(AvisoApp.duracao("Gerando PDF avançado do dossiê..."))
        XCTAssertEqual(AvisoApp.duracao("Comentário salvo."), 4)
        XCTAssertGreaterThanOrEqual(AvisoApp.duracao("Não foi possível gerar o PDF.") ?? 0, 8)
        XCTAssertGreaterThan(AvisoApp.duracao(String(repeating: "palavra ", count: 20) + "salva.") ?? 0, 4)
    }

    /// The AI prompt, the answer filter and the displayed text match Tools/ia_referencia.py exactly.
    /// Same codes, derivations and encrypted bytes as `Tools/conta_propria_referencia.mjs` and Android.
    func testOwnAccountMatchesReferenceCases() throws {
        let c = try XCTUnwrap(ContaPropriaCaderno.Configuracao.compartilhada)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_conta_propria_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        func bytes(_ hex: String) -> Data {
            Data(stride(from: 0, to: hex.count, by: 2).map { UInt8(hex.dropFirst($0).prefix(2), radix: 16)! })
        }
        func hex(_ dados: Data) -> String { dados.map { String(format: "%02x", $0) }.joined() }
        for caso in try XCTUnwrap(raiz["formatacao"] as? [[String: String]]) {
            XCTAssertEqual(ContaPropriaCaderno.formatar(bytes(caso["bytes"]!), c), caso["codigo"])
        }
        for caso in try XCTUnwrap(raiz["normalizacao"] as? [[String: Any]]) {
            XCTAssertEqual(ContaPropriaCaderno.normalizar(caso["entrada"] as? String ?? "", c), caso["esperado"] as? String,
                           "\(caso["entrada"] ?? "")")
        }
        for caso in try XCTUnwrap(raiz["derivacao"] as? [[String: String]]) {
            let derivacao = ContaPropriaCaderno.derivar(caso["codigo"]!, c)
            XCTAssertEqual(derivacao.conta, caso["conta"])
            XCTAssertEqual(derivacao.credencial, caso["credencial"])
            XCTAssertEqual(hex(derivacao.chave), caso["chave"])
        }
        for caso in try XCTUnwrap(raiz["cifragem"] as? [[String: String]]) {
            let chave = bytes(caso["chave"]!)
            let cifrado = try ContaPropriaCaderno.cifrar(Data(caso["texto"]!.utf8), chave: chave, nonce: bytes(caso["nonce"]!))
            XCTAssertEqual(hex(cifrado), caso["cifrado"], caso["nome"]!)
            XCTAssertEqual(String(decoding: try ContaPropriaCaderno.decifrar(bytes(caso["cifrado"]!), chave: chave), as: UTF8.self),
                           caso["texto"], caso["nome"]!)
        }
    }

    /// Real sync through the own-account server (local `wrangler dev`): the notebook is encrypted, sent and
    /// read back; an upload over a version already replaced by another device is refused.
    /// Opt-in: TEST_RUNNER_CONTA_PROPRIA_SERVIDOR=http://127.0.0.1:8787 xcodebuild test ...
    @MainActor
    func testOwnAccountSyncThroughServer() async throws {
        guard let servidor = ProcessInfo.processInfo.environment["CONTA_PROPRIA_SERVIDOR"] else {
            throw XCTSkip("Set TEST_RUNNER_CONTA_PROPRIA_SERVIDOR to the local server (wrangler dev)")
        }
        let c = try XCTUnwrap(ContaPropriaCaderno.Configuracao.compartilhada)
        let caderno = try XCTUnwrap(CadernoEstudo.Configuracao.compartilhada)
        let derivacao = ContaPropriaCaderno.derivar(try XCTUnwrap(ContaPropriaCaderno.normalizar(ContaPropriaCaderno.novoCodigo(c), c)), c)
        let aparelho = ProvedorContaPropria(servidor: servidor, derivacao: derivacao, configuracao: c)
        let mesclado = try await CadernoSincronizacao.sincronizar(com: aparelho, configuracao: caderno)
        defer { UserDefaults.standard.removeObject(forKey: "sincronizacaoCadernoEm") }

        let outro = ProvedorContaPropria(servidor: servidor, derivacao: derivacao, configuracao: c)
        let leitura = try await outro.ler()
        let lido = try XCTUnwrap(leitura)
        XCTAssertEqual(CadernoEstudo.decodificar(lido, configuracao: caderno), mesclado)

        // Both devices read the same version; the first upload wins and the second one is refused.
        let terceiro = ProvedorContaPropria(servidor: servidor, derivacao: derivacao, configuracao: c)
        _ = try await terceiro.ler()
        try await outro.gravar(lido)
        do {
            try await terceiro.gravar(lido)
            XCTFail("An upload over a replaced version must be refused")
        } catch {
            XCTAssertEqual(error.localizedDescription, c.rotulo("conflito"))
        }
    }

    /// iPhone and Android with the same sync code exchange notes through the own-account server. Opt-in:
    /// TEST_RUNNER_CONTA_PROPRIA_SERVIDOR, TEST_RUNNER_CONTA_PROPRIA_CODIGO and, on the run after the
    /// Android one, TEST_RUNNER_CONTA_PROPRIA_ESPERAR_ANDROID=1.
    @MainActor
    func testOwnAccountCrossPlatformExchange() async throws {
        let ambiente = ProcessInfo.processInfo.environment
        guard let servidor = ambiente["CONTA_PROPRIA_SERVIDOR"], let codigo = ambiente["CONTA_PROPRIA_CODIGO"] else {
            throw XCTSkip("Set TEST_RUNNER_CONTA_PROPRIA_SERVIDOR and TEST_RUNNER_CONTA_PROPRIA_CODIGO")
        }
        let c = try XCTUnwrap(ContaPropriaCaderno.Configuracao.compartilhada)
        let caderno = try XCTUnwrap(CadernoEstudo.Configuracao.compartilhada)
        let provedor = ProvedorContaPropria(servidor: servidor, derivacao: ContaPropriaCaderno.derivar(try XCTUnwrap(
            ContaPropriaCaderno.normalizar(codigo, c)), c), configuracao: c)
        CommentsService.salvar(comentario: "Anotação feita no iPhone.", para: "01/01", obraID: "teste_cruzado_ios")
        let mesclado = try await CadernoSincronizacao.sincronizar(com: provedor, configuracao: caderno)
        if ambiente["CONTA_PROPRIA_ESPERAR_ANDROID"] == "1" {
            XCTAssertEqual(mesclado.leituras.first { $0.obraId == "teste_cruzado_android" }?.comentario, "Anotação feita no Android.")
            XCTAssertEqual(CommentsService.carregar(data: "01/01", obraID: "teste_cruzado_android"), "Anotação feita no Android.")
            for chave in UserDefaults.standard.dictionaryRepresentation().keys where chave.contains("teste_cruzado") {
                UserDefaults.standard.removeObject(forKey: chave)
            }
        }
    }

    /// Same merges and file checks as `Tools/caderno_referencia.py` and Android (`casos_caderno_v1.json`).
    func testStudyNotebookMatchesReferenceCases() throws {
        let configuracao = try XCTUnwrap(CadernoEstudo.Configuracao.compartilhada)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_caderno_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        func caderno(_ valor: Any?) throws -> CadernoEstudo.Caderno {
            try JSONDecoder().decode(CadernoEstudo.Caderno.self, from: JSONSerialization.data(withJSONObject: try XCTUnwrap(valor)))
        }
        for caso in try XCTUnwrap(raiz["mesclagens"] as? [[String: Any]]) {
            let resultado = CadernoEstudo.mesclar(local: try caderno(caso["local"]), importado: try caderno(caso["importado"]),
                                                  hoje: try XCTUnwrap(caso["hoje"] as? String), configuracao: configuracao)
            XCTAssertEqual(resultado, try caderno(caso["esperado"]), "\(caso["nome"] ?? "")")
        }
        for caso in try XCTUnwrap(raiz["validacao"] as? [[String: Any]]) {
            let arquivo = try XCTUnwrap(caso["caderno"] as? [String: Any])
            XCTAssertEqual(CadernoEstudo.valido(formato: arquivo["formato"] as? String, versao: arquivo["versao"] as? Int,
                                                configuracao: configuracao), caso["valido"] as? Bool, "\(caso["nome"] ?? "")")
        }
    }

    func testStudyNotebookByThemeMatchesReferenceCases() throws {
        let configuracao = try XCTUnwrap(CadernoEstudo.Configuracao.compartilhada)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_caderno_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let porTema = try XCTUnwrap(raiz["porTema"] as? [String: Any])
        func decodificar<T: Decodable>(_ tipo: T.Type, _ valor: Any?) throws -> T {
            try JSONDecoder().decode(tipo, from: JSONSerialization.data(withJSONObject: try XCTUnwrap(valor), options: .fragmentsAllowed))
        }
        let caderno = try decodificar(CadernoEstudo.Caderno.self, porTema["caderno"])
        let titulos = try decodificar([String: String].self, porTema["titulos"])
        let anotacoes = CadernoEstudo.anotacoes(caderno, titulos: titulos, configuracao: configuracao)
        XCTAssertEqual(CadernoEstudo.temas(caderno, anotacoes: anotacoes), try decodificar([CadernoEstudo.Tema].self, porTema["temas"]))
        for busca in try XCTUnwrap(porTema["buscas"] as? [[String: Any]]) {
            let consulta = try XCTUnwrap(busca["consulta"] as? String)
            let encontradas = CadernoEstudo.buscar(anotacoes, consulta: consulta)
            XCTAssertEqual(encontradas, try decodificar([CadernoEstudo.Anotacao].self, busca["encontradas"]), consulta)
            XCTAssertEqual(CadernoEstudo.exportar(encontradas, consulta: consulta, configuracao: configuracao),
                           busca["exportacao"] as? String, consulta)
        }
    }

    /// The file written by each app opens in the other: this app writes the reference notebook to
    /// Documents/caderno-ios.json and reads Documents/caderno-android.json when it was copied there.
    func testStudyNotebookFilesCrossPlatform() throws {
        let configuracao = try XCTUnwrap(CadernoEstudo.Configuracao.compartilhada)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_caderno_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let caso = try XCTUnwrap((raiz["mesclagens"] as? [[String: Any]])?[1])
        let esperado = try JSONDecoder().decode(CadernoEstudo.Caderno.self,
                                                from: JSONSerialization.data(withJSONObject: try XCTUnwrap(caso["esperado"])))
        let documentos = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try CadernoEstudo.codificar(esperado).write(to: documentos.appendingPathComponent("caderno-ios.json"), options: .atomic)
        let doAndroid = documentos.appendingPathComponent("caderno-android.json")
        guard FileManager.default.fileExists(atPath: doAndroid.path) else {
            throw XCTSkip("Copy the file written by the Android test to Documents/caderno-android.json to check it here.")
        }
        XCTAssertEqual(CadernoEstudo.decodificar(try Data(contentsOf: doAndroid), configuracao: configuracao), esperado)
    }

    /// Sync through a service: the merged notebook is applied here and written back; a remote file
    /// from a newer version of the app is never overwritten.
    @MainActor
    func testStudyNotebookSyncMergesAndProtectsUnreadableRemote() async throws {
        final class Memoria: ProvedorCaderno, @unchecked Sendable {
            let opcao = CadernoSincronizacao.Opcao.contaPropria
            var dados: Data?
            var gravacoes = 0
            init(_ dados: Data?) { self.dados = dados }
            func ler() async throws -> Data? { dados }
            func gravar(_ novos: Data) async throws { dados = novos; gravacoes += 1 }
        }
        let configuracao = try XCTUnwrap(CadernoEstudo.Configuracao.compartilhada)
        let obra = "teste_caderno_sincronizacao"
        defer {
            for chave in UserDefaults.standard.dictionaryRepresentation().keys where chave.contains(obra) {
                UserDefaults.standard.removeObject(forKey: chave)
            }
            UserDefaults.standard.removeObject(forKey: "sincronizacaoCadernoEm")
        }
        var outroAparelho = CadernoEstudo.vazio(configuracao)
        var leitura = CadernoEstudo.Leitura(obraId: obra, data: "05/07")
        leitura.comentario = "Anotação feita no outro aparelho."
        outroAparelho.leituras = [leitura]
        let nuvem = Memoria(try CadernoEstudo.codificar(outroAparelho))

        let mesclado = try await CadernoSincronizacao.sincronizar(com: nuvem, configuracao: configuracao)
        XCTAssertEqual(CommentsService.carregar(data: "05/07", obraID: obra), "Anotação feita no outro aparelho.")
        XCTAssertEqual(CadernoEstudo.decodificar(try XCTUnwrap(nuvem.dados), configuracao: configuracao), mesclado)
        let depois = nuvem.gravacoes
        _ = try await CadernoSincronizacao.sincronizar(com: nuvem, configuracao: configuracao)
        XCTAssertEqual(nuvem.gravacoes, depois, "Nothing changed, nothing is written")

        let futuro = Data(#"{"formato":"caderno-biblioteca-maconica","versao":99}"#.utf8)
        let nuvemFutura = Memoria(futuro)
        do {
            _ = try await CadernoSincronizacao.sincronizar(com: nuvemFutura, configuracao: configuracao)
            XCTFail("A notebook from a newer version must not be merged")
        } catch {
            XCTAssertEqual(nuvemFutura.dados, futuro)
            XCTAssertEqual(nuvemFutura.gravacoes, 0)
        }
    }

    /// A notebook written to this device and collected again keeps the reading, its highlight and edit.
    func testStudyNotebookRoundTripOnThisDevice() throws {
        let configuracao = try XCTUnwrap(CadernoEstudo.Configuracao.compartilhada)
        let obra = "teste_caderno_ida_e_volta"
        defer {
            for chave in UserDefaults.standard.dictionaryRepresentation().keys where chave.contains(obra) {
                UserDefaults.standard.removeObject(forKey: chave)
            }
        }
        var leitura = CadernoEstudo.Leitura(obraId: obra, data: "03/07")
        leitura.comentario = "Comentário importado."
        leitura.reflexao = "Reflexão importada."
        leitura.favorita = true
        leitura.lida = true
        leitura.destaques = [CadernoEstudo.Destaque(id: UUID().uuidString, texto: "trecho marcado", criadoEm: 1_790_000_000_000)]
        leitura.edicao = CadernoEstudo.Edicao(titulo: "Título", frase: "", texto: "Texto", rodape: "Nota", autor: "")
        var importado = CadernoEstudo.vazio(configuracao)
        importado.leituras = [leitura]
        let local = CadernoEstudo.coletar(configuracao: configuracao)
        CadernoEstudo.aplicar(CadernoEstudo.mesclar(local: local, importado: importado, hoje: "2026-10-10", configuracao: configuracao))
        let coletada = CadernoEstudo.coletar(configuracao: configuracao).leituras.first { $0.obraId == obra }
        XCTAssertEqual(coletada, leitura)
        let dados = try CadernoEstudo.codificar(CadernoEstudo.coletar(configuracao: configuracao))
        XCTAssertNotNil(CadernoEstudo.decodificar(dados, configuracao: configuracao))
    }

    /// Same cards, schedule and sessions as `Tools/revisao_referencia.py` and Android (`casos_revisao_v1.json`).
    func testActiveReviewMatchesReferenceCases() throws {
        let configuracao = try XCTUnwrap(RevisaoAtiva.Configuracao.compartilhada)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_revisao_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        func decodificar<T: Decodable>(_ tipo: T.Type, _ valor: Any?) throws -> T {
            try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: try XCTUnwrap(valor)))
        }
        for caso in try XCTUnwrap(raiz["geracao"] as? [[String: Any]]) {
            let analise = try XCTUnwrap(caso["analise"] as? [String: Any])
            let fontes = try XCTUnwrap(caso["fontes"] as? [[String: Any]]).map {
                DossieEstudoAnalise.Fonte(id: $0["id"] as? String ?? "", obraId: "", tituloObra: $0["tituloObra"] as? String ?? "",
                                          area: "", pagina: $0["pagina"] as? Int ?? 0, data: $0["data"] as? String)
            }
            let formas = try XCTUnwrap(analise["termosAssociados"] as? [[String: Any]]).compactMap { $0["forma"] as? String }
            let cartoes = RevisaoAtiva.gerar(termo: try XCTUnwrap(caso["tema"] as? String),
                                             definicoes: try decodificar([DossieEstudoAnalise.Trecho].self, analise["definicoes"]),
                                             perguntas: try decodificar([DossieEstudoAnalise.Pergunta].self, analise["perguntas"]),
                                             formas: formas, fontes: fontes, configuracao: configuracao)
            XCTAssertEqual(cartoes, try decodificar([RevisaoAtiva.Cartao].self, caso["esperado"]), "\(caso["id"] ?? "")")
        }
        for caso in try XCTUnwrap(raiz["agenda"] as? [[String: Any]]) {
            var estado = RevisaoAtiva.novoEstado(hoje: try XCTUnwrap(caso["criadoEm"] as? String))
            var estados: [RevisaoAtiva.Estado] = []
            for resposta in try XCTUnwrap(caso["respostas"] as? [[String]]) {
                estado = RevisaoAtiva.responder(estado, nota: try XCTUnwrap(RevisaoAtiva.Nota(rawValue: resposta[0])),
                                                hoje: resposta[1], configuracao: configuracao)
                estados.append(estado)
            }
            XCTAssertEqual(estados, try decodificar([RevisaoAtiva.Estado].self, caso["esperado"]), "\(caso["nome"] ?? "")")
        }
        for caso in try XCTUnwrap(raiz["sessoes"] as? [[String: Any]]) {
            let cartoes = try XCTUnwrap(caso["cartoes"] as? [[String: String]]).map {
                (id: $0["id"] ?? "", criadoEm: $0["criadoEm"] ?? "", vencimento: $0["vencimento"] ?? "")
            }
            XCTAssertEqual(RevisaoAtiva.sessao(cartoes, hoje: try XCTUnwrap(caso["hoje"] as? String), configuracao: configuracao),
                           caso["esperado"] as? [String], "\(caso["nome"] ?? "")")
        }
    }

    /// Same results as `Tools/qualidade_referencia.py` and Android for every case of `casos_qualidade_v1.json`.
    func testTextQualityMatchesReferenceCases() throws {
        let configuracao = try XCTUnwrap(QualidadeTexto.Configuracao.compartilhada)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_qualidade_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        for caso in try XCTUnwrap(raiz["casos"] as? [[String: Any]]) {
            let nome = caso["nome"] as? String ?? ""
            let esperado = try XCTUnwrap(caso["esperado"] as? [String: Any])
            switch caso["tipo"] as? String {
            case "token":
                XCTAssertEqual(QualidadeTexto.classificar(caso["texto"] as? String ?? "", configuracao: configuracao),
                               esperado["classe"] as? String, nome)
            case "obra":
                XCTAssertEqual(QualidadeTexto.nivelObra(avaliadas: caso["avaliadas"] as? Int ?? -1, ruidosas: caso["ruidosas"] as? Int ?? -1,
                                                        ilegiveis: caso["ilegiveis"] as? Int ?? -1, configuracao: configuracao),
                               esperado["nivel"] as? String, nome)
            default:
                let texto = caso["texto"] as? String ?? ""
                let avaliacao = caso["tipo"] as? String == "pagina"
                    ? QualidadeTexto.avaliarPagina(texto, configuracao: configuracao)
                    : QualidadeTexto.avaliarFrase(texto, configuracao: configuracao)
                XCTAssertEqual(avaliacao.palavras, esperado["palavras"] as? Int, nome)
                XCTAssertEqual(avaliacao.suspeitas, esperado["suspeitas"] as? Int, nome)
                XCTAssertEqual(avaliacao.nivel.rawValue, esperado["nivel"] as? String, nome)
                XCTAssertEqual(avaliacao.motivos, esperado["motivos"] as? [String: Int], nome)
            }
        }
    }

    func testAssistedInterpretationMatchesReferenceCases() throws {
        let configuracao = try XCTUnwrap(InterpretacaoAssistida.Configuracao.compartilhada)
        let estudo = try XCTUnwrap(DossieEstudoAnalise.Configuracao.compartilhada)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_ia_v1", withExtension: "json"))
        let casos = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        func fontes(_ lista: Any?) throws -> [DossieEstudoAnalise.Fonte] {
            let dados = try JSONSerialization.data(withJSONObject: try XCTUnwrap(lista))
            return try JSONDecoder().decode([DossieEstudoAnalise.Fonte].self, from: dados)
        }
        for caso in try XCTUnwrap(casos["prompts"] as? [[String: Any]]) {
            let oficiais = (caso["fontesOficiais"] as? [[String: String]] ?? []).map {
                InterpretacaoAssistida.FonteOficial(titulo: $0["titulo"] ?? "", origem: $0["origem"] ?? "", url: $0["url"] ?? "", observacao: $0["observacao"] ?? "")
            }
            let prompt = InterpretacaoAssistida.prompt(termo: try XCTUnwrap(caso["termo"] as? String), fontes: try fontes(caso["fontes"]),
                                                       oficiais: oficiais, configuracao: configuracao, estudo: estudo)
            XCTAssertEqual(prompt, caso["esperado"] as? String, "\(caso["id"] ?? "")")
        }
        let conjuntos = try XCTUnwrap(casos["fontes"] as? [String: Any])
        for caso in try XCTUnwrap(casos["respostas"] as? [[String: Any]]) {
            let lista = try fontes(conjuntos[try XCTUnwrap(caso["fontes"] as? String)])
            let esperado = try XCTUnwrap(caso["esperado"] as? [String: Any])
            let resultado = InterpretacaoAssistida.filtrar(resposta: try XCTUnwrap(caso["resposta"] as? String), fontes: lista, configuracao: configuracao)
            let id = "\(caso["id"] ?? "")"
            XCTAssertEqual(resultado.texto, esperado["texto"] as? String, id)
            XCTAssertEqual(resultado.frasesMantidas, esperado["frasesMantidas"] as? Int, id)
            XCTAssertEqual(resultado.frasesRemovidas, esperado["frasesRemovidas"] as? Int, id)
            XCTAssertEqual(resultado.fontesCitadas, esperado["fontesCitadas"] as? [Int], id)
            XCTAssertEqual(InterpretacaoAssistida.exibicao(resultado, fontes: lista, configuracao: configuracao, estudo: estudo),
                           esperado["exibicao"] as? String, id)
        }
    }

    /// Saved dossiers date their reviews from the day they were saved, with the same rule as Android.
    func testSavedDossierReviewsFollowSharedSchedule() throws {
        let configuracao = try XCTUnwrap(DossieEstudoAnalise.Configuracao.compartilhada)
        let passos = configuracao.revisao
        XCTAssertEqual(passos.map(\.dias), [0, 1, 3, 7, 21])
        let salvo = DossieSalvo(id: "t", tema: "Escada de Jacó", area: "bibliotecaMaconica", obraId: nil, autor: "", assunto: "",
                                criadoEm: "2026-09-20", revisoesConcluidas: [0])
        let hoje = try XCTUnwrap(DossieSalvo(id: "", tema: "", area: nil, obraId: nil, autor: "", assunto: "", criadoEm: "2026-09-23").dataCriacao)
        let revisoes = salvo.revisoes(passos: passos, hoje: hoje)
        XCTAssertEqual(revisoes.map { DossieSalvo.data($0.data) }, ["2026-09-20", "2026-09-21", "2026-09-23", "2026-09-27", "2026-10-11"])
        XCTAssertEqual(revisoes.map(\.situacao), [.feita, .atrasada, .hoje, .proxima, .proxima])
        XCTAssertEqual(salvo.proximaRevisao(passos: passos, hoje: hoje)?.dias, 1)
        XCTAssertEqual(salvo.alternando(1).proximaRevisao(passos: passos, hoje: hoje)?.dias, 3)
        XCTAssertEqual(salvo.alternando(1).alternando(1).revisoesConcluidas, [0])
        XCTAssertEqual(salvo.chave, DossieSalvo.chave(tema: "  escada de JACÓ ", area: "bibliotecaMaconica", obraId: nil, autor: "", assunto: ""))
        XCTAssertEqual(configuracao.lembreteRevisao.hora, 9)
        XCTAssertEqual(configuracao.lembreteRevisao.minuto, 0)

        let defaults = try XCTUnwrap(UserDefaults(suiteName: "teste-dossies-\(UUID().uuidString)"))
        let store = DossiesSalvosStore(defaults: defaults)
        store.salvar(salvo)
        var copia = salvo.alternando(1)
        copia = DossieSalvo(id: "u", tema: copia.tema, area: copia.area, obraId: nil, autor: "", assunto: "",
                            criadoEm: copia.criadoEm, revisoesConcluidas: copia.revisoesConcluidas)
        store.salvar(copia)
        XCTAssertEqual(store.todos().filter { $0.chave == salvo.chave }.map(\.id), ["u"], "Same study is replaced, not duplicated")
        XCTAssertEqual(store.buscar(id: "u")?.revisoesConcluidas, [0, 1])
        store.remover(id: "u")
        XCTAssertNil(store.buscar(chave: salvo.chave))
    }

    /// Pending reviews of a saved dossier become notifications that open it, as on Android.
    @MainActor
    func testSavedDossierRemindersOpenTheDossier() throws {
        let configuracao = try XCTUnwrap(DossieEstudoAnalise.Configuracao.compartilhada)
        let hoje = DossieSalvo.calendario.startOfDay(for: Date())
        let agora = try XCTUnwrap(DossieSalvo.calendario.date(byAdding: .hour, value: 12, to: hoje))
        let salvo = DossieSalvo(id: "abc", tema: "Lembrete de teste", area: nil, obraId: nil, autor: "", assunto: "",
                                criadoEm: DossieSalvo.data(hoje), revisoesConcluidas: [0, 3])
        let requests = NotificationService.requisicoesRevisao(salvo, configuracao: configuracao, agora: agora)
        XCTAssertEqual(requests.map(\.identifier), ["breviario.dossie.abc.1", "breviario.dossie.abc.7", "breviario.dossie.abc.21"],
                       "Completed reviews are never scheduled")
        let primeira = try XCTUnwrap(requests.first)
        XCTAssertEqual(primeira.content.title, "Revisão do dossiê: Lembrete de teste")
        XCTAssertEqual(primeira.content.body, configuracao.revisao[1].tarefa)
        XCTAssertEqual(primeira.content.userInfo["url"] as? String, "breviario://dossie?id=abc")
        let gatilho = try XCTUnwrap(primeira.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(gatilho.dateComponents.hour, configuracao.lembreteRevisao.hora)
        XCTAssertEqual(gatilho.dateComponents.minute, configuracao.lembreteRevisao.minuto)
        XCTAssertEqual(DossieSalvo.calendario.date(from: gatilho.dateComponents).map { DossieSalvo.calendario.startOfDay(for: $0) },
                       DossieSalvo.calendario.date(byAdding: .day, value: 1, to: hoje))
        // Tapping the notification hands its link to the router the dossier screen observes.
        let router = NotificationReadingRouter()
        let url = try XCTUnwrap(URL(string: try XCTUnwrap(primeira.content.userInfo["url"] as? String)))
        router.receive(url)
        XCTAssertEqual(router.pendingURL, url)
        router.receive(URL(string: "outro://dossie?id=abc")!)
        XCTAssertEqual(router.pendingURL, url, "Only the app's own scheme is accepted")
        XCTAssertEqual(DossieSalvoTextos.progresso(salvo, passos: configuracao.revisao, hoje: agora),
                       "Próxima revisão em \(DossieSalvoTextos.data(try XCTUnwrap(DossieSalvo.calendario.date(byAdding: .day, value: 1, to: hoje)))): \(configuracao.revisao[1].tarefa)")
    }

    /// A package installed from an earlier catalog is offered as an update, as on Android.
    func testInstalledPackageFromEarlierCatalogIsOutdated() throws {
        let arquivo = "teste_versao_\(UUID().uuidString).sqlite"
        let works = [BibliotecaRAGPacoteObra(id: "versao", titulo: "versao", autor: nil, tipo: .livro, paginas: 1, paragrafos: 0, notas: 0, assuntos: [])]
        let package = BibliotecaRAGPacote(area: .bibliotecaMaconica, titulo: "Versão", arquivo: arquivo, url: nil, sha256: "ABC123", nivel: nil, tamanhoBytes: 1, estatisticas: .init(obras: 1, paginas: 1, paragrafos: 0, notas: 0, imagens: 0, blocosFTS: 0), obras: works)
        let catalog = BibliotecaRAGCatalogo(versaoFormato: 1, estrategia: "teste", geradoEm: "teste", origem: nil, baseURL: nil, pacotes: [package], totais: .init(pacotes: 1, obras: 1, paginas: 1, paragrafos: 0, notas: 0, blocosFTS: 0, tamanhoBytes: 1))
        let catalogURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try JSONEncoder().encode(catalog).write(to: catalogURL)
        let raiz = BibliotecaRAGCatalogService.raizPacotesLocal()
        try FileManager.default.createDirectory(at: raiz, withIntermediateDirectories: true)
        let local = raiz.appendingPathComponent(arquivo)
        let versao = raiz.appendingPathComponent(arquivo + ".sha256")
        defer {
            try? FileManager.default.removeItem(at: local)
            try? FileManager.default.removeItem(at: versao)
            try? FileManager.default.removeItem(at: catalogURL)
        }
        let servico = try BibliotecaOfflinePackageService(catalogo: BibliotecaRAGCatalogService(catalogoURL: catalogURL))

        XCTAssertFalse(try XCTUnwrap(servico.estados().first).desatualizado, "Not installed is not outdated")
        try Data("x".utf8).write(to: local)
        XCTAssertTrue(try XCTUnwrap(servico.estados().first).desatualizado, "No recorded version counts as outdated")
        try Data("0000".utf8).write(to: versao)
        XCTAssertTrue(servico.desatualizado(package))
        try Data("abc123\n".utf8).write(to: versao)
        XCTAssertFalse(try XCTUnwrap(servico.estados().first).desatualizado)
    }

    /// Words split by the import/OCR (Tools/corrigir_palavras_quebradas.py) stay joined, as on Android.
    func testBreviaryReadingsHaveNoWordsSplitByOCR() throws {
        let quebradas = ["difi cilmente", "signifi cando", "constran gimentos", "coraça- o", "na- o", "Maço naria", "exis tência", "tornando- se", "Grão- Mestre"]
        var textos: [String] = []
        for obra in BibliotecaObra.padroes where obra.recursoJSON != nil {
            for item in try BreviarioStore.carregarDadosDaObra(obra).itens {
                textos.append([item.titulo, item.frase, item.texto, item.rodape ?? ""].joined(separator: "\n"))
            }
        }
        for quebrada in quebradas {
            XCTAssertFalse(textos.contains { $0.contains(quebrada) }, quebrada)
        }
        let rizzardo = try BreviarioStore.carregarDadosDaObra(.breviarioRizzardo).itens
        XCTAssertTrue(try XCTUnwrap(rizzardo.first { $0.data == "25/02" }).texto.contains("pois dificilmente se pode"))
    }

    func testIndexWithoutRecordedDatesIsLinkedByPrintedPage() {
        let item = BreviarioItem(id: 1, data: "10/02", titulo: "T", frase: "", texto: "", rodape: "170 Nota da página", pagina: 41)
        let vinculado = BreviarioImportService.vincularIndice([IndiceRemissivoEntry(id: 1, termo: "Termo", paginas: [170], datas: [])], aos: [item])
        XCTAssertEqual(vinculado.first?.datas, ["10/02"])
    }

    /// The AI-free dossier must reproduce the golden cases of Tools/dossie_referencia.py exactly.
    /// Messages of the review cards on the watch, the same the Android Data Layer carries (relogio_revisao_v1.json).
    func testWatchReviewMessagesMatchSharedExamples() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "relogio_revisao_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let exemplos = try XCTUnwrap(raiz["exemplos"] as? [String: Any])
        let baralho = try JSONDecoder().decode(BaralhoRelogio.self,
                                               from: JSONSerialization.data(withJSONObject: try XCTUnwrap(exemplos["baralho"])))
        XCTAssertEqual(baralho.cartoes.map(\.verso), ["degrau", "Símbolo da imortalidade."])
        XCTAssertEqual(BaralhoRelogio.parse(baralho.message), baralho, "Sent and read back unchanged")
        XCTAssertEqual(baralho.rotulo("pendentes", ["n": "2"]), "2 cartão(ões) para hoje")
        for caso in try XCTUnwrap(exemplos["respostas"] as? [[String: Any]]) {
            let mensagem = try XCTUnwrap(caso["mensagem"] as? [String: Any])
            XCTAssertEqual(RespostaRelogio.parse(mensagem) != nil, caso["valida"] as? Bool, "\(mensagem)")
        }
        XCTAssertEqual(RevisaoRelogio.compartilhada?.limiteCartoes, raiz["limiteCartoes"] as? Int)
    }

    func testSearchVariantsMatchReferenceCases() throws {
        let configuracao = try XCTUnwrap(VariantesBusca.Configuracao.compartilhada)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_variantes_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        for caso in try XCTUnwrap(raiz["casos"] as? [[String: Any]]) {
            let palavras = try XCTUnwrap(caso["palavras"] as? [String])
            let plural = try XCTUnwrap(caso["singularPlural"] as? Bool)
            XCTAssertEqual(VariantesBusca.expandir(palavras, singularPlural: plural, configuracao),
                           try XCTUnwrap(caso["esperado"] as? [String: [String]]), "\(palavras) \(plural)")
        }
        // The dossier variants are generated from the same groups.
        XCTAssertEqual(DossieEstudoAnalise.Configuracao.compartilhada?.variantes, VariantesBusca.grafias(configuracao))
        XCTAssertEqual(VariantesBusca.paraBusca("Irmãos \"Escada de Jacó\"", singularPlural: true)["jaco"], ["jacob", "jacos"])
    }

    func testDegreeTracksMatchReferenceCases() throws {
        let configuracao = try XCTUnwrap(TrilhasGrau.Configuracao.compartilhada)
        XCTAssertEqual(configuracao.graus.map(\.id), ["aprendiz", "companheiro", "mestre"])
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_trilhas_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        for caso in try XCTUnwrap(raiz["casos"] as? [[String: Any]]) {
            let esperado = try JSONDecoder().decode([TrilhasGrau.Progresso].self,
                                                    from: JSONSerialization.data(withJSONObject: try XCTUnwrap(caso["esperado"])))
            let obtido = TrilhasGrau.progresso(configuracao, temasSalvos: try XCTUnwrap(caso["temasSalvos"] as? [String]),
                                               marcadas: Set(try XCTUnwrap(caso["marcadas"] as? [String])))
            XCTAssertEqual(obtido, esperado, caso["nome"] as? String ?? "")
        }
    }

    func testPranchaMatchesReferenceCases() throws {
        let configuracao = try XCTUnwrap(PranchaDossie.Configuracao.compartilhada)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_prancha_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        func decodificar<T: Decodable>(_ tipo: T.Type, _ valor: Any?) throws -> T {
            try JSONDecoder().decode(tipo, from: JSONSerialization.data(withJSONObject: try XCTUnwrap(valor)))
        }
        let obras = try decodificar([String: PranchaDossie.Obra].self, raiz["obras"])
        for caso in try XCTUnwrap(raiz["casos"] as? [[String: Any]]) {
            let dossie = try XCTUnwrap(caso["dossie"] as? [String: Any])
            let prancha = PranchaDossie.montar(
                termo: try XCTUnwrap(caso["termo"] as? String),
                fontes: try decodificar([DossieEstudoAnalise.Fonte].self, caso["fontes"]),
                definicoes: try decodificar([DossieEstudoAnalise.Trecho].self, dossie["definicoes"]),
                resumo: try decodificar([DossieEstudoAnalise.Trecho].self, dossie["resumo"]),
                divergencias: try decodificar([DossieEstudoAnalise.Trecho].self, dossie["divergencias"]),
                termosAssociados: try decodificar([DossieEstudoAnalise.TermoAssociado].self, dossie["termosAssociados"]),
                obras: obras, configuracao: configuracao)
            XCTAssertEqual(prancha, try decodificar(PranchaDossie.Prancha.self, caso["esperado"]), caso["id"] as? String ?? "")
        }
        for caso in try XCTUnwrap(raiz["referencias"] as? [[String: Any]]) {
            XCTAssertEqual(PranchaDossie.referencia(try decodificar(PranchaDossie.Obra.self, caso["obra"]), configuracao),
                           caso["referencia"] as? String)
        }
        // Every work of the collection has its bibliographic data.
        XCTAssertEqual(PranchaDossie.obrasCompartilhadas["breviario_seculo_xxi"]?.autor, "Kennyo Ismail")
    }

    func testDossierAnalysisMatchesReferenceCases() throws {
        let configuracao = try XCTUnwrap(DossieEstudoAnalise.Configuracao.compartilhada)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_dossie_v1", withExtension: "json"))
        let raiz = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let casos = try XCTUnwrap(raiz["casos"] as? [[String: Any]])
        XCTAssertFalse(casos.isEmpty)
        let titulos = try XCTUnwrap(raiz["titulos"] as? [[String: Any]])
        XCTAssertFalse(titulos.isEmpty)
        for caso in titulos {
            let separado = DossieEstudoAnalise.separarTitulo(DossieEstudoAnalise.limpar(try XCTUnwrap(caso["texto"] as? String)))
            XCTAssertEqual([separado.titulo, separado.corpo], caso["esperado"] as? [String], caso["id"] as? String ?? "")
        }
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "UTC")!
        for caso in casos {
            let id = try XCTUnwrap(caso["id"] as? String)
            let fontesJSON = try JSONSerialization.data(withJSONObject: try XCTUnwrap(caso["fontes"]))
            let fontes = try JSONDecoder().decode([DossieEstudoAnalise.Fonte].self, from: fontesJSON)
            let partes = try XCTUnwrap(caso["hoje"] as? String).split(separator: "-").compactMap { Int($0) }
            let hoje = try XCTUnwrap(calendario.date(from: DateComponents(year: partes[0], month: partes[1], day: partes[2])))
            let resultado = DossieEstudoAnalise.analisar(termo: try XCTUnwrap(caso["termo"] as? String), fontes: fontes,
                                                         configuracao: configuracao, hoje: hoje, calendario: calendario)
            let esperado = try XCTUnwrap(caso["esperado"] as? [String: Any])
            var obtido = resultado.json
            obtido["exibicao"] = DossieEstudoAnalise.exibicao(termo: try XCTUnwrap(caso["termo"] as? String), resultado: resultado,
                                                             fontes: fontes, configuracao: configuracao).json
            XCTAssertEqual(Set(obtido.keys), Set(esperado.keys), id)
            for (chave, valor) in esperado {
                XCTAssertEqual(NSObject.normalizarJSON(obtido[chave]), NSObject.normalizarJSON(valor), "\(id).\(chave)")
            }
        }
    }

    /// Collections built from the two integrated breviaries, compared with Android by rule id.
    func testLocalBreviaryCollectionsAreRecordedForParity() throws {
        var itens: [BreviarioItem] = []
        var termosPorChave: [String: String] = [:]
        for obra in BibliotecaObra.padroes where obra.recursoJSON != nil {
            let dados = try BreviarioStore.carregarDadosDaObra(obra)
            itens += dados.itens
            for entrada in dados.indiceRemissivo {
                for data in entrada.datas { termosPorChave["\(obra.id)_\(data)", default: ""] += " " + entrada.termo }
            }
        }
        let resultado = HomeView.montarConteudoPremiumCache(itens: itens, indice: [], termosPorChave: termosPorChave)
        var selecao: [String: [String]] = [:]
        for colecao in resultado.colecoes { selecao[colecao.id] = colecao.itens.map(\.chavePersistencia) }
        for trilha in resultado.trilhas { selecao[trilha.id] = trilha.itens.map(\.chavePersistencia) }
        XCTAssertEqual(selecao.count, RegrasEstudo.compartilhadas.colecoes.count + RegrasEstudo.compartilhadas.trilhas.count)
        XCTAssertTrue(selecao.values.allSatisfy { !$0.isEmpty })
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try JSONSerialization.data(withJSONObject: selecao, options: [.prettyPrinted, .sortedKeys])
            .write(to: documents.appendingPathComponent("estudos-locais-ios.json"), options: .atomic)
    }

    /// The index engine must rank pages exactly like the shared in-memory rule, notes and phrases included.
    func testIndexStudyScoringMatchesSharedRule() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("RAGPackages/estudo.sqlite")
        let db = try BibliotecaSQLiteService(url: url)
        let obra = BibliotecaRAGObra(id: "estudo", area: .bibliotecaMaconica, tipo: .livro, titulo: "Estudo", autor: nil, origem: nil, edicao: nil, assuntos: [], dataImportacao: Date())
        let blocos: [(Int, String)] = [
            (1, "A Escada de Jacó tem degraus: a escada de Jacó e a Grande Loja."),
            (2, "Leitura do espírito; nenhuma palavra inteira aqui."),
            (3, "Uma ética da virtude."),
            (3, "Segundo bloco da mesma página com virtude e ética."),
            (4, "Texto neutro."),
            (5, "Grande   loja, grande loja e lei.")
        ]
        let paragrafos = blocos.enumerated().map { indice, bloco in
            BibliotecaRAGParagrafo(obraID: "estudo", pagina: bloco.0, ordem: indice, texto: bloco.1, capitulo: nil, secao: nil, temas: [], palavrasChave: [])
        }
        let paginas = (1...5).map { numero in
            BibliotecaRAGPagina(obraID: "estudo", numeroOriginal: numero, titulo: nil,
                                textoIntegral: blocos.filter { $0.0 == numero }.map(\.1).joined(separator: "\n"), largura: 595, altura: 842)
        }
        let notas = [BibliotecaRAGNotaRodape(obraID: "estudo", pagina: 4, numero: "578", texto: "Nota sobre a Escada de Jacó e a lei.")]
        try db.substituirObra(obra: obra, paginas: paginas, paragrafos: paragrafos, notas: notas, imagens: [])

        let regrasTexto = [["escada de jaco", "degraus", "grande loja"], ["etica", "virtude"], ["lei", "rito", "grande loja"]]
        let regras = regrasTexto.map { RegrasEstudo.palavrasChave($0.map(RegrasEstudo.normalizar)) }
        let limites = [3, 3, 3]
        let indice = try BibliotecaEstudoIndice.pontuar(url: url, obras: ["estudo"], regras: regras, limites: limites)

        let itens = try db.carregarItensBiblioteca(obraID: "estudo")
        let textos = Dictionary(uniqueKeysWithValues: itens.map { ($0.chavePersistencia, [$0.titulo, $0.texto, $0.rodape ?? ""].joined(separator: " ")) })
        for (numero, palavras) in regrasTexto.enumerated() {
            let memoria = RegrasEstudo.selecionar(itens, palavras: palavras, textos: textos, limite: limites[numero])
            XCTAssertEqual(indice[numero].map(\.referencia.pagina), memoria.compactMap(\.pagina), "regra \(numero)")
        }
        XCTAssertEqual(indice[0].map(\.referencia.pagina), [1, 5, 4])
        XCTAssertEqual(indice[0].first?.temas, 3)
        XCTAssertEqual(indice[0].first?.ocorrencias, 4)
        XCTAssertEqual(indice[2].map(\.referencia.pagina), [5, 1, 4], "\"lei\" and \"rito\" must not match inside other words")
    }

    /// Phase 1 scores study themes straight from the FTS index; the platform SQLite must provide fts5vocab.
    func testSystemSQLiteSupportsIndexOnlyTermCounts() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(":memory:", &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        let setup = """
        CREATE VIRTUAL TABLE rag_fts USING fts5(bloco_id UNINDEXED, texto, tokenize = 'unicode61 remove_diacritics 2');
        INSERT INTO rag_fts VALUES ('a', 'A Escada de Jacó e a escada do templo.');
        INSERT INTO rag_fts VALUES ('b', 'Leitura sem o termo.');
        CREATE VIRTUAL TABLE temp.vocab USING fts5vocab(main, rag_fts, 'instance');
        """
        XCTAssertEqual(sqlite3_exec(db, setup, nil, nil, nil), SQLITE_OK, String(cString: sqlite3_errmsg(db)))
        var statement: OpaquePointer?
        let query = "SELECT doc, count(DISTINCT term), count(*) FROM temp.vocab WHERE term IN ('escada', 'jaco', 'lei') GROUP BY doc"
        XCTAssertEqual(sqlite3_prepare_v2(db, query, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        var rows: [[Int]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append((0..<3).map { Int(sqlite3_column_int64(statement, Int32($0))) })
        }
        // Whole words, accents folded: "lei" does not count inside "Leitura".
        XCTAssertEqual(rows, [[1, 2, 3]])
    }

    func testSharedStudySelectionIsIndependentOfBatchSizeAndOrder() throws {
        struct Fixture: Decodable {
            struct Item: Decodable { let work, date, title, body, notes, index: String; let page: Int }
            let keywords: [String]; let limit: Int; let expected: [String]; let items: [Item]
        }
        struct Root: Decodable { let studySelection: Fixture }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "casos_comuns_v1", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Root.self, from: Data(contentsOf: url)).studySelection
        let itens = fixture.items.map { BreviarioItem(id: $0.page, data: $0.date, titulo: $0.title, frase: "", texto: $0.body, rodape: $0.notes, pagina: $0.page, obraID: $0.work) }
        let textos = Dictionary(uniqueKeysWithValues: zip(itens, fixture.items).map { ($0.0.chavePersistencia, [$0.1.title, $0.1.body, $0.1.notes, $0.1.index].joined(separator: " ")) })
        for ordem in [itens, itens.reversed().map { $0 }] {
            for tamanho in [1, 2, 3, 8] {
                var selecionados: [BreviarioItem] = []
                for inicio in stride(from: 0, to: ordem.count, by: tamanho) {
                    let lote = Array(ordem[inicio..<min(inicio + tamanho, ordem.count)])
                    selecionados = RegrasEstudo.incorporar(selecionados, lote: lote + lote, palavras: fixture.keywords, textos: textos, limite: fixture.limit)
                    XCTAssertLessThanOrEqual(selecionados.count, fixture.limit)
                }
                XCTAssertEqual(selecionados.map(\.chavePersistencia), fixture.expected)
                XCTAssertEqual(selecionados.first { $0.chavePersistencia == "a_P2" }?.rodape, "578 Estudo da ÉTICA.")
            }
        }
        XCTAssertTrue(RegrasEstudo.selecionar(itens, palavras: fixture.keywords, textos: textos, limite: 0).isEmpty)
    }

    func testRecentPagesFromDownloadedWorksPreserveNotesAndWorkScope() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let db = try BibliotecaSQLiteService(url: root.appendingPathComponent("RAGPackages/recent.sqlite"))
        let ids = ["recent-a-\(UUID().uuidString)", "recent-b-\(UUID().uuidString)"]
        for id in ids {
            let work = BibliotecaRAGObra(id: id, area: .bibliotecaMaconica, tipo: .livro, titulo: id, autor: "Autor", origem: nil, edicao: nil, assuntos: [], dataImportacao: Date())
            let pages = (1...4).map { BibliotecaRAGPagina(obraID: id, numeroOriginal: $0, titulo: "Pagina \($0)", textoIntegral: "Texto integral \(id) \($0)", largura: 595, altura: 842) }
            let notes = (1...4).map { BibliotecaRAGNotaRodape(obraID: id, pagina: $0, numero: "578", texto: "Nota \(id) \($0)") }
            try db.substituirObra(obra: work, paginas: pages, paragrafos: [], notas: notes, imagens: [])
        }
        let works = ids.map { BibliotecaRAGPacoteObra(id: $0, titulo: $0, autor: "Autor", tipo: .livro, paginas: 4, paragrafos: 0, notas: 4, assuntos: []) }
        let package = BibliotecaRAGPacote(area: .bibliotecaMaconica, titulo: "Recentes", arquivo: "recent.sqlite", url: nil, sha256: nil, nivel: nil, tamanhoBytes: 1, estatisticas: .init(obras: 2, paginas: 8, paragrafos: 0, notas: 8, imagens: 0, blocosFTS: 0), obras: works)
        let catalog = BibliotecaRAGCatalogo(versaoFormato: 1, estrategia: "teste", geradoEm: "teste", origem: nil, baseURL: nil, pacotes: [package], totais: .init(pacotes: 1, obras: 2, paginas: 8, paragrafos: 0, notas: 8, blocosFTS: 0, tamanhoBytes: 1))
        let url = root.appendingPathComponent("catalog.json")
        try JSONEncoder().encode(catalog).write(to: url)
        let service = try BibliotecaRAGCatalogService(catalogoURL: url)
        let work = try XCTUnwrap(service.obras().first { $0.id == ids[0] })
        let references = ["P4", "P2", "P1"]
        let recent = try BreviarioStore.carregarItensRecentesParaResumo(obra: work, referencias: references, catalogo: service)
        XCTAssertEqual(recent.map(\.pagina), [1, 2, 4])
        let indexed = Dictionary(uniqueKeysWithValues: recent.map { ($0.data, $0) })
        XCTAssertEqual(references.compactMap { indexed[$0]?.pagina }, [4, 2, 1])
        for item in recent {
            XCTAssertEqual(item.obraID, work.id)
            XCTAssertEqual(item.texto, "Texto integral \(work.id) \(try XCTUnwrap(item.pagina))")
            XCTAssertEqual(item.rodape, "578 Nota \(work.id) \(try XCTUnwrap(item.pagina))")
        }
        XCTAssertTrue(try BreviarioStore.carregarItensRecentesParaResumo(obra: work, referencias: ["", "20/09", "P0", "P-1", "P999"], catalogo: service).isEmpty)
        XCTAssertTrue(try db.carregarItensBiblioteca(obraID: work.id, paginas: []).isEmpty)
        XCTAssertEqual(try db.carregarItensBiblioteca(obraID: work.id, paginas: [2, 2, -1]).map(\.pagina), [2])
        XCTAssertEqual(try db.carregarItensBiblioteca(obraID: ids[1]).count, 4)
        var batches: [[BreviarioItem]] = []
        try db.percorrerItensBiblioteca(obraID: work.id, tamanhoLote: 2) { batches.append($0); return true }
        XCTAssertEqual(batches.map(\.count), [2, 2])
        XCTAssertEqual(batches.flatMap { $0 }.map(\.pagina), [1, 2, 3, 4])
        XCTAssertTrue(batches.flatMap { $0 }.allSatisfy { $0.obraID == work.id && $0.rodape?.contains("578 Nota") == true })
        var visits = 0
        try db.percorrerItensBiblioteca(obraID: work.id, tamanhoLote: 1) { _ in visits += 1; return false }
        XCTAssertEqual(visits, 1)
    }

    @MainActor
    func testVisualExportFixture() throws {
        let body = (1...45).map { String(repeating: "Parágrafo \($0). Estudo da maçonaria e formação para uma leitura integral. Chamada 578; data 01/06/2026; quantidade 1234. ", count: 3) }.joined(separator: "\n\n") + " FIMLEITURA"
        let item = BreviarioItem(id: 1, data: "01/06", titulo: "Verificação visual de parágrafos, notas e paginação", frase: "", texto: body, rodape: "578 NOTAINTEGRAL\n579 SEGUNDANOTAINTEGRAL", autor: "Autor", pagina: 1)
        let url = try PDFService.gerarPDF(item: item, comentario: "COMENTARIOINTEGRAL\n\nComentário pessoal 578 preservado em nova página.", nomeUsuario: "Pessoa de teste", incluirComentario: true)
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("paridade-exportacao-ios.pdf")
        try Data(contentsOf: url).write(to: output, options: .atomic)
        let document = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertGreaterThan(document.pageCount, 3)
        XCTAssertTrue(document.string?.contains("FIMLEITURA") == true)
        XCTAssertTrue(document.string?.contains("COMENTARIOINTEGRAL") == true)
        try? FileManager.default.removeItem(at: url)
    }

    func testSharedStudyRulesHaveStableDefinitions() {
        let rules = RegrasEstudo.compartilhadas
        XCTAssertEqual(rules.schemaVersion, 1)
        XCTAssertEqual(rules.colecoes.count, 9)
        XCTAssertEqual(rules.trilhas.count, 7)
        XCTAssertEqual(rules.collectionLimit, 24)
        XCTAssertEqual(rules.pathLimit, 18)
        XCTAssertEqual(Set(rules.trilhas.map(\.id)).count, 7)
        let first = HomeView.montarConteudoPremiumCache(itens: [], indice: []).trilhas
        let second = HomeView.montarConteudoPremiumCache(itens: [], indice: []).trilhas
        XCTAssertEqual(first.map(\.id), rules.trilhas.map(\.id))
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        for (path, rule) in zip(first, rules.trilhas) {
            XCTAssertEqual(path.subtitulo, rule.subtitulo)
            XCTAssertEqual(path.instrucao, rule.instrucao)
            XCTAssertEqual(path.objetivo, rule.objetivo)
            XCTAssertEqual(path.duracaoSugerida, rule.duracaoSugerida)
            XCTAssertEqual(path.etapas, rule.etapas)
        }
    }

    @MainActor
    func testLongPDFTitleAndSequentialFootnotesAreNotTruncated() throws {
        let title = String(repeating: "Título extenso para verificar a paginação integral. ", count: 35) + " FIMTITULO"
        let notes = (1...80).map { "\($0) Nota documental completa \($0)." }.joined(separator: "\n") + " FIMNOTAS"
        let item = BreviarioItem(id: 1, data: "01/06", titulo: title, frase: "", texto: "LEITURAPRESERVADA", rodape: notes)
        let url = try PDFService.gerarPDF(item: item, comentario: "COMENTARIOPRESERVADO", incluirComentario: true)
        defer { try? FileManager.default.removeItem(at: url) }
        let document = try XCTUnwrap(PDFDocument(url: url))
        let pages = (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
        for marker in ["FIMTITULO", "LEITURAPRESERVADA", "FIMNOTAS", "COMENTARIOPRESERVADO"] {
            XCTAssertEqual(pages.joined().components(separatedBy: marker).count - 1, 1, marker)
        }
        XCTAssertGreaterThan(try XCTUnwrap(pages.firstIndex { $0.contains("COMENTARIOPRESERVADO") }),
                             try XCTUnwrap(pages.firstIndex { $0.contains("FIMNOTAS") }))
    }

    func testQuotedPhraseKeepsOrderWhileWordsCanCross() {
        XCTAssertEqual(BibliotecaSQLiteService.termosBusca("\"Grande Loja\" história"), ["grande loja", "história"])
        XCTAssertTrue(BibliotecaSQLiteService.corresponde(termo: "grande loja", texto: "A loja é grande"))
        XCTAssertFalse(BibliotecaSQLiteService.corresponde(termo: "\"grande loja\"", texto: "A loja é grande"))
        XCTAssertTrue(BibliotecaSQLiteService.corresponde(termo: "maçonaria", texto: "Estudo da MACONARIA."))
    }

    func testSuperscriptKeepsUnrelatedNumbersUnchanged() {
        let text = "Em 01/06/2026, texto 578 e outro579. Total 1234; 12/578 não é chamada."
        XCTAssertEqual(HomeView.converterChamadasRodapeParaSobrescrito(text, chamadasRodape: ["578", "579"]),
                       "Em 01/06/2026, texto ⁵⁷⁸ e outro⁵⁷⁹. Total 1234; 12/578 não é chamada.")
    }

    func testSamePDFIsRecognizedAsAlreadyImported() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("%PDF-1.4 same file \(UUID())".utf8).write(to: url)
        let hash = try XCTUnwrap(BreviarioStore.sha256PDF(url))
        let obra = BibliotecaObra(id: "pdf-duplicado-\(UUID().uuidString)", titulo: "Obra importada", autor: nil, area: .bibliotecaMaconica,
                                  tipo: .livro, recursoJSON: nil, descricao: "", assuntos: [], ativa: true)
        let conteudo = try BreviarioStore.criarURLImportado(obraID: obra.id)
        defer { try? FileManager.default.removeItem(at: conteudo) }
        try BreviarioStore.registrarPDFImportado(hash, obraID: obra.id)
        // Without the imported content (the import failed or was removed) the PDF can be imported again.
        XCTAssertNil(BreviarioStore.obraComPDF(hash, obras: [obra]))
        try Data("{}".utf8).write(to: conteudo)
        XCTAssertEqual(BreviarioStore.obraComPDF(hash, obras: [obra])?.id, obra.id)
        XCTAssertEqual(BreviarioStore.mensagemPDFDuplicado(obra.titulo), "Este PDF já foi importado como “Obra importada”.")
    }

    func testCorruptPDFIsRejectedInsteadOfEmptySuccess() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("invalid document".utf8).write(to: url)
        XCTAssertThrowsError(try PDFOCRService.extrairTexto(url: url))
        XCTAssertThrowsError(try PDFOCRService.renderizarPaginas(url: url, obraID: "test"))
    }

    @MainActor
    func testPDFPreviewPreservesOrientationAndColor() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: source) }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400))
        let data = renderer.pdfData { context in
            context.beginPage()
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 200, width: 300, height: 200))
        }
        let document = try XCTUnwrap(PDFDocument(data: data))
        let page = try XCTUnwrap(document.page(at: 0))
        func pixels(_ image: UIImage) throws -> [UInt8] {
            let cg = try XCTUnwrap(image.cgImage)
            var bytes = [UInt8](repeating: 0, count: 24 * 24 * 4)
            bytes.withUnsafeMutableBytes { storage in
                let context = CGContext(data: storage.baseAddress, width: 24, height: 24, bitsPerComponent: 8, bytesPerRow: 96,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.interpolationQuality = .none
                context.draw(cg, in: CGRect(x: 0, y: 0, width: 24, height: 24))
            }
            return bytes
        }
        for rotation in [0, 90, 180, 270] {
            page.rotation = rotation
            XCTAssertTrue(document.write(to: source))
            let media = try PDFOCRService.renderizarPaginas(url: source, obraID: "orientation-\(UUID().uuidString)", qualidade: 1)
            let output = try XCTUnwrap(media[1]?.urlArquivo)
            defer { try? FileManager.default.removeItem(at: output.deletingLastPathComponent().deletingLastPathComponent()) }
            let actual = try XCTUnwrap(UIImage(contentsOfFile: output.path))
            let expected = page.thumbnail(of: actual.size, for: .mediaBox)
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try actual.pngData()?.write(to: documents.appendingPathComponent("orientation-\(rotation)-actual.png"))
            try expected.pngData()?.write(to: documents.appendingPathComponent("orientation-\(rotation)-expected.png"))
            let actualPixels = try pixels(actual), expectedPixels = try pixels(expected)
            let differing = zip(actualPixels, expectedPixels).filter { abs(Int($0) - Int($1)) > 12 }.count
            XCTAssertLessThan(differing, 100, "Incorrect orientation/color at rotation \(rotation)")
        }
    }

    @MainActor
    func testMultiPagePDFExtractionKeepsColumnsAndLastPage() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: source) }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 900, height: 1200))
        try renderer.writePDF(to: source) { context in
            for number in 1...40 {
                context.beginPage()
                for (x, label) in [(CGFloat(40), "LEFT"), (CGFloat(480), "RIGHT")] {
                    ("\(label)PAGE\(number)END" as NSString).draw(at: CGPoint(x: x, y: 80), withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
                }
            }
        }
        let text = try PDFOCRService.extrairTexto(url: source, modo: .obraGenerica)
        for number in 1...40 {
            XCTAssertEqual(text.components(separatedBy: "LEFTPAGE\(number)END").count - 1, 1)
            XCTAssertEqual(text.components(separatedBy: "RIGHTPAGE\(number)END").count - 1, 1)
        }
    }

    @MainActor
    func testScannedPDFRecognizesBodyAndFootnoteAfterRendering() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: source) }
        let rect = CGRect(x: 0, y: 0, width: 800, height: 1000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: rect, format: format).image { context in
            UIColor.white.setFill(); context.fill(rect)
            let font: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 30), .foregroundColor: UIColor.black]
            ("MASONRY STUDY" as NSString).draw(at: CGPoint(x: 70, y: 80), withAttributes: font)
            ("Integral reading for a library audit." as NSString).draw(at: CGPoint(x: 70, y: 150), withAttributes: font)
            UIColor.black.setFill(); context.fill(CGRect(x: 70, y: 820, width: 530, height: 3))
            ("578 Footnote preserved for study." as NSString).draw(at: CGPoint(x: 70, y: 860), withAttributes: font)
        }
        try UIGraphicsPDFRenderer(bounds: rect).writePDF(to: source) { context in
            context.beginPage(); image.draw(in: rect)
        }
        XCTAssertTrue(PDFDocument(url: source)?.page(at: 0)?.string?.isEmpty ?? true)
        let text = try PDFOCRService.extrairTexto(url: source, modo: .obraGenerica)
        XCTAssertTrue(text.contains("MASONRY STUDY"))
        XCTAssertTrue(text.contains("Integral reading"))
        XCTAssertTrue(text.contains("578"))
        XCTAssertTrue(text.contains("Footnote preserved"))
        XCTAssertTrue(text.contains(PDFOCRService.marcadorRodapePorLayout))
    }

    @MainActor
    func testMultiDayPDFKeepsLongIndexEntriesAndEveryReading() throws {
        let items = (1...3).map { day in
            BreviarioItem(id: day, data: String(format: "%02d/06", day), titulo: String(repeating: "Título extenso para testar índice sem cortes. ", count: 20) + " TITULOEND\(day)", frase: "", texto: "CORPOINTEGRAL\(day)", rodape: "578 NOTAINTEGRAL\(day)", autor: "Autor de teste", pagina: day)
        }
        let url = try PDFService.gerarPDF(itens: items, incluirComentarios: false)
        defer { try? FileManager.default.removeItem(at: url) }
        let document = try XCTUnwrap(PDFDocument(url: url))
        let text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
        for day in 1...3 {
            XCTAssertEqual(text.components(separatedBy: "TITULOEND\(day)").count - 1, 2)
            XCTAssertEqual(text.components(separatedBy: "CORPOINTEGRAL\(day)").count - 1, 1)
            XCTAssertEqual(text.components(separatedBy: "NOTAINTEGRAL\(day)").count - 1, 1)
        }
    }

    @MainActor
    func testPDFReimportPreservesOriginalAndPreviousMedia() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            ("Texto integral 578" as NSString).draw(at: CGPoint(x: 25, y: 60), withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
        }
        defer { try? FileManager.default.removeItem(at: url) }
        let obra = "test-\(UUID().uuidString)"
        let first = try PDFOCRService.renderizarPaginas(url: url, obraID: obra)
        let second = try PDFOCRService.renderizarPaginas(url: url, obraID: obra)
        let firstURL = try XCTUnwrap(first[1]?.urlArquivo)
        let secondURL = try XCTUnwrap(second[1]?.urlArquivo)
        defer { try? FileManager.default.removeItem(at: firstURL.deletingLastPathComponent().deletingLastPathComponent()) }
        XCTAssertNotEqual(firstURL, secondURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertEqual(try Data(contentsOf: url), try Data(contentsOf: secondURL.deletingLastPathComponent().appendingPathComponent("original.pdf")))
    }
    func testOfficialURLAloneIsNotDocumentaryEvidence() {
        let source = FonteOficialMaconica(titulo: "Fonte de teste", origem: "Instituição", url: "https://example.org", observacao: "")
        let context = BibliotecaRAGContextoIA(pergunta: "Teste", trechos: [], notas: [], fontesOficiais: [source])
        XCTAssertFalse(context.possuiBaseDocumentalSuficiente)
    }

    @MainActor
    func testBackupIgnoresUnchangedContentAndDetectsEdits() {
        let first: [String: Any] = ["comentario_01/06": "Integral", "temaApp": "sepia"]
        let reordered: [String: Any] = ["temaApp": "sepia", "comentario_01/06": "Integral"]
        XCTAssertTrue(UserDataPersistenceService.conteudoIgual(first, reordered))
        XCTAssertFalse(UserDataPersistenceService.conteudoIgual(first, nil))
        XCTAssertFalse(UserDataPersistenceService.conteudoIgual(["comentario_01/06": "Editado"], first))
        XCTAssertFalse(UserDataPersistenceService.conteudoIgual([:], first))
    }

    func testEditingPreservesOriginalPageImage() {
        let media = PaginaMidia(pagina: 8, caminhoRelativo: "teste/p8.png", largura: 600, altura: 800, tipo: "pagina")
        let original = BreviarioItem(id: 8, data: "P8", titulo: "Original", frase: "", texto: "Integral", obraID: "teste", paginaMidia: media)
        let edited = original.atualizado(titulo: "Editado", texto: "Revisado")
        XCTAssertEqual(edited.paginaMidia, media)
        XCTAssertEqual(edited.obraID, original.obraID)
        XCTAssertEqual(edited.id, original.id)
    }

    func testLegacyCommentDoesNotLeakToAnotherWork() {
        let date = "audit-\(UUID().uuidString)"
        let legacyKey = "comentario_\(date)"
        UserDefaults.standard.set("Somente original", forKey: legacyKey)
        defer { UserDefaults.standard.removeObject(forKey: legacyKey) }
        XCTAssertEqual(CommentsService.carregar(data: date), "Somente original")
        XCTAssertEqual(CommentsService.carregar(data: date, obraID: "outra_obra"), "")
    }

    func testInvalidDateAndPageReferencesRemainUnchanged() {
        for date in ["00/06", "01/13", "01/00", "32/01", "01/06/2026", "P185"] {
            let item = BreviarioItem(id: 1, data: date, titulo: "", frase: "", texto: "")
            XCTAssertEqual(item.dataExportacao, date)
        }
    }

    func testSQLiteSearchHandlesSymbolsAndKeepsWorkFilters() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try BibliotecaSQLiteService(url: directory.appendingPathComponent("test.sqlite"))
        for id in ["obra_a", "obra_b"] {
            let work = BibliotecaRAGObra(id: id, area: .bibliotecaMaconica, tipo: .livro, titulo: id, autor: nil, origem: nil, edicao: nil, assuntos: [], dataImportacao: Date())
            let paragraph = BibliotecaRAGParagrafo(obraID: id, pagina: 1, ordem: 1, texto: "Grão mestre e símbolos da maçonaria", capitulo: nil, secao: nil, temas: [], palavrasChave: [])
            try database.substituirObra(obra: work, paginas: [], paragrafos: [paragraph], notas: [], imagens: [])
        }
        let hits = try database.buscarTexto(termo: "grão-mestre", obraID: "obra_a")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.obraID, "obra_a")
        for query in ["\"", "!!!", "OR", "NEAR()", "a", "símbolos"] {
            XCTAssertNoThrow(try database.buscarTexto(termo: query))
        }
    }

    @MainActor
    func testPremiumPDFKeepsEndOfReadingFootnoteAndSeparateComment() throws {
        let body = String(repeating: "Parágrafo para testar paginação integral. ", count: 180) + " FIMLEITURA"
        let item = BreviarioItem(id: 1, data: "01/06", titulo: "Auditoria", frase: "", texto: body, rodape: "578 NOTAINTEGRAL", autor: "Autor de teste")
        let url = try PDFService.gerarPDF(item: item, comentario: "COMENTARIOINTEGRAL", incluirComentario: true)
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        let pages = (0..<pdf.pageCount).map { pdf.page(at: $0)?.string ?? "" }
        XCTAssertTrue(pages.joined().contains("01 de junho"))
        let readingPage = try XCTUnwrap(pages.firstIndex { $0.contains("FIMLEITURA") })
        let notePage = try XCTUnwrap(pages.firstIndex { $0.contains("NOTAINTEGRAL") })
        let commentPage = try XCTUnwrap(pages.firstIndex { $0.contains("COMENTARIOINTEGRAL") })
        XCTAssertGreaterThan(commentPage, max(readingPage, notePage))
    }

    func testReadingMetricsAreBoundedAndHandleEmptyCollections() {
        XCTAssertEqual(ReadingMetricsController.progress(completed: 0, total: 0), 0)
        XCTAssertEqual(ReadingMetricsController.percentage(completed: 2, total: 4), 50)
        XCTAssertEqual(ReadingMetricsController.progress(completed: 8, total: 4), 1)
    }

    @MainActor
    func testNavigationControllerOpensReadingAndReturnsHome() {
        let navigation = AppNavigationController()
        navigation.showReading(itemID: 42)
        XCTAssertEqual(navigation.selectedTab, AppNavigationController.Tab.acervo.rawValue)
        XCTAssertEqual(navigation.readingPath, [42])
        navigation.showHome()
        XCTAssertEqual(navigation.selectedTab, AppNavigationController.Tab.inicio.rawValue)
        XCTAssertTrue(navigation.readingPath.isEmpty)
        XCTAssertEqual(navigation.moreScreen, .menu)
    }

    @MainActor
    func testReadingStackResetsOnlyWhenLeavingAnOpenReadingForHome() {
        let navigation = AppNavigationController()
        for id in [32, 126, 32] {
            let stackID = navigation.readingStackID
            navigation.showMore(.buscaBiblioteca)
            navigation.showReading(itemID: id)
            XCTAssertEqual(navigation.readingPath, [id])
            XCTAssertEqual(navigation.readingStackID, stackID)
            navigation.showHome()
            XCTAssertNotEqual(navigation.readingStackID, stackID)
            XCTAssertTrue(navigation.readingPath.isEmpty)
        }
        let emptyStackID = navigation.readingStackID
        navigation.showHome()
        XCTAssertEqual(navigation.readingStackID, emptyStackID)
        XCTAssertTrue(navigation.readingPath.isEmpty)
        navigation.showLibrary()
        navigation.showReading(itemID: 10)
        XCTAssertEqual(navigation.readingPath, [10])
    }

    @MainActor
    func testClosingReadingReturnsToTheTabThatOpenedIt() {
        let navigation = AppNavigationController()
        navigation.selectedTab = AppNavigationController.Tab.dossie.rawValue
        navigation.showReading(itemID: 7)
        XCTAssertEqual(navigation.selectedTab, AppNavigationController.Tab.acervo.rawValue)
        XCTAssertEqual(navigation.readingReturnTab, AppNavigationController.Tab.dossie.rawValue)

        navigation.closeReading()
        XCTAssertEqual(navigation.selectedTab, AppNavigationController.Tab.dossie.rawValue)
        XCTAssertTrue(navigation.readingPath.isEmpty)
        XCTAssertNil(navigation.readingReturnTab)

        navigation.showMore(.buscaBiblioteca)
        navigation.showReading(itemID: 8)
        navigation.closeReading()
        XCTAssertEqual(navigation.selectedTab, AppNavigationController.Tab.mais.rawValue)
        XCTAssertEqual(navigation.moreScreen, .buscaBiblioteca)
    }

    @MainActor
    func testClosingReadingOpenedInsideAcervoStaysInAcervo() {
        let navigation = AppNavigationController()
        navigation.showLibrary()
        navigation.showReading(itemID: 3)
        XCTAssertNil(navigation.readingReturnTab)
        navigation.closeReading()
        XCTAssertEqual(navigation.selectedTab, AppNavigationController.Tab.acervo.rawValue)
        XCTAssertTrue(navigation.readingPath.isEmpty)

        navigation.selectedTab = AppNavigationController.Tab.colecoes.rawValue
        navigation.showReading(itemID: 4)
        navigation.forgetReadingOrigin()
        navigation.closeReading()
        XCTAssertEqual(navigation.selectedTab, AppNavigationController.Tab.acervo.rawValue)
    }

    @MainActor
    func testNavigationControllerOpensMoreDestination() {
        let navigation = AppNavigationController()
        navigation.showMore(.fontesOficiais)
        XCTAssertEqual(navigation.selectedTab, AppNavigationController.Tab.mais.rawValue)
        XCTAssertEqual(navigation.moreScreen, .fontesOficiais)
    }

    @MainActor
    func testNotificationDestinationSurvivesUntilReaderConsumesIt() throws {
        let router = NotificationReadingRouter()
        let first = try XCTUnwrap(URL(string: "breviario://leitura?obra=breviario-seculo-xxi&data=02-02"))
        let latest = try XCTUnwrap(URL(string: "breviario://leitura?obra=breviario-seculo-xxi&data=04-05"))
        router.receive(first)
        XCTAssertEqual(router.pendingURL, first)
        router.receive(latest)
        router.consume(first)
        XCTAssertEqual(router.pendingURL, latest)
        router.receive(try XCTUnwrap(URL(string: "https://example.com")))
        XCTAssertEqual(router.pendingURL, latest)
        router.consume(latest)
        XCTAssertNil(router.pendingURL)
    }

    func testActivationCodeIsStableForSameDate() {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16))!
        XCTAssertEqual(ActivationCodeGenerator.codigoDoDia(date), ActivationCodeGenerator.codigoDoDia(date))
        XCTAssertTrue(ActivationCodeGenerator.codigoValido(ActivationCodeGenerator.codigoDoDia(date), para: date))
    }

    func testActivationRejectsExpiredAndArbitraryCodes() {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)!
        XCTAssertFalse(ActivationCodeGenerator.codigoValido(ActivationCodeGenerator.codigoDoDia(yesterday), para: date))
        XCTAssertFalse(ActivationCodeGenerator.codigoValido("BMXI-0000-0000", para: date))
    }

    func testPortugueseExportDate() {
        let item = BreviarioItem(
            id: 1,
            data: "01/06",
            titulo: "Título",
            frase: "",
            texto: "Texto completo"
        )
        XCTAssertEqual(item.dataExportacao, "01 de junho")
    }

    func testParagraphFormattingPreservesParagraphsAndJoinsWrappedLines() {
        let input = "Primeira linha\ncontinuação do parágrafo.\n\nSegundo parágrafo."
        XCTAssertEqual(
            TextoLeituraFormatter.comParagrafosVisiveis(input),
            "Primeira linha continuação do parágrafo.\n\nSegundo parágrafo."
        )
    }

    func testFootnotesAreKeptOnSequentialLines() {
        let input = "578 Primeira nota. 579 Segunda nota."
        XCTAssertEqual(
            TextoLeituraFormatter.rodapeComNotasEmLinhas(input, chamadasRodape: ["578", "579"]),
            "578 Primeira nota.\n579 Segunda nota."
        )
    }

    func testPersistenceKeySeparatesWorksWithSameDate() {
        let first = BibliotecaItemID(obraID: "obra_a", itemID: 1, data: "01/06")
        let second = BibliotecaItemID(obraID: "obra_b", itemID: 1, data: "01/06")
        XCTAssertNotEqual(first.chavePersistencia, second.chavePersistencia)
    }

    @MainActor
    func testReadingProgressCanBePersistedAndRemoved() {
        let work = "teste_paridade"
        let date = "16/09"
        ReadingProgressService.definirConcluido(date, obraID: work, lido: true, sincronizar: false)
        XCTAssertTrue(ReadingProgressService.concluidos(obraID: work).contains(date))
        ReadingProgressService.definirConcluido(date, obraID: work, lido: false, sincronizar: false)
        XCTAssertFalse(ReadingProgressService.concluidos(obraID: work).contains(date))
    }
}

private extension NSObject {
    /// Canonical JSON text of a value, so nested dictionaries and arrays compare structurally.
    static func normalizarJSON(_ valor: Any?) -> String {
        guard let valor, let dados = try? JSONSerialization.data(withJSONObject: ["v": valor], options: [.sortedKeys]) else { return "nil" }
        return String(decoding: dados, as: UTF8.self)
    }
}
