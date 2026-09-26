import XCTest
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
        let largest = try XCTUnwrap(service.pacotes.flatMap(\.obras).max { $0.paginas < $1.paginas })
        let start = ProcessInfo.processInfo.systemUptime
        let pages = try service.carregarIndicePaginas(obraID: largest.id)
        XCTAssertEqual(pages.count, largest.paginas)
        let report: [String: Any] = [
            "environment": "iPhone simulator; not a physical-device certification",
            "packages": service.pacotes.count, "queries": timings,
            "largestWorkPages": pages.count,
            "pageIndexMilliseconds": (ProcessInfo.processInfo.systemUptime - start) * 1000
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: documents.appendingPathComponent("medicao-acervo-ios.json"), options: .atomic)
    }

    func testFullCatalogStudyBatchesWhenAuditCorpusIsInstalled() throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let catalogURL = documents.appendingPathComponent("rag_catalogo.json")
        guard FileManager.default.fileExists(atPath: catalogURL.path) else { throw XCTSkip("Audit corpus not installed") }
        let catalog = try BibliotecaRAGCatalogService(catalogoURL: catalogURL)
        let rules = RegrasEstudo.compartilhadas
        let words = (rules.colecoes.map(\.palavrasChave) + rules.trilhas.map(\.palavrasChave)).map { $0.map(RegrasEstudo.normalizar) }
        let limits = Array(repeating: rules.collectionLimit, count: rules.colecoes.count) + Array(repeating: rules.pathLimit, count: rules.trilhas.count)
        var selected = Array(repeating: [BreviarioItem](), count: words.count)
        var total = 0
        var maxBatch = 0
        let start = ProcessInfo.processInfo.systemUptime
        for work in catalog.obras() {
            try catalog.percorrerItens(obraID: work.id) { batch in
                total += batch.count
                maxBatch = max(maxBatch, batch.count)
                let texts = Dictionary(uniqueKeysWithValues: batch.map { ($0.chavePersistencia, RegrasEstudo.normalizar([$0.titulo, $0.texto, $0.rodape ?? ""].joined(separator: " "))) })
                for i in words.indices {
                    selected[i] = RegrasEstudo.incorporarNormalizados(selected[i], lote: batch, palavras: words[i], textos: texts, limite: limits[i])
                }
                return true
            }
        }
        XCTAssertEqual(total, catalog.totaisPorObra().values.reduce(0, +))
        XCTAssertLessThanOrEqual(maxBatch, 100)
        for i in selected.indices {
            XCTAssertFalse(selected[i].isEmpty)
            XCTAssertLessThanOrEqual(selected[i].count, limits[i])
            XCTAssertTrue(selected[i].allSatisfy { ($0.pagina ?? 0) > 0 })
        }
        let report: [String: Any] = ["pages": total, "maxBatch": maxBatch, "milliseconds": (ProcessInfo.processInfo.systemUptime - start) * 1000,
            "resultsPerRule": selected.map(\.count),
            "ruleIDs": rules.colecoes.map(\.id) + rules.trilhas.map(\.id),
            "selectedPages": selected.map { $0.map { "\($0.obraID):\($0.pagina ?? 0)" } },
            "environment": "simulator, not physical certification"]
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
                XCTAssertEqual(selecionados.first?.rodape, "578 Estudo da ÉTICA.")
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
