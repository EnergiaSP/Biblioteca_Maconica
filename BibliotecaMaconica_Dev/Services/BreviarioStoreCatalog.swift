import Foundation

@MainActor
extension BreviarioStore {
    nonisolated static func carregarItensRecentesParaResumo(
        obra: BibliotecaObra,
        referencias: [String],
        catalogo: BibliotecaRAGCatalogService? = nil
    ) throws -> [BreviarioItem] {
        guard !referencias.isEmpty else { return [] }
        if obra.recursoJSON != nil || urlImportadoExistente(obraID: obra.id) != nil {
            let selecionadas = Set(referencias)
            return try carregarItensDaObra(obra).filter { selecionadas.contains($0.data) }
        }
        let paginas = referencias.compactMap { referencia -> Int? in
            guard referencia.hasPrefix("P"), let pagina = Int(referencia.dropFirst()), pagina > 0 else { return nil }
            return pagina
        }
        guard !paginas.isEmpty else { return [] }
        let catalogo = try catalogo ?? BibliotecaRAGCatalogService()
        return catalogo.carregarItens(obraID: obra.id, paginas: paginas)
    }

func atualizarCatalogo() {
        tarefaCatalogo?.cancel()
        let obrasAtivas = obras.filter(\.ativa)

        tarefaCatalogo = Task { @MainActor in
            let totais = await Task.detached(priority: .utility) {
                var parcial = (try? BibliotecaRAGCatalogService().totaisPorObra()) ?? [:]
                for obra in obrasAtivas {
                    if obra.recursoJSON != nil || Self.urlImportadoExistente(obraID: obra.id) != nil {
                        parcial[obra.id] = ((try? Self.carregarItensDaObra(obra)) ?? []).count
                    } else {
                        parcial[obra.id] = parcial[obra.id] ?? 0
                    }
                }
                return parcial
            }.value

            guard Task.isCancelled == false else {
                return
            }

            totalItensPorObra = totais
            tarefaCatalogo = nil
        }
    }

    func carregarObraRAG(obraID: String) {
        tarefaCarregamento?.cancel()
        importando = false
        carregando = true
        itens = []
        indiceRemissivo = []
        erro = nil

        tarefaCarregamento = Task {
            let itensCarregados = await Task.detached(priority: .userInitiated) {
                (try? BibliotecaRAGCatalogService().carregarItens(obraID: obraID)) ?? []
            }.value

            guard Task.isCancelled == false else {
                return
            }

            if itensCarregados.isEmpty {
                erro = "Esta obra ainda não está disponível offline. Abra Acervo offline e toque em baixar para liberar a leitura e a busca."
            } else {
                itens = itensCarregados
                indiceRemissivo = []
                atualizarSnapshotCompartilhado()
                erro = nil
            }

            carregando = false
            tarefaCarregamento = nil
        }
    }

    func urlImportado(obraID: String) -> URL? {
        Self.urlImportadoExistente(obraID: obraID)
    }

    nonisolated static func urlImportadoExistente(obraID: String) -> URL? {
        let url = try? criarURLImportado(obraID: obraID)
        guard let url, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return url
    }

    nonisolated static func criarURLImportado(obraID: String) throws -> URL {
        let pasta = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(pastaDados, isDirectory: true)

        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        if obraID == ObraID.breviarioSeculoXXI {
            return pasta.appendingPathComponent("breviario-importado.json")
        }

        return pasta.appendingPathComponent("obra-\(obraID)-importada.json")
    }

    nonisolated static func urlSolicitacoesInclusao() throws -> URL {
        let pasta = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(pastaDados, isDirectory: true)

        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        return pasta.appendingPathComponent("solicitacoes-inclusao-obras.json")
    }

    nonisolated static func urlFontesOficiais() throws -> URL {
        let pasta = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(pastaDados, isDirectory: true)

        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        return pasta.appendingPathComponent(arquivoFontesOficiais)
    }

    nonisolated static func carregarFontesOficiaisSalvas() throws -> [FonteOficialMaconica] {
        let url = try urlFontesOficiais()
        guard FileManager.default.fileExists(atPath: url.path) else {
            guard let dadosBackup = UserDefaults.standard.data(forKey: "backup_fontes_oficiais") else {
                return fontesOficiaisPadrao()
            }
            let fontes = try JSONDecoder().decode([FonteOficialMaconica].self, from: dadosBackup)
            try dadosBackup.write(to: url, options: .atomic)
            return fontes.isEmpty ? fontesOficiaisPadrao() : fontes
        }

        let dados = try Data(contentsOf: url)
        let fontes = try JSONDecoder().decode([FonteOficialMaconica].self, from: dados)
        return fontes.isEmpty ? fontesOficiaisPadrao() : fontes
    }

