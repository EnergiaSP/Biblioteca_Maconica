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
        let visivel = areaVisivel()
        try app.performAccessibilityAudit(for: types) { issue in
            let element = issue.element
            let details = """
            \(issue.compactDescription)
            \(issue.detailedDescription)
            Label: \(element?.label ?? "<none>")
            Identifier: \(element?.identifier ?? "<none>")
            Frame: \(String(describing: element?.frame))
            Hittable: \(element?.isHittable ?? false)
            App frame: \(self.app.frame)
            """
            let attachment = XCTAttachment(string: details)
            attachment.name = "Accessibility-issue-details"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            print("ACCESSIBILITY_DIAGNOSTIC: \(details)")
            // Any kind of issue on an element hidden by a bar or cut by the edge (the taller iPhone
            // Pro Max also reported text size there) is checked again with the element in view.
            if let element, !element.label.isEmpty, !visivel.contains(element.frame) {
                cobertos.append((element.label, element.frame, issue.auditType))
                return true
            }
            return false
        }
        var verificados = Set<String>()
        for coberto in cobertos where verificados.insert("\(coberto.label)|\(coberto.tipo.rawValue)").inserted {
            try verificarContrasteVisivel(label: coberto.label, frameOriginal: coberto.frame, tipo: coberto.tipo)
        }
    }

    /// Screen area not covered by the tab bar. On iOS 26 the floating bar is not exposed as a tab bar,
    /// so its top comes from the Home tab button, less the capsule and the scroll edge band above it.
    private func areaVisivel() -> CGRect {
        let aba = navigationTab("Início")
        let limite = aba.exists ? aba.frame.minY - 16 : app.frame.maxY
        return CGRect(x: app.frame.minX, y: app.frame.minY, width: app.frame.width, height: limite - app.frame.minY)
    }

    /// Scrolls the element fully into view and audits contrast again; failing there is a real failure.
    private func verificarContrasteVisivel(label: String, frameOriginal: CGRect,
                                           tipo: XCUIAccessibilityAuditType = .contrast) throws {
        let alvo = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        guard alvo.exists else {
            XCTFail("Elemento com contraste acusado sumiu antes da verificação: \(label)")
            return
        }
        for _ in 0..<6 where !areaVisivel().contains(alvo.frame) {
            let area = areaVisivel()
            // Vertical position first: a carousel can only be swiped while its row is on screen.
            if alvo.frame.maxY > area.maxY {
                app.swipeUp(velocity: .slow)
            } else if alvo.frame.minY < area.minY {
                app.swipeDown(velocity: .slow)
            } else {
                // Horizontal carousels: swipe the smallest scroll view that holds the element.
                let carrossel = app.scrollViews.containing(NSPredicate(format: "label == %@", label))
                    .allElementsBoundByIndex.filter { $0.frame.height < area.height / 2 && area.intersects($0.frame) }
                    .min { $0.frame.height < $1.frame.height }
                guard let carrossel else {
                    XCTFail("Carrossel de \(label) não encontrado; frame \(alvo.frame)")
                    return
                }
                if alvo.frame.maxX > area.maxX { carrossel.swipeLeft() } else { carrossel.swipeRight() }
            }
        }
        guard areaVisivel().contains(alvo.frame) else {
            XCTFail("Não foi possível trazer para a área visível: \(label) \(alvo.frame) em \(areaVisivel())")
            return
        }
        let frame = alvo.frame
        try app.performAccessibilityAudit(for: tipo) { issue in
            guard issue.element?.label == label, issue.element?.frame == frame else { return true }
            let attachment = XCTAttachment(string: "Contraste reprovado com o elemento visível: \(label) \(frame)")
            attachment.name = "Accessibility-visible-contrast"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            return false
        }
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

    @MainActor
    func testFullAccessibilityReading() throws {
        app.buttons["Abrir leitura diária de Breviário Maçônico - Kennyo Ismail"].tap()
        XCTAssertTrue(app.buttons["Tela cheia"].firstMatch.waitForExistence(timeout: 8))
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testFullAccessibilityCollections() throws {
        navigationTab("Coleções").tap()
        XCTAssertTrue(app.navigationBars["Coleções"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Ver todas as leituras"].firstMatch.waitForExistence(timeout: 20))
        try auditAccessibility()
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
}
