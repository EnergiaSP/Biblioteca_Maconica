import XCTest

final class BibliotecaMaconicaUITests: XCTestCase {
    func testDossierInvalidatesSourcesWhenAuthorFilterChanges() {
        navigationTab("Dossiê").tap()
        let topic = app.descendants(matching: .any).matching(identifier: "dossier.topic").firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        topic.tap()
        topic.typeText("virtude")
        let generate = app.buttons["Montar dossiê"].firstMatch
        for _ in 0..<4 where !generate.isHittable { app.swipeUp() }
        XCTAssertTrue(generate.isHittable)
        generate.tap()
        let results = app.otherElements["dossier.results"].firstMatch
        XCTAssertTrue(results.waitForExistence(timeout: 20))
        let author = app.descendants(matching: .any).matching(identifier: "search.author").firstMatch
        for _ in 0..<4 where !author.isHittable { app.swipeDown() }
        XCTAssertTrue(author.isHittable)
        author.tap()
        author.typeText("Autor inexistente de teste")
        XCTAssertTrue(results.waitForNonExistence(timeout: 5))
    }
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 12))
    }

    /// Updates the installed collection to the current catalog through "Acervo offline", as a user
    /// would. Opt-in because it downloads the whole collection: `TEST_RUNNER_ATUALIZAR_ACERVO=1 xcodebuild test ...`.
    @MainActor
    func testOutdatedPackagesAreUpdatedFromOfflineCollection() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ATUALIZAR_ACERVO"] == "1", "Downloads the whole collection")
        navigationTab("Mais").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Acervo offline")).firstMatch.tap()
        let aviso = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "com atualização disponível")).firstMatch
        XCTAssertTrue(aviso.waitForExistence(timeout: 10), "Installed packages from the previous catalog are offered as updates")
        app.buttons["Baixar todo o acervo"].firstMatch.tap()
        let concluido = app.staticTexts["Todo o acervo está disponível offline."]
        let interrompido = app.staticTexts["O download geral foi interrompido antes de concluir."]
        let fim = Date().addingTimeInterval(60 * 60)
        while Date() < fim && concluido.exists == false && interrompido.exists == false {
            _ = concluido.waitForExistence(timeout: 30)
        }
        XCTAssertFalse(interrompido.exists)
        XCTAssertTrue(concluido.exists)
        XCTAssertFalse(aviso.exists, "No update left after downloading everything")
    }

    private func navigationTab(_ title: String) -> XCUIElement {
        let compactTab = app.tabBars.buttons[title]
        if compactTab.exists { return compactTab }
        // iPadOS exposes its floating tab bar without an XCUI TabBar ancestor.
        return app.buttons[title].firstMatch
    }

    @MainActor
    private func auditAccessibility(_ types: XCUIAccessibilityAuditType = .all) throws {
        // Text under the tab bar or cut by the screen edge is measured against the bar, not the
        // app's colors. Such elements are brought fully into view and audited again below.
        var cobertos: [(label: String, frame: CGRect, tipo: XCUIAccessibilityAuditType)] = []
        // On iPad the system tab bar sits at the top and its labels keep a fixed size (the app's own
        // text grows; see the Phase 7 report). The audit reports them as UILabels with no element.
        // At most one such report per tab is tolerated, and only there.
        let abasNoTopo = barraDeAbasNoTopo()
        var rotulosDaBarra = 0
        var capturouTela = false
        // Each new attempt measures the tab bar again, so its count starts over.
        // The handler runs inside the audit's time limit: every property read on an element is a
        // query to the app, so each is read once and only when needed (dozens of reports on the
        // iPad Collections grid used to push the audit past its limit).
        let quadroApp = app.frame
        try auditarRepetindoSeExpirar(types, aoRecomecar: { rotulosDaBarra = 0 }) { issue in
            let element = issue.element
            let rotulo = element?.label ?? ""
            let quadro = element?.frame
            let details = """
            \(issue.compactDescription)
            \(issue.detailedDescription)
            Label: \(element == nil ? "<none>" : rotulo)
            Frame: \(String(describing: quadro))
            App frame: \(quadroApp)
            """
            let attachment = XCTAttachment(string: details)
            attachment.name = "Accessibility-issue-details"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            if !capturouTela {
                // What the screen looked like when the audit measured it.
                capturouTela = true
                let tela = XCTAttachment(screenshot: self.app.screenshot())
                tela.name = "Accessibility-issue-screen"
                tela.lifetime = .keepAlways
                self.add(tela)
            }
            print("ACCESSIBILITY_DIAGNOSTIC: \(details)")
            // WCAG 1.4.3 sets no contrast minimum for inactive controls; the audit flags the disabled
            // "Buscar" (empty query) although its pixels measure 9.2:1 (Phase 7 report).
            if issue.auditType == .contrast, let element, !element.isEnabled {
                return true
            }
            // Any issue on a named element is measured again with the element fully in view (on screen
            // and inside its carousel) and fails if it repeats. Elements hidden by a bar, cut by the
            // screen edge or scrolled past the edge of a carousel were measured against other pixels
            // (iPhone Pro Max; the iPad three-column Collections grid flagged a different chip on
            // each run, e.g. "Fraternidade" outside its card, "Moral", "Ritualística").
            if !rotulo.isEmpty, let quadro {
                cobertos.append((rotulo, quadro, issue.auditType))
                return true
            }
            if abasNoTopo, element == nil, issue.auditType == .dynamicType,
               issue.detailedDescription.contains("UILabel"), rotulosDaBarra < Self.abasPrincipais.count {
                rotulosDaBarra += 1
                return true
            }
            return false
        }
        // One new audit per kind measures every reported element at once (one audit per element
        // timed out on the iPad Collections grid). A report that repeats at the same position is
        // then checked on its own with the element scrolled fully into view; one that does not
        // repeat was not reproducible and is dropped.
        let porTipo = Dictionary(grouping: cobertos, by: { $0.tipo.rawValue })
        for (_, itens) in porTipo {
            let tipo = itens[0].tipo
            var repetidos: [(label: String, frame: CGRect)] = []
            try auditarRepetindoSeExpirar(tipo) { issue in
                guard let element = issue.element else { return true }
                let rotulo = element.label
                guard itens.contains(where: { $0.label == rotulo }) else { return true }
                let quadro = element.frame
                if itens.contains(where: { $0.label == rotulo && $0.frame == quadro }) {
                    repetidos.append((rotulo, quadro))
                }
                return true
            }
            var verificados = Set<String>()
            for repetido in repetidos where verificados.insert(repetido.label).inserted {
                try verificarContrasteVisivel(label: repetido.label, frameOriginal: repetido.frame, tipo: tipo)
            }
        }
    }

    private static let abasPrincipais = ["Início", "Coleções", "Dossiê", "Acervo", "Mais"]

    private func barraDeAbasNoTopo() -> Bool {
        let aba = navigationTab("Início")
        return aba.exists && aba.frame.midY < app.frame.midY
    }

    /// The audit service sometimes times out (code -56, or 1000 from the waiting future) without
    /// reporting anything; that one error is retried once. Any issue it reports still goes through the handler.
    private func auditarRepetindoSeExpirar(_ types: XCUIAccessibilityAuditType,
                                            aoRecomecar: () -> Void = {},
                                            _ handler: @escaping (XCUIAccessibilityAuditIssue) -> Bool) throws {
        for tentativa in 1...2 {
            do {
                aoRecomecar()
                try app.performAccessibilityAudit(for: types, handler)
                return
            } catch let erro as NSError where auditoriaExpirou(erro) {
                if tentativa == 1 { continue }
                // A screen with many elements (Collections on iPad) can time out with every check at
                // once; the same checks then run one kind at a time, so nothing is skipped.
                let tipos: [XCUIAccessibilityAuditType] = [.contrast, .elementDetection, .hitRegion,
                                                          .sufficientElementDescription, .dynamicType,
                                                          .textClipped, .trait]
                let separados = tipos.filter { types.contains($0) }
                guard separados.count > 1 else { throw erro }
                for tipo in separados {
                    try auditarRepetindoSeExpirar(tipo, aoRecomecar: aoRecomecar, handler)
                }
            }
        }
    }

    private func auditoriaExpirou(_ erro: NSError) -> Bool {
        (erro.domain == "com.apple.xcode.xctest.accessibilityAudit" && erro.code == -56)
            || (erro.domain == "com.apple.dt.XCTest.XCTFuture" && erro.code == 1000)
    }

    /// Screen area not covered by the tab bar or the status bar. On iOS 26 the floating bar is not exposed as a tab bar,
    /// so its edge comes from the Home tab button, plus the capsule and the scroll edge band next to it.
    /// The bar sits at the bottom on iPhone and at the top on iPad.
    private func areaVisivel() -> CGRect {
        let aba = navigationTab("Início")
        // At the top, the status bar (with the Dynamic Island) and the opaque edge band.
        var topo = app.frame.minY + 100
        var limite = app.frame.maxY
        if aba.exists, aba.frame.midY < app.frame.midY {
            topo = max(topo, aba.frame.maxY + 32)
            // No bar at the bottom, but the home indicator and the scroll edge band still cover text.
            limite = app.frame.maxY - 40
        } else if aba.exists {
            // 32 pt covers the capsule and the opaque edge band, measured on an iPhone 15 Pro Max.
            limite = aba.frame.minY - 32
        }
        return CGRect(x: app.frame.minX, y: topo, width: app.frame.width, height: limite - topo)
    }

    /// Scrolls the element fully into view and audits again; failing there is a real failure.
    private func verificarContrasteVisivel(label: String, frameOriginal: CGRect,
                                           tipo: XCUIAccessibilityAuditType = .contrast) throws {
        let alvo = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        guard alvo.exists else {
            XCTFail("Elemento com contraste acusado sumiu antes da verificação: \(label)")
            return
        }
        // The smallest horizontal scroll view that holds the element, if it is in a carousel.
        func carrossel() -> XCUIElement? {
            let area = areaVisivel()
            return app.scrollViews.containing(NSPredicate(format: "label == %@", label))
                .allElementsBoundByIndex.filter { $0.frame.height < area.height / 2 && area.intersects($0.frame) }
                .min { $0.frame.height < $1.frame.height }
        }
        func areaDoElemento() -> CGRect {
            let area = areaVisivel()
            guard let carrossel = carrossel() else { return area }
            return area.intersection(carrossel.frame)
        }
        for _ in 0..<8 where !areaDoElemento().contains(alvo.frame) {
            let area = areaVisivel()
            // Vertical position first: a carousel can only be swiped while its row is on screen.
            if alvo.frame.maxY > area.maxY {
                app.swipeUp(velocity: .slow)
            } else if alvo.frame.minY < area.minY {
                app.swipeDown(velocity: .slow)
            } else {
                guard let carrossel = carrossel() else {
                    XCTFail("Carrossel de \(label) não encontrado; frame \(alvo.frame)")
                    return
                }
                if alvo.frame.maxX > carrossel.frame.maxX { carrossel.swipeLeft() } else { carrossel.swipeRight() }
            }
        }
        guard areaDoElemento().contains(alvo.frame) else {
            XCTFail("Não foi possível trazer para a área visível: \(label) \(alvo.frame) em \(areaDoElemento())")
            return
        }
        let frame = alvo.frame
        // Any issue still reported with the element in view fails the test.
        try auditarRepetindoSeExpirar(tipo) { issue in
            // Label first: reading a frame is another query to the app.
            guard let element = issue.element, element.label == label, element.frame == frame else { return true }
            if tipo == .contrast, !element.isEnabled { return true }
            let attachment = XCTAttachment(string: "Aviso mantido com o elemento visível: \(label) \(frame)")
            attachment.name = "Accessibility-visible-issue"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            return false
        }
    }

    /// Saving a dossier creates review cards; the session shows the answer with its source and grades it,
    /// as on Android.
    func testSavedDossierCreatesReviewCardsAndSessionGradesThem() throws {
        navigationTab("Dossiê").tap()
        let topic = app.descendants(matching: .any).matching(identifier: "dossier.topic").firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        let apagar = app.buttons.matching(identifier: "dossier.saved.delete").firstMatch
        while apagar.exists { apagar.tap() }
        let resumo = app.staticTexts["review.summary"].firstMatch
        XCTAssertTrue(resumo.waitForExistence(timeout: 5))
        XCTAssertFalse(resumo.label.contains("para revisar hoje"), "Deleting the saved dossiers removes their cards")

        topic.tap()
        topic.typeText("virtude")
        app.buttons["Montar dossiê"].tap()
        XCTAssertTrue(app.otherElements["dossier.results"].firstMatch.waitForExistence(timeout: 20))
        let salvar = app.buttons["dossier.save"].firstMatch
        for _ in 0..<6 where !salvar.isHittable { app.swipeUp(velocity: .slow) }
        salvar.tap()
        XCTAssertTrue(app.buttons["Dossiê salvo"].waitForExistence(timeout: 5))
        for _ in 0..<40 where !resumo.isHittable { app.swipeDown(velocity: .fast) }
        let total = try XCTUnwrap(Int(resumo.label.prefix { $0.isNumber }), resumo.label)
        XCTAssertGreaterThan(total, 0)

        app.buttons["review.start"].tap()
        XCTAssertTrue(app.staticTexts["review.front"].waitForExistence(timeout: 5))
        app.buttons["review.show"].tap()
        XCTAssertTrue(app.staticTexts["review.back"].waitForExistence(timeout: 5))
        app.buttons["review.grade.acertei"].tap()
        app.buttons["Fechar"].firstMatch.tap()
        XCTAssertTrue(resumo.waitForExistence(timeout: 5))
        XCTAssertEqual(resumo.label, "\(total - 1) cartão(ões) para revisar hoje")

        for _ in 0..<40 where !apagar.isHittable { app.swipeUp(velocity: .slow) }
        apagar.tap()
    }

    /// A collection is read aloud one reading after another, with its position, next and stop. Same as Android.
    func testCollectionPlaysReadingsInSequence() {
        navigationTab("Coleções").tap()
        let ouvir = app.buttons.matching(identifier: "audio.sequence.play").firstMatch
        XCTAssertTrue(ouvir.waitForExistence(timeout: 20))
        ouvir.tap()
        let estado = app.staticTexts["audio.sequence.status"]
        XCTAssertTrue(estado.waitForExistence(timeout: 5))
        XCTAssertTrue(estado.label.contains("leitura 1 de"), estado.label)
        app.buttons["audio.sequence.next"].tap()
        XCTAssertTrue(estado.wait(for: \.label, toEqual: estado.label.replacingOccurrences(of: "leitura 1 de", with: "leitura 2 de"),
                                  timeout: 5), estado.label)
        app.buttons["audio.sequence.stop"].tap()
        XCTAssertTrue(estado.waitForNonExistence(timeout: 5))
    }

    /// A step marked by hand counts in the progress of its degree; "Estudar no Dossiê" builds the dossier of the topic. Same as Android.
    func testDegreeTrackCountsMarkedStepAndStudiesTopic() {
        navigationTab("Mais").tap()
        let trilhas = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Trilhas por grau")).firstMatch
        XCTAssertTrue(trilhas.waitForExistence(timeout: 5))
        for _ in 0..<4 where !trilhas.isHittable { app.swipeUp(velocity: .slow) }
        trilhas.tap()
        let progresso = app.staticTexts["trilha.aprendiz.progresso"]
        XCTAssertTrue(progresso.waitForExistence(timeout: 5))
        app.buttons["trilha.aprendiz.etapas"].tap()
        let marcar = app.buttons["trilha.etapa.aprendiz_iniciacao.marcar"]
        if marcar.label.hasPrefix("Desmarcar") { marcar.tap() }
        XCTAssertEqual(progresso.label, "0 de 10 etapas (0%)")
        marcar.tap()
        XCTAssertTrue(progresso.wait(for: \.label, toEqual: "1 de 10 etapas (10%)", timeout: 5), progresso.label)
        XCTAssertTrue(app.staticTexts["trilha.aprendiz.marco"].exists)
        marcar.tap()
        XCTAssertTrue(progresso.wait(for: \.label, toEqual: "0 de 10 etapas (0%)", timeout: 5), progresso.label)
        app.buttons["trilha.etapa.aprendiz_pedra_bruta.estudar"].tap()
        XCTAssertTrue(app.navigationBars["Dossiê"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["dossier.results"].firstMatch.waitForExistence(timeout: 30))
    }

    /// Store screenshots (Paridade/PUBLICACAO_LOJAS.md), only when asked:
    /// `TEST_RUNNER_CAPTURAS=1 xcodebuild test ...` (Tools/gerar_capturas_lojas.sh).
    @MainActor
    func testStoreScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAPTURAS"] == "1", "Only for the store screenshots")
        func capturar(_ nome: String) {
            sleep(2)
            let anexo = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            anexo.name = "loja-\(nome)"
            anexo.lifetime = .keepAlways
            add(anexo)
        }
        func reabrir() {
            app.terminate()
            app.launch()
            XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 12))
        }
        func abrirNoMais(_ tela: String, aguardar marca: XCUIElement) {
            reabrir()
            navigationTab("Mais").tap()
            let botao = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", tela)).firstMatch
            XCTAssertTrue(botao.waitForExistence(timeout: 5))
            for _ in 0..<4 where !botao.isHittable { app.swipeUp(velocity: .slow) }
            botao.tap()
            XCTAssertTrue(marca.waitForExistence(timeout: 20), tela)
        }
        capturar("01-inicio")

        app.buttons["Abrir leitura diária de Breviário Maçônico - Kennyo Ismail"].tap()
        XCTAssertTrue(app.buttons["Tela cheia"].firstMatch.waitForExistence(timeout: 8))
        capturar("02-leitura")

        reabrir()
        navigationTab("Coleções").tap()
        XCTAssertTrue(app.buttons["Ver todas as leituras"].firstMatch.waitForExistence(timeout: 30))
        // The collections are shown when every work is scored, not while they load.
        _ = app.staticTexts["Preparando coleções"].waitForNonExistence(timeout: 120)
        capturar("03-colecoes")

        reabrir()
        navigationTab("Dossiê").tap()
        let topic = app.descendants(matching: .any).matching(identifier: "dossier.topic").firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        let apagar = app.buttons.matching(identifier: "dossier.saved.delete").firstMatch
        while apagar.exists { apagar.tap() }
        for _ in 0..<3 where (topic.value(forKey: "hasKeyboardFocus") as? Bool) != true {
            topic.tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        }
        topic.typeText("Acácia\n")
        XCTAssertTrue(app.otherElements["dossier.results"].firstMatch.waitForExistence(timeout: 30))
        let salvar = app.buttons["dossier.save"].firstMatch
        for _ in 0..<6 where !salvar.isHittable { app.swipeUp(velocity: .slow) }
        salvar.tap()
        // The analysis of the dossier (definition, summary with sources) fills the screen.
        let definicao = app.staticTexts["Definição"].firstMatch
        for _ in 0..<6 where !definicao.isHittable { app.swipeUp(velocity: .slow) }
        app.swipeUp(velocity: .slow)
        capturar("04-dossie")
        let prancha = app.buttons["dossier.prancha"].firstMatch
        let copiarPrancha = app.buttons["prancha.copiar"]
        // The floating tab bar covers the bottom of the screen: the button is brought to the middle first.
        for _ in 0..<4 where !copiarPrancha.exists {
            for _ in 0..<6 where !prancha.isHittable || prancha.frame.maxY > app.frame.height * 0.75 {
                app.swipeDown(velocity: .slow)
            }
            prancha.tap()
            _ = copiarPrancha.waitForExistence(timeout: 10)
        }
        XCTAssertTrue(copiarPrancha.exists)
        capturar("05-prancha")

        abrirNoMais("Trilhas por grau", aguardar: app.staticTexts["trilha.aprendiz.progresso"])
        capturar("06-trilhas")

        abrirNoMais("Caderno de estudo", aguardar: app.descendants(matching: .any)["notebook.theme.search"])
        capturar("07-caderno")

        reabrir()
        navigationTab("Acervo").tap()
        sleep(3)
        capturar("08-acervo")
    }

    /// The prancha of a dossier shows each author side by side and the text with ABNT references. Same as Android.
    func testDossierBuildsPranchaWithReferences() {
        navigationTab("Dossiê").tap()
        let topic = app.descendants(matching: .any).matching(identifier: "dossier.topic").firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        for _ in 0..<3 where (topic.value(forKey: "hasKeyboardFocus") as? Bool) != true {
            topic.tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        }
        topic.typeText("virtude")
        app.buttons["Montar dossiê"].tap()
        XCTAssertTrue(app.otherElements["dossier.results"].firstMatch.waitForExistence(timeout: 20))
        let prancha = app.buttons["dossier.prancha"].firstMatch
        for _ in 0..<6 where !prancha.isHittable { app.swipeUp(velocity: .slow) }
        prancha.tap()
        // The text and the side-by-side authors are checked by the reference cases; the long prancha makes
        // text queries slow for XCUITest, so only its actions are driven here.
        let copiar = app.buttons["prancha.copiar"]
        XCTAssertTrue(copiar.waitForExistence(timeout: 20))
        copiar.tap()
        XCTAssertTrue(copiar.wait(for: \.label, toEqual: "Prancha copiada.", timeout: 10), copiar.label)
        app.buttons["Fechar"].tap()
        XCTAssertTrue(prancha.waitForExistence(timeout: 5))
    }

    /// A saved dossier appears as a theme of the notebook; its note opens the dossier again. Same as Android.
    func testNotebookByThemeListsSavedDossierAndOpensIt() {
        navigationTab("Dossiê").tap()
        let topic = app.descendants(matching: .any).matching(identifier: "dossier.topic").firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        let apagar = app.buttons.matching(identifier: "dossier.saved.delete").firstMatch
        while apagar.exists { apagar.tap() }
        topic.tap()
        topic.typeText("virtude")
        app.buttons["Montar dossiê"].tap()
        XCTAssertTrue(app.otherElements["dossier.results"].firstMatch.waitForExistence(timeout: 20))
        let salvar = app.buttons["dossier.save"].firstMatch
        for _ in 0..<6 where !salvar.isHittable { app.swipeUp(velocity: .slow) }
        salvar.tap()
        XCTAssertTrue(app.buttons["Dossiê salvo"].waitForExistence(timeout: 5))

        // The saved dossier stays after the app is reopened, which also leaves the dossier field and its keyboard.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 12))
        navigationTab("Mais").tap()
        XCTAssertTrue(app.navigationBars["Recursos avançados"].waitForExistence(timeout: 5))
        let caderno = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Caderno de estudo")).firstMatch
        XCTAssertTrue(caderno.waitForExistence(timeout: 5))
        for _ in 0..<4 where !caderno.isHittable { app.swipeUp(velocity: .slow) }
        caderno.tap()
        let tema = app.buttons["notebook.theme.virtude"]
        XCTAssertTrue(tema.waitForExistence(timeout: 10))
        tema.tap()
        let busca = app.textFields["notebook.theme.search"]
        XCTAssertEqual(busca.value as? String, "virtude")
        let nota = app.buttons.matching(identifier: "notebook.note").firstMatch
        XCTAssertTrue(nota.waitForExistence(timeout: 5))
        XCTAssertTrue(nota.label.hasPrefix("Dossiê — virtude"), nota.label)
        nota.tap()
        XCTAssertTrue(app.navigationBars["Dossiê"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["dossier.results"].firstMatch.waitForExistence(timeout: 20))

        for _ in 0..<40 where !apagar.isHittable { app.swipeUp(velocity: .slow) }
        apagar.tap()
    }

    /// Save, mark a review, leave, reopen from the saved list and delete, as on Android.
    func testSavedDossierKeepsReviewsReopensAndCanBeDeleted() {
        navigationTab("Dossiê").tap()
        let topic = app.descendants(matching: .any).matching(identifier: "dossier.topic").firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        let apagar = app.buttons.matching(identifier: "dossier.saved.delete").firstMatch
        while apagar.exists { apagar.tap() }

        topic.tap()
        topic.typeText("virtude")
        app.buttons["Montar dossiê"].tap()
        XCTAssertTrue(app.otherElements["dossier.results"].firstMatch.waitForExistence(timeout: 20))
        let salvar = app.buttons["dossier.save"].firstMatch
        for _ in 0..<6 where !salvar.isHittable { app.swipeUp(velocity: .slow) }
        salvar.tap()
        XCTAssertTrue(app.buttons["Dossiê salvo"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["dossier.save"].isEnabled)

        let revisao = app.buttons["dossier.review.0"].firstMatch
        for _ in 0..<30 where !revisao.isHittable { app.swipeUp(velocity: .slow) }
        revisao.tap()
        XCTAssertEqual(app.buttons["dossier.review.0"].value as? String, "Feita")
        let mapa = app.otherElements["dossier.map"].firstMatch
        XCTAssertTrue(mapa.exists)
        for _ in 0..<6 where !mapa.isHittable { app.swipeUp(velocity: .slow) }
        let captura = XCTAttachment(screenshot: app.screenshot())
        captura.name = "dossier-map"
        captura.lifetime = .keepAlways
        add(captura)

        // Another topic is not the saved dossier any more.
        for _ in 0..<40 where !topic.isHittable { app.swipeDown(velocity: .fast) }
        topic.tap()
        topic.typeText(" adicional")
        XCTAssertTrue(app.buttons["dossier.review.0"].waitForNonExistence(timeout: 5))

        let abrir = app.buttons["dossier.saved.open"].firstMatch
        for _ in 0..<6 where !abrir.isHittable { app.swipeUp(velocity: .slow) }
        abrir.tap()
        XCTAssertTrue(app.otherElements["dossier.results"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertEqual(topic.value as? String, "virtude")
        let reaberta = app.buttons["dossier.review.0"].firstMatch
        for _ in 0..<30 where !reaberta.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertEqual(reaberta.value as? String, "Feita")
        XCTAssertEqual(app.buttons["dossier.review.1"].value as? String, "Pendente")

        for _ in 0..<40 where !apagar.isHittable { app.swipeDown(velocity: .fast) }
        apagar.tap()
        XCTAssertTrue(app.otherElements["dossier.saved"].waitForNonExistence(timeout: 5))
    }

    /// Return builds the dossier instead of adding a line break, and the Search keeps its own topic.
    func testReturnKeyBuildsTheDossierAndKeepsSearchSeparate() {
        navigationTab("Dossiê").tap()
        let topic = app.descendants(matching: .any).matching(identifier: "dossier.topic").firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        topic.tap()
        topic.typeText("virtude\n")
        XCTAssertTrue(app.otherElements["dossier.results"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertEqual(topic.value as? String, "virtude")

        navigationTab("Início").tap()
        app.buttons["Buscar na biblioteca"].tap()
        let query = app.textFields["Buscar"].firstMatch
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        XCTAssertNotEqual(query.value as? String, "virtude", "The Search does not inherit the dossier topic")
    }

    func testMainTabsOpenExpectedScreens() {
        navigationTab("Coleções").tap()
        XCTAssertTrue(app.navigationBars["Coleções"].waitForExistence(timeout: 5))

        navigationTab("Dossiê").tap()
        XCTAssertTrue(app.navigationBars["Dossiê"].waitForExistence(timeout: 5))

        navigationTab("Acervo").tap()
        XCTAssertTrue(navigationTab("Acervo").isSelected)

        navigationTab("Mais").tap()
        XCTAssertTrue(app.navigationBars["Recursos avançados"].waitForExistence(timeout: 5))
    }

    func testDossierInvalidatesPreviousSourcesWhenTopicChanges() {
        navigationTab("Dossiê").tap()
        let topic = app.descendants(matching: .any).matching(identifier: "dossier.topic").firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        topic.tap()
        topic.typeText("virtude")
        app.buttons["Montar dossiê"].tap()
        let result = app.otherElements["dossier.results"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 20))
        topic.tap()
        topic.typeText(" adicional")
        XCTAssertTrue(result.waitForNonExistence(timeout: 5))
    }

    func testDossierShowsTheAnalysisExtractedFromSources() {
        navigationTab("Dossiê").tap()
        let topic = app.descendants(matching: .any).matching(identifier: "dossier.topic").firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        topic.tap()
        topic.typeText("virtude")
        app.buttons["Montar dossiê"].tap()
        XCTAssertTrue(app.otherElements["dossier.results"].firstMatch.waitForExistence(timeout: 20))
        // Every line of the analysis is extracted from the sources and ends with its citation.
        let resumo = app.staticTexts["Resumo com fontes"].firstMatch
        for _ in 0..<10 where !resumo.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(resumo.isHittable)
        XCTAssertTrue(app.staticTexts["Métricas"].firstMatch.exists)
    }

    func testReadingOpenedFromDossierReturnsToTheDossier() {
        navigationTab("Dossiê").tap()
        let topic = app.descendants(matching: .any).matching(identifier: "dossier.topic").firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        topic.tap()
        topic.typeText("virtude")
        app.buttons["Montar dossiê"].tap()
        let source = app.buttons["dossier.source"].firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 20))
        for _ in 0..<10 where !source.isHittable { app.swipeUp(velocity: .slow) }
        source.tap()

        let back = app.buttons["Voltar"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        back.tap()
        XCTAssertTrue(app.navigationBars["Dossiê"].waitForExistence(timeout: 5),
                      "Back must return to the dossier that opened the reading")
        XCTAssertTrue(app.buttons["dossier.source"].firstMatch.exists, "The dossier must keep its sources")
    }

    func testSettingsAndHomeRoundTrip() {
        app.buttons["Configurações"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Configurações"].waitForExistence(timeout: 5))
        navigationTab("Início").tap()
        XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 5))
    }

    func testNotificationTestDoesNotInvokeAdjacentCancelAction() {
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            for title in ["Permitir", "Allow"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        app.buttons["Configurações"].firstMatch.tap()
        let section = app.buttons["Notificação diária"].firstMatch
        for _ in 0..<5 where !section.isHittable { app.swipeUp() }
        XCTAssertTrue(section.isHittable)
        section.tap()
        let send = app.buttons["Enviar teste em 5 segundos"].firstMatch
        for _ in 0..<5 where !send.isHittable { app.swipeUp() }
        XCTAssertTrue(send.isHittable)
        let enabled = app.switches["Ativar notificação"].firstMatch
        let switchControl = enabled.switches.firstMatch
        if enabled.value as? String != "1" { switchControl.tap() }
        defer { if enabled.value as? String == "1" { switchControl.tap() } }
        XCTAssertEqual(enabled.value as? String, "1", "Notification must be enabled before the test action")
        send.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.firstMatch.exists {
            let allow = springboard.alerts.buttons["Allow"].exists
                ? springboard.alerts.buttons["Allow"] : springboard.alerts.buttons["Permitir"]
            if allow.exists { allow.tap() }
        }
        XCTAssertTrue(app.staticTexts["Teste agendado: a notificação será enviada em 5 segundos."].waitForExistence(timeout: 5))
        XCTAssertEqual(enabled.value as? String, "1", "Test must not run the adjacent cancellation action")
    }

    func testStructuredSearchOpensFromHome() {
        app.buttons["Buscar na biblioteca"].tap()
        XCTAssertTrue(app.navigationBars["Busca"].waitForExistence(timeout: 5))
    }

    func testSearchReadingAfterDailyReadingAndRepeatedHomeReturns() {
        app.buttons["Abrir leitura diária de Breviário Maçônico - Kennyo Ismail"].tap()
        XCTAssertTrue(app.buttons["Tela cheia"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["Voltar"].firstMatch.tap()
        for attempt in 0..<3 {
            if attempt == 0 {
                XCTAssertTrue(app.buttons["Buscar na biblioteca"].waitForExistence(timeout: 5))
                app.buttons["Buscar na biblioteca"].tap()
                let query = app.textFields["Buscar"].firstMatch
                XCTAssertTrue(query.waitForExistence(timeout: 5))
                query.tap()
                query.typeText("virtude")
                app.buttons["Buscar"].firstMatch.tap()
            }
            XCTAssertTrue(app.staticTexts["Breviários"].firstMatch.waitForExistence(timeout: 20))
            // Results are a lazy list ordered by relevance; the reading can start below the visible area.
            let result = app.staticTexts["O número Dois"].firstMatch
            for _ in 0..<20 where !(result.exists && result.isHittable) { app.swipeUp(velocity: .slow) }
            XCTAssertTrue(result.waitForExistence(timeout: 5))
            result.tap()
            XCTAssertTrue(app.buttons["Tela cheia"].firstMatch.waitForExistence(timeout: 8))
            XCTAssertTrue(app.staticTexts["Leitura: 02 de fevereiro"].exists)
            app.buttons["Voltar"].firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Busca"].waitForExistence(timeout: 5),
                          "Back must return to the search that opened the reading, keeping its results")
        }
    }

    @MainActor
    func testAccessibilityDescriptionsAndTouchTargets() throws {
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion])
        app.buttons["Buscar na biblioteca"].tap()
        XCTAssertTrue(app.navigationBars["Busca"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion])
    }

    @MainActor
    func testFullAccessibilityHome() throws {
        continueAfterFailure = true
        defer { continueAfterFailure = false }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Home-accessibility-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        try auditAccessibility()
    }

    @MainActor
    func testFullAccessibilityHomeAfterScrolling() throws {
        continueAfterFailure = true
        defer { continueAfterFailure = false }
        app.buttons["Abrir leitura diária de Breviário Maçônico - Kennyo Ismail"].tap()
        XCTAssertTrue(app.buttons["Voltar"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["Voltar"].firstMatch.tap()
        let heading = app.staticTexts["Últimas leituras"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<4 where !heading.isHittable {
            scroll.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(heading.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Home-recent-readings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        try auditAccessibility()
    }

    func testThemeSearchScreensAndReturnNavigation() {
        for theme in ["escuro", "claro", "sepia"] {
            app.terminate()
            app.launchArguments = ["-ui-testing", "-temaApp", theme, "-temaLeitura", theme]
            app.launch()
            XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 12))
            app.buttons["Buscar na biblioteca"].tap()
            XCTAssertTrue(app.navigationBars["Busca"].waitForExistence(timeout: 5))
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Busca-\(theme)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.navigationBars["Busca"].buttons["Mais"].tap()
            XCTAssertTrue(app.navigationBars["Recursos avançados"].waitForExistence(timeout: 5))
            navigationTab("Início").tap()
            XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 5))
        }
    }

    @MainActor
    func testFullAccessibilitySearch() throws {
        app.buttons["Buscar na biblioteca"].tap()
        XCTAssertTrue(app.navigationBars["Busca"].waitForExistence(timeout: 5))
        // On a physical iPhone the system keyboard opens with the field; it is not app content.
        // With the field empty, the keyboard's search key only closes the keyboard.
        let teclaBuscar = app.keyboards.buttons.matching(NSPredicate(format: "label IN %@", ["Buscar", "search", "Search"])).firstMatch
        if teclaBuscar.exists { teclaBuscar.tap() }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
        try auditAccessibility()
    }

    func testSearchMetadataFiltersAtLargestDynamicType() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 12))
        let search = app.buttons["Buscar na biblioteca"]
        for _ in 0..<8 where !search.isHittable { app.swipeUp(velocity: .slow) }
        search.tap()
        XCTAssertTrue(app.navigationBars["Busca"].waitForExistence(timeout: 5))
        for identifier in ["search.author", "search.subject"] {
            let field = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            let label = app.staticTexts["\(identifier).label"]
            let top = app.navigationBars["Busca"].frame.maxY + 8
            let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY - 8 : app.frame.maxY - 90
            for _ in 0..<18 {
                if field.isHittable && label.frame.minY >= top && field.frame.maxY <= bottom { break }
                let scrollDown = label.frame.minY < top
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: scrollDown ? 0.45 : 0.65))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: scrollDown ? 0.65 : 0.45))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            XCTAssertTrue(field.isHittable)
            XCTAssertGreaterThan(field.frame.height, 40)
            XCTAssertGreaterThanOrEqual(field.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(field.frame.maxX, app.frame.maxX)
            XCTAssertGreaterThanOrEqual(label.frame.minY, top)
            XCTAssertLessThanOrEqual(field.frame.maxY, bottom)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "\(identifier)-maior-fonte"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    @MainActor
    func testFullAccessibilitySettings() throws {
        app.buttons["Configurações"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Configurações"].waitForExistence(timeout: 5))
        try auditAccessibility()
    }

    /// The screens of Phases 10 to 12 are audited too, as on Android (AccessibilityAuditTest).
    @MainActor
    func testFullAccessibilityDegreeTracksAndNotebook() throws {
        for tela in ["Trilhas por grau", "Caderno de estudo"] {
            // Reopened between screens, so the Mais tab starts on its menu.
            app.terminate()
            app.launch()
            XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 12))
            navigationTab("Mais").tap()
            let botao = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", tela)).firstMatch
            XCTAssertTrue(botao.waitForExistence(timeout: 5))
            for _ in 0..<4 where !botao.isHittable { app.swipeUp(velocity: .slow) }
            botao.tap()
            XCTAssertTrue(app.staticTexts[tela].firstMatch.waitForExistence(timeout: 10))
            try auditAccessibility()
        }
    }

    @MainActor
    func testFullAccessibilityReading() throws {
        app.buttons["Abrir leitura diária de Breviário Maçônico - Kennyo Ismail"].tap()
        XCTAssertTrue(app.buttons["Tela cheia"].firstMatch.waitForExistence(timeout: 8))
        try auditAccessibility()
    }

    @MainActor
    func testFullAccessibilityCollections() throws {
        navigationTab("Coleções").tap()
        XCTAssertTrue(app.navigationBars["Coleções"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Ver todas as leituras"].firstMatch.waitForExistence(timeout: 20))
        // On iPad the audit's text-size check reports text of this grid that does grow (measured in
        // testCollectionTextGrowsWithTextSize: 18 to 58.5 pt) and times out on it. There the other
        // checks run and text size is covered by that measurement; iPhone runs every check.
        try auditAccessibility(barraDeAbasNoTopo() ? XCUIAccessibilityAuditType.all.subtracting(.dynamicType) : .all)
    }

    func testCollectionsAtLargestDynamicTypeOpenTheCorrectReading() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 12))
        navigationTab("Coleções").tap()
        XCTAssertTrue(app.navigationBars["Coleções"].waitForExistence(timeout: 20))
        // Top reading of the Virtudes collection under the shared rule (most distinct keywords, then occurrences).
        let title = app.staticTexts["DEGRAU"].firstMatch
        for _ in 0..<10 where !title.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(title.isHittable)
        XCTAssertGreaterThan(title.frame.height, 30, "The largest font must actually grow, not just set a launch argument")
        XCTAssertGreaterThanOrEqual(title.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(title.frame.maxX, app.frame.maxX)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Colecoes-maior-fonte"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        title.tap()
        XCTAssertTrue(app.staticTexts["Leitura: 11 de abril"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Voltar"].firstMatch.exists)
        app.buttons["Voltar"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Coleções"].waitForExistence(timeout: 5),
                      "Back must return to the collection that opened the reading")
    }

    func testUnsavedCommentIsKeptWhenChangingReading() {
        let marker = "Rascunho automático \(Int(Date().timeIntervalSince1970))"
        app.buttons["Abrir leitura diária de Breviário Maçônico - Kennyo Ismail"].tap()
        XCTAssertTrue(app.buttons["Próximo dia"].firstMatch.waitForExistence(timeout: 8))
        let comment = app.textViews["reading.comment"]
        for _ in 0..<12 where !comment.isHittable { app.swipeUp(velocity: .slow) }
        comment.tap()
        comment.typeText(marker)

        app.buttons["Próximo dia"].firstMatch.tap()
        app.buttons["Dia anterior"].firstMatch.tap()
        let reopened = app.textViews["reading.comment"]
        for _ in 0..<12 where !reopened.isHittable { app.swipeUp(velocity: .slow) }
        let value = reopened.value as? String ?? ""
        XCTAssertTrue(value.contains(marker), "Unsaved comment was discarded when changing reading")

        // Leave the reading as it was before the test.
        reopened.tap()
        reopened.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: marker.count))
        app.buttons["Voltar"].firstMatch.tap()
    }

    @MainActor
    func testFullAccessibilityDossier() throws {
        navigationTab("Dossiê").tap()
        XCTAssertTrue(app.navigationBars["Dossiê"].waitForExistence(timeout: 5))
        try auditAccessibility()
    }

    func testStudyPathAtLargestDynamicTypePreservesDetails() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 12))
        navigationTab("Coleções").tap()
        XCTAssertTrue(app.buttons["Ver todas as leituras"].firstMatch.waitForExistence(timeout: 20))
        let instruction = app.staticTexts["Base simbólica"].firstMatch
        for _ in 0..<55 where !instruction.isHittable { app.swipeUp() }
        XCTAssertTrue(instruction.isHittable)
        for text in ["Base simbólica", "10 dias", "Símbolos, acácia e construção moral"] {
            let label = app.staticTexts[text].firstMatch
            for _ in 0..<5 where !label.isHittable { app.swipeUp(velocity: .slow) }
            XCTAssertTrue(label.isHittable)
            XCTAssertGreaterThan(label.frame.height, 25)
            XCTAssertGreaterThanOrEqual(label.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(label.frame.maxX, app.frame.maxX)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Trilha-maior-fonte"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testContrastIndependentOfOtherAudits() throws {
        continueAfterFailure = true
        defer { continueAfterFailure = false }
        try auditAccessibility(.contrast)
        app.buttons["Buscar na biblioteca"].tap()
        XCTAssertTrue(app.navigationBars["Busca"].waitForExistence(timeout: 5))
        try auditAccessibility(.contrast)
        navigationTab("Dossiê").tap()
        XCTAssertTrue(app.navigationBars["Dossiê"].waitForExistence(timeout: 5))
        try auditAccessibility(.contrast)
    }

    func testDailyReadingOpensAndReturnsHome() {
        for _ in 0..<3 {
            let dailyReading = app.buttons["Abrir leitura diária de Breviário Maçônico - Kennyo Ismail"]
            XCTAssertTrue(dailyReading.waitForExistence(timeout: 5))
            dailyReading.tap()
            let back = app.buttons["Voltar"]
            XCTAssertTrue(back.waitForExistence(timeout: 8))
            back.tap()
            XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 5))
        }
    }

    func testFullscreenReadingCanCloseWithoutLosingNavigation() {
        app.buttons["Abrir leitura diária de Breviário Maçônico - Kennyo Ismail"].tap()
        let expand = app.buttons["Tela cheia"].firstMatch
        XCTAssertTrue(expand.waitForExistence(timeout: 8))
        expand.tap()
        let close = app.buttons["Fechar tela cheia"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        close.tap()
        let back = app.buttons["Voltar"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 5))
    }

    func testNativeHighlightSelectionWorksInFullscreen() {
        app.buttons["Abrir leitura diária de Breviário Maçônico - Kennyo Ismail"].tap()
        XCTAssertTrue(app.buttons["Tela cheia"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["Tela cheia"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Fechar tela cheia"].waitForExistence(timeout: 5))
        let text = app.textViews.firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.02)).press(forDuration: 1.2)
        let highlight = app.descendants(matching: .any).matching(identifier: "Destacar").firstMatch
        XCTAssertTrue(highlight.waitForExistence(timeout: 8))
        highlight.tap()
        let confirmation = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Marcador salvo:")).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.contains(confirmation.frame), "The saving confirmation must remain inside the visible screen")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Destaque-tela-cheia"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Fechar tela cheia"].tap()
        XCTAssertTrue(app.buttons["Tela cheia"].firstMatch.waitForExistence(timeout: 5))
    }

    func testDailyReadingCardAcceptsTapsAcrossItsSurface() {
        for position in [CGVector(dx: 0.5, dy: 0.5), CGVector(dx: 0.03, dy: 0.5), CGVector(dx: 0.97, dy: 0.5)] {
            let card = app.buttons["Abrir leitura diária de Breviário Maçônico - Kennyo Ismail"]
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            XCTAssertTrue(card.isHittable)
            card.coordinate(withNormalizedOffset: position).tap()
            XCTAssertTrue(app.buttons["Tela cheia"].firstMatch.waitForExistence(timeout: 8))
            app.buttons["Voltar"].firstMatch.tap()
            XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 5))
        }
    }

    func testRapidTabSwitchingRemainsStable() {
        for _ in 0..<3 {
            navigationTab("Coleções").tap()
            navigationTab("Dossiê").tap()
            navigationTab("Acervo").tap()
            navigationTab("Mais").tap()
            navigationTab("Início").tap()
        }
        XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 5))
    }

    func testBackgroundAndForegroundKeepsNavigationAvailable() {
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 8))
        XCTAssertTrue(navigationTab("Acervo").exists)
    }

    func testRepeatedSettingsRoundTripsRemainStable() {
        for _ in 0..<3 {
            app.buttons["Configurações"].firstMatch.tap()
            XCTAssertTrue(app.navigationBars["Configurações"].waitForExistence(timeout: 5))
            navigationTab("Início").tap()
            XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 5))
        }
    }

    /// Collection text grows with the system text size: a card title, the topics row and a reading
    /// title. Measured because the iPad accessibility audit reports this text as "partially
    /// unsupported" although it grows (Phase 7 report).
    func testCollectionTextGrowsWithTextSize() {
        var alturas: [String: [CGFloat]] = [:]
        for tamanho in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            app.terminate()
            app.launchArguments = ["-ui-testing", "-UIPreferredContentSizeCategoryName", tamanho]
            app.launch()
            XCTAssertTrue(app.staticTexts["Biblioteca Maçônica"].waitForExistence(timeout: 12))
            navigationTab("Coleções").tap()
            let alvos = [
                ("título do cartão", app.staticTexts["Ética"].firstMatch),
                ("tópicos", app.descendants(matching: .any).matching(identifier: "study.topics.etica").firstMatch),
                ("título da leitura", app.staticTexts["A Justiça"].firstMatch)
            ]
            for (nome, alvo) in alvos {
                for _ in 0..<25 where !(alvo.exists && alvo.isHittable) { app.swipeUp(velocity: .slow) }
                XCTAssertTrue(alvo.isHittable, nome)
                alturas[nome, default: []].append(alvo.frame.height)
            }
        }
        for (nome, medidas) in alturas {
            // At the largest size the grid becomes one wider column, so more chips fit on each line
            // and the topics row grows less than its text (iPad: 55 to 129 pt).
            let minimo: CGFloat = nome == "tópicos" ? 2.0 : 2.5
            XCTAssertGreaterThanOrEqual(medidas[1], medidas[0] * minimo, "\(nome): \(medidas)")
        }
    }

    /// Each work in the offline collection shows its text quality, as on Android (Phase 8).
    func testOfflineCollectionShowsTextQuality() {
        navigationTab("Mais").tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Acervo offline")).firstMatch.tap()
        let busca = app.descendants(matching: .any).matching(identifier: "acervo.busca").firstMatch
        XCTAssertTrue(busca.waitForExistence(timeout: 10))
        // The list below reloads as the screen appears; tap again until the field has focus.
        for _ in 0..<3 where (busca.value(forKey: "hasKeyboardFocus") as? Bool) != true {
            busca.tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        }
        busca.typeText("Boletim GOB")
        XCTAssertTrue(app.staticTexts["Texto com muito ruído"].firstMatch.waitForExistence(timeout: 10))
    }
}