    nonisolated static func urlCatalogoObras() throws -> URL {
        let pasta = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(pastaDados, isDirectory: true)

        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        return pasta.appendingPathComponent(arquivoCatalogoObras)
    }

    nonisolated static func carregarObrasDoCatalogo() -> [BibliotecaObra] {
        let personalizadas = (try? carregarObrasPersonalizadas()) ?? []
        let obrasRAG = (try? BibliotecaRAGCatalogService().obras()) ?? []
        var ids = Set<String>()
        return (BibliotecaObra.padroes + personalizadas + obrasRAG).filter { obra in
            guard ids.contains(obra.id) == false else {
                return false
            }
            ids.insert(obra.id)
            return true
        }
    }

    nonisolated static func carregarObrasPersonalizadas() throws -> [BibliotecaObra] {
        let url = try urlCatalogoObras()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let dados = try Data(contentsOf: url)
        return try JSONDecoder().decode([BibliotecaObra].self, from: dados)
    }

    nonisolated static func salvarObrasPersonalizadas(_ obras: [BibliotecaObra]) throws {
        let dados = try JSONEncoder().encode(obras)
        try dados.write(to: urlCatalogoObras(), options: .atomic)
    }

    nonisolated static func criarIDObra(titulo: String) -> String {
        let base = titulo
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { parcial, caractere in
                if caractere == "-", parcial.last == "-" {
                    return
                }
                parcial.append(caractere)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        let sufixo = UUID().uuidString.lowercased()
        return "obra_\(base.isEmpty ? "importada" : String(base.prefix(40)))_\(sufixo)"
    }

    nonisolated static func contextoBusca(termo: String, em texto: String) -> String {
        let textoLimpo = texto
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")

        guard let range = textoLimpo.range(of: termo, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return String(textoLimpo.prefix(220))
        }

        let inicio = textoLimpo.index(range.lowerBound, offsetBy: -90, limitedBy: textoLimpo.startIndex) ?? textoLimpo.startIndex
        let fim = textoLimpo.index(range.upperBound, offsetBy: 160, limitedBy: textoLimpo.endIndex) ?? textoLimpo.endIndex
        let prefixo = inicio == textoLimpo.startIndex ? "" : "..."
        let sufixo = fim == textoLimpo.endIndex ? "" : "..."
        return prefixo + String(textoLimpo[inicio..<fim]) + sufixo
    }

    nonisolated static func termosRelacionados(
        termo: String,
        resultados: [BibliotecaResultadoBusca]
    ) -> [String] {
        let proibidos = Set(
            [
                termo.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased(),
                "para", "com", "uma", "das", "dos", "que", "por", "como", "mais", "seu", "sua",
                "este", "esta", "esse", "essa", "pela", "pelo", "ser", "sao", "são", "aos", "nas",
                "nos", "ao", "as", "os", "de", "da", "do", "em", "no", "na", "um"
            ]
        )

        var contagem: [String: Int] = [:]
        let separadores = CharacterSet.alphanumerics.inverted

        for resultado in resultados {
            let texto = resultado.item.texto

            let palavras = texto
                .components(separatedBy: separadores)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count >= 4 }

            for palavra in palavras {
                let chave = palavra
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
                    .lowercased()

                guard proibidos.contains(chave) == false else {
                    continue
                }

                contagem[palavra.lowercased(with: Locale(identifier: "pt_BR")), default: 0] += 1
            }
        }

        return contagem
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }

