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

    private func navigationTab(_ title: String) -> XCUIElement {
        let compactTab = app.tabBars.buttons[title]
        if compactTab.exists { return compactTab }
        // iPadOS exposes its floating tab bar without an XCUI TabBar ancestor.
        return app.buttons[title].firstMatch
    }

    @MainActor
    private func auditAccessibility(_ types: XCUIAccessibilityAuditType = .all) throws {
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
            // Record evidence without accepting or suppressing any audit failure.
            return false
        }
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
            XCTAssertTrue(app.buttons["Buscar na biblioteca"].waitForExistence(timeout: 5))
            app.buttons["Buscar na biblioteca"].tap()
            if attempt == 0 {
                let query = app.textFields["Buscar"].firstMatch
                XCTAssertTrue(query.waitForExistence(timeout: 5))
                query.tap()
                query.typeText("virtude")
                app.buttons["Buscar"].firstMatch.tap()
            }
            let result = app.staticTexts["O número Dois"].firstMatch
            XCTAssertTrue(result.waitForExistence(timeout: 20))
            result.tap()
            XCTAssertTrue(app.buttons["Tela cheia"].firstMatch.waitForExistence(timeout: 8))
            XCTAssertTrue(app.staticTexts["Leitura: 02 de fevereiro"].exists)
            app.buttons["Voltar"].firstMatch.tap()
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
        try app.performAccessibilityAudit()
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
        let title = app.staticTexts["Adonhiram"].firstMatch
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
        XCTAssertTrue(app.staticTexts["Leitura: 03 de janeiro"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Voltar"].firstMatch.exists)
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