                return $0.value > $1.value
            }
            .prefix(12)
            .map(\.key)
    }

    nonisolated static func roteiroEstudo(
        termo: String,
        resultados: [BibliotecaResultadoBusca]
    ) -> [String] {
        guard resultados.isEmpty == false else {
            return [
                "Refinar o termo pesquisado com uma palavra mais específica.",
                "Selecionar uma área ou obra antes de repetir a busca.",
                "Registrar quais termos próximos devem entrar no índice de estudo."
            ]
        }

        return [
            "Ler primeiro as ocorrências do termo \(termo) nas obras com maior recorrência.",
            "Separar trechos literais, comentários pessoais e dúvidas em blocos diferentes.",
            "Comparar o mesmo termo entre breviários, dicionários, obras jurídicas e livros.",
            "Marcar os trechos centrais como favoritos para revisão espaçada.",
            "Escrever uma síntese final citando a obra e a referência de cada trecho."
        ]
    }

    nonisolated static func perguntasFixacao(
        termo: String,
        resultados: [BibliotecaResultadoBusca]
    ) -> [String] {
        [
            "Como o termo \(termo) aparece nas diferentes obras consultadas?",
            "Há diferença entre sentido simbólico, histórico, jurídico e prático?",
            "Quais trechos devem ser citados em um trabalho ou instrução?",
            resultados.count > 1
                ? "Quais obras concordam entre si e quais exigem leitura complementar?"
                : "Qual obra complementar deve ser importada para ampliar a análise?"
        ]
    }

    nonisolated static func mapaConceitual(
        termo: String,
        resultados: [BibliotecaResultadoBusca],
        termosRelacionados: [String]
    ) -> [String] {
        let areas = Set(resultados.map { $0.obra.area.titulo }).sorted()
        let obras = Set(resultados.map { $0.obra.titulo }).sorted()
        var mapa = [
            "\(termo) → obras consultadas: \(obras.isEmpty ? "nenhuma ocorrência encontrada" : obras.prefix(4).joined(separator: ", "))",
            "\(termo) → áreas envolvidas: \(areas.isEmpty ? "refinar busca" : areas.joined(separator: ", "))"
        ]

        if termosRelacionados.isEmpty == false {
            mapa.append("\(termo) → termos relacionados: \(termosRelacionados.prefix(8).joined(separator: ", "))")
        }

        mapa.append("\(termo) → síntese pessoal: registrar entendimento com referência à obra e à página/leitura.")
        return mapa
    }

    nonisolated static func revisaoEspacada(termo: String) -> [String] {
        [
            "Hoje: ler as principais referências de \(termo) e destacar trechos centrais.",
            "Em 1 dia: reler os destaques e escrever uma síntese de cinco linhas.",
            "Em 3 dias: responder às perguntas de fixação sem consultar o texto.",
            "Em 7 dias: comparar o tema com outro termo relacionado do índice.",
            "Em 21 dias: revisar a síntese e transformar em estudo, prancha ou anotação final."
        ]
    }

    nonisolated static func cruzamentosEstudo(resultados: [BibliotecaResultadoBusca]) -> [String] {
        guard resultados.isEmpty == false else {
            return [
                "Sem ocorrências suficientes para cruzamento entre obras.",
                "Importe novas obras ou refine o termo para ampliar o estudo comparado."
            ]
        }

        let porArea = Dictionary(grouping: resultados, by: { $0.obra.area })
        var cruzamentos = porArea
            .sorted { $0.key.titulo.localizedCaseInsensitiveCompare($1.key.titulo) == .orderedAscending }
            .map { area, resultadosArea in
                let obras = Set(resultadosArea.map(\.obra.titulo)).sorted()
                return "\(area.titulo): \(resultadosArea.count) ocorrência(s) em \(obras.prefix(4).joined(separator: ", "))"
            }

        cruzamentos.append("Conferir concordâncias, diferenças de contexto e limites antes de transformar em trabalho escrito.")
        return Array(cruzamentos.prefix(10))
    }

    nonisolated static func limitesDaBase(resultados: [BibliotecaResultadoBusca]) -> [String] {
        guard resultados.isEmpty == false else {
            return [
                "Nenhuma referência textual foi encontrada no acervo local para sustentar conclusão.",
                "A análise deve informar ausência de base e sugerir nova importação ou fonte oficial."
            ]
        }

        let obras = Set(resultados.map(\.obra.id)).count
        let areas = Set(resultados.map(\.obra.area)).count
        var limites = [
            "Conclusões devem citar somente os \(resultados.count) trecho(s) localizado(s) no acervo.",
            "Não usar fontes externas sem cadastro prévio como fonte oficial."
        ]

        if obras == 1 {
            limites.append("Há somente uma obra envolvida; tratar a leitura como referência localizada, não como consenso amplo.")
        }

        if areas == 1 {
            limites.append("Há somente uma área envolvida; estudo cruzado depende de importação ou busca em outras áreas.")
        }

        return limites
    }

    nonisolated static func fontesOficiaisPadrao() -> [FonteOficialMaconica] {
        [
            FonteOficialMaconica(
                titulo: "Grande Oriente do Brasil",
                origem: "Potência maçônica regular",
                url: "https://www.gob.org.br",
                observacao: "Usar apenas conteúdos institucionais oficiais e publicamente verificáveis."
            ),
            FonteOficialMaconica(
                titulo: "CMSB",
                origem: "Confederação da Maçonaria Simbólica do Brasil",
                url: "https://cmsb.org.br",
                observacao: "Referência institucional para consulta complementar quando aplicável."
            ),
            FonteOficialMaconica(
                titulo: "COMAB",
                origem: "Confederação Maçônica do Brasil",
                url: "https://comab.org.br",
                observacao: "Usar somente páginas institucionais oficiais."
            )
        ]
    }

    enum ImportError: Error {
        case semItens
    }

    enum CatalogoError: Error {
        case tituloObrigatorio
    }

    static let formatoData: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter
    }()
}
