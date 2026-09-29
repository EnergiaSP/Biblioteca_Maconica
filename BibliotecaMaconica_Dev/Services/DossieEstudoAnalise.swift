import Foundation

/// AI-free study dossier: every output is extracted from the given sources and cites one of them.
/// Mirrors `Tools/dossie_referencia.py`; `casos_dossie_v1.json` holds the golden cases both apps reproduce.
enum DossieEstudoAnalise {
    struct Configuracao: Decodable {
        struct Limites: Decodable {
            let fontesAnalisadas, fontesExibidas, definicoes, resumo, termosAssociados, janelaAssociacao: Int
            let perguntas, divergencias, obrasCentrais, capitulosDedicados: Int
            let tamanhoMinimoFrase, tamanhoMaximoFrase, inicioCapitulo, tamanhoMinimoTermoAssociado: Int
            let tokensChaveDuplicata, tokensMinimosDuplicata, tokensImpressaoDigital: Int
        }
        struct Revisao: Decodable {
            let dias: Int
            let tarefa: String
        }
        let schemaVersion: Int
        let limites: Limites
        let variantes: [String: [String]]
        let verbosDefinicao: [String]
        let marcadoresDivergencia: [String]
        let palavrasVazias: [String]
        let revisao: [Revisao]
        /// Local time of saved-dossier review notifications.
        let lembreteRevisao: Lembrete
        let areas: [String: String]

        struct Lembrete: Decodable {
            let hora: Int
            let minuto: Int
        }

        static let compartilhada: Configuracao? = {
            guard let url = Bundle.main.url(forResource: "estudo_dossie_v1", withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let configuracao = try? JSONDecoder().decode(Configuracao.self, from: dados),
                  configuracao.schemaVersion == 1 else { return nil }
            return configuracao
        }()
    }

    struct Fonte: Codable, Equatable {
        let id: String
        let obraId: String
        let tituloObra: String
        let area: String
        let pagina: Int
        var data: String? = nil
        var texto: String = ""
        var rodape: String = ""
    }

    struct Trecho: Codable, Equatable {
        let texto: String
        let fonte: String
    }

    struct Metricas: Equatable {
        let fontes: Int
        let obras: Int
        let ocorrencias: Int
        let duplicadas: Int
        let frasesComRuido: Int
        let porArea: [(area: String, fontes: Int)]

        static func == (lhs: Metricas, rhs: Metricas) -> Bool {
            lhs.fontes == rhs.fontes && lhs.obras == rhs.obras && lhs.ocorrencias == rhs.ocorrencias && lhs.duplicadas == rhs.duplicadas
                && lhs.frasesComRuido == rhs.frasesComRuido
                && lhs.porArea.elementsEqual(rhs.porArea) { $0.area == $1.area && $0.fontes == $1.fontes }
        }
    }

    struct ObraCentral: Codable, Equatable {
        let obraId: String
        let titulo: String
        let ocorrencias: Int
        let fontes: Int
    }

    struct TermoAssociado: Codable, Equatable {
        let termo: String
        /// Most frequent written form, shown to the reader ("maçom", not "macom").
        let forma: String
        let ocorrencias: Int
        let obras: Int
    }

    struct Pergunta: Codable, Equatable {
        let pergunta: String
        let resposta: String
        let fonte: String
    }

    struct Etapa: Codable, Equatable {
        let etapa: String
        let texto: String
    }

    struct Revisao: Codable, Equatable {
        let data: String
        let tarefa: String
    }

    struct Resultado: Equatable {
        let definicoes: [Trecho]
        let resumo: [Trecho]
        let divergencias: [Trecho]
        let metricas: Metricas
        let obrasCentrais: [ObraCentral]
        let capitulosDedicados: [String]
        let termosAssociados: [TermoAssociado]
        let perguntas: [Pergunta]
        let roteiro: [Etapa]
        let revisao: [Revisao]

        /// Same shape as the golden cases, for comparison and export.
        var json: [String: Any] {
            func trechos(_ lista: [Trecho]) -> [[String: Any]] { lista.map { ["texto": $0.texto, "fonte": $0.fonte] } }
            return [
                "definicoes": trechos(definicoes),
                "resumo": trechos(resumo),
                "divergencias": trechos(divergencias),
                "metricas": ["fontes": metricas.fontes, "obras": metricas.obras, "ocorrencias": metricas.ocorrencias, "duplicadas": metricas.duplicadas,
                             "frasesComRuido": metricas.frasesComRuido,
                             "porArea": metricas.porArea.map { [$0.area, $0.fontes] as [Any] }],
                "obrasCentrais": obrasCentrais.map { ["obraId": $0.obraId, "titulo": $0.titulo, "ocorrencias": $0.ocorrencias, "fontes": $0.fontes] },
                "capitulosDedicados": capitulosDedicados,
                "termosAssociados": termosAssociados.map { ["termo": $0.termo, "forma": $0.forma, "ocorrencias": $0.ocorrencias, "obras": $0.obras] },
                "perguntas": perguntas.map { ["pergunta": $0.pergunta, "resposta": $0.resposta, "fonte": $0.fonte] },
                "roteiro": roteiro.map { ["etapa": $0.etapa, "texto": $0.texto] },
                "revisao": revisao.map { ["data": $0.data, "tarefa": $0.tarefa] }
            ]
        }
    }

    /// Lines shown on screen and in exports, identical on both platforms.
    struct Exibicao: Equatable {
        let definicoes, resumo, divergencias, metricas, obrasCentrais, capitulosDedicados: [String]
        let mapa, perguntas, roteiro, revisao: [String]

        var json: [String: Any] {
            ["definicoes": definicoes, "resumo": resumo, "divergencias": divergencias, "metricas": metricas,
             "obrasCentrais": obrasCentrais, "capitulosDedicados": capitulosDedicados, "mapa": mapa,
             "perguntas": perguntas, "roteiro": roteiro, "revisao": revisao]
        }
    }

    static func exibicao(termo: String, resultado: Resultado, fontes: [Fonte], configuracao: Configuracao) -> Exibicao {
        let porID = Dictionary(fontes.map { ($0.id, $0) }, uniquingKeysWith: { primeira, _ in primeira })
        func citar(_ id: String) -> String {
            guard let fonte = porID[id] else { return id }
            return "\(fonte.tituloObra), \(referencia(fonte))"
        }
        func trechos(_ lista: [Trecho]) -> [String] { lista.map { "\($0.texto) — \(citar($0.fonte))" } }
        let metricas = resultado.metricas
        let areas = metricas.porArea.map { "\(configuracao.areas[$0.area] ?? $0.area) (\($0.fontes))" }.joined(separator: ", ")
        let tema = nfc(termo).unicodeScalars.split { $0.properties.isWhitespace }.map { texto(ArraySlice($0)) }.joined(separator: " ")
        let leitura = DateFormatter()
        leitura.locale = Locale(identifier: "en_US_POSIX")
        leitura.timeZone = TimeZone(identifier: "UTC")
        leitura.dateFormat = "yyyy-MM-dd"
        let escrita = DateFormatter()
        escrita.locale = Locale(identifier: "en_US_POSIX")
        escrita.timeZone = TimeZone(identifier: "UTC")
        escrita.dateFormat = "dd/MM/yyyy"
        return Exibicao(
            definicoes: trechos(resultado.definicoes),
            resumo: trechos(resultado.resumo),
            divergencias: trechos(resultado.divergencias),
            metricas: ["\(metricas.fontes) fonte(s) em \(metricas.obras) obra(s); \(metricas.ocorrencias) ocorrência(s) do tema."]
                + (areas.isEmpty ? [] : ["Áreas: \(areas)."])
                + (metricas.duplicadas == 0 ? [] : ["\(metricas.duplicadas) fonte(s) com texto repetido de outra obra desconsiderada(s)."])
                + (metricas.frasesComRuido == 0 ? [] : ["\(metricas.frasesComRuido) frase(s) com ruído de digitalização desconsiderada(s)."]),
            obrasCentrais: resultado.obrasCentrais.map { "\($0.titulo): \($0.ocorrencias) ocorrência(s) em \($0.fontes) fonte(s)" },
            capitulosDedicados: resultado.capitulosDedicados.map(citar),
            mapa: resultado.termosAssociados.map { "\(tema) → \($0.forma) (\($0.ocorrencias) ocorrência(s), \($0.obras) obra(s))" },
            perguntas: resultado.perguntas.map { "\($0.pergunta) (Resposta: \($0.resposta) — \(citar($0.fonte)))" },
            roteiro: resultado.roteiro.map { "\($0.etapa): \($0.texto)" },
            revisao: resultado.revisao.map { item in
                "\(leitura.date(from: item.data).map(escrita.string(from:)) ?? item.data): \(item.tarefa)"
            }
        )
    }

    // MARK: - Text, by Unicode code point as in the reference

    static func nfc(_ texto: String) -> String {
        texto.precomposedStringWithCanonicalMapping
    }

    static func ehCaractereDePalavra(_ escalar: Unicode.Scalar) -> Bool {
        switch escalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber:
            true
        default:
            false
        }
    }

    /// Runs of letters and digits with their code point positions.
    static func intervalos(_ escalares: [Unicode.Scalar]) -> [Range<Int>] {
        var resultado: [Range<Int>] = []
        var inicio: Int?
        for (indice, escalar) in escalares.enumerated() {
            if ehCaractereDePalavra(escalar) {
                if inicio == nil { inicio = indice }
            } else if let comeco = inicio {
                resultado.append(comeco..<indice)
                inicio = nil
            }
        }
        if let comeco = inicio { resultado.append(comeco..<escalares.count) }
        return resultado
    }

    static func texto(_ escalares: ArraySlice<Unicode.Scalar>) -> String {
        var visao = String.UnicodeScalarView()
        visao.append(contentsOf: escalares)
        return String(visao)
    }

    static func dobrar(_ palavra: String) -> String {
        texto(ArraySlice(palavra.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars
            .filter { $0.properties.generalCategory != .nonspacingMark }))
    }

    private static func ehNumero(_ palavra: String) -> Bool {
        palavra.unicodeScalars.allSatisfy { $0.properties.generalCategory == .decimalNumber }
    }

    /// Original, lowercase (with accents) and normalized words, index-aligned.
    static func palavras(_ frase: String) -> (originais: [String], minusculas: [String], normalizadas: [String]) {
        let escalares = Array(frase.unicodeScalars)
        let originais = intervalos(escalares).map { texto(escalares[$0]) }
        return (originais, originais.map { $0.lowercased() }, originais.map(dobrar))
    }

    /// Collapses whitespace and removes OCR repetition: a run of 1 to 20 words repeated at once.
    static func limpar(_ bruto: String) -> String {
        let itens = nfc(bruto).unicodeScalars.split { $0.properties.isWhitespace }.map { texto(ArraySlice($0)) }
        var saida: [String] = []
        var indice = 0
        repeticao: while indice < itens.count {
            for tamanho in stride(from: 20, through: 1, by: -1) where indice + 2 * tamanho <= itens.count {
                if itens[indice..<(indice + tamanho)].elementsEqual(itens[(indice + tamanho)..<(indice + 2 * tamanho)]) {
                    saida.append(contentsOf: itens[indice..<(indice + tamanho)])
                    indice += 2 * tamanho
                    continue repeticao
                }
            }
            saida.append(itens[indice])
            indice += 1
        }
        return saida.joined(separator: " ")
    }

    /// Separates a heading glued by OCR to the start of a page: the leading words with no lowercase
    /// letter ("49 10ª INSTRUÇÃO ESCADA DE JACÓ VM Degrau é..."). Page numbers at the very start are
    /// dropped from the heading; a final single capital letter belongs to the body ("... JACÓ A escada").
    /// Works on an already cleaned text; the heading is "" when there is none.
    static func separarTitulo(_ limpo: String) -> (titulo: String, corpo: String) {
        func categoria(_ palavra: String, _ teste: (Unicode.GeneralCategory) -> Bool) -> Int {
            palavra.unicodeScalars.filter { teste($0.properties.generalCategory) }.count
        }
        let ehLetra: (Unicode.GeneralCategory) -> Bool = {
            [.uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter].contains($0)
        }
        let ehNumero: (Unicode.GeneralCategory) -> Bool = { [.decimalNumber, .letterNumber, .otherNumber].contains($0) }
        let itens = limpo.isEmpty ? [] : limpo.components(separatedBy: " ")
        var prefixo: [String] = []
        // Only the Unicode lowercase category: "ª" and "º" (10ª, Nº) are not lowercase words.
        for palavra in itens {
            if categoria(palavra, { $0 == .lowercaseLetter }) > 0 { break }
            prefixo.append(palavra)
        }
        guard !prefixo.isEmpty, prefixo.count < itens.count, prefixo.count <= 20 else { return ("", limpo) }
        var corpo = Array(itens[prefixo.count...])
        while let ultima = prefixo.last, categoria(ultima, ehLetra) == 1, categoria(ultima, ehNumero) == 0 {
            corpo.insert(prefixo.removeLast(), at: 0)
        }
        while let primeira = prefixo.first, categoria(primeira, { $0 == .decimalNumber }) == primeira.unicodeScalars.count {
            prefixo.removeFirst()
        }
        guard prefixo.contains(where: { categoria($0, { $0 == .uppercaseLetter }) >= 2 }) else { return ("", limpo) }
        return (prefixo.joined(separator: " "), corpo.joined(separator: " "))
    }

    /// Cuts after '.', '!', '?' or ';' followed by a space; `texto` is already collapsed.
    static func frases(_ limpo: String) -> [String] {
        let escalares = Array(limpo.unicodeScalars)
        var resultado: [String] = []
        var inicio = 0
        for indice in escalares.indices where ".!?;".unicodeScalars.contains(escalares[indice])
            && indice + 1 < escalares.count && escalares[indice + 1] == " " {
            resultado.append(texto(escalares[inicio...indice]).trimmingCharacters(in: .whitespaces))
            inicio = indice + 2
        }
        if inicio < escalares.count {
            resultado.append(texto(escalares[inicio...]).trimmingCharacters(in: .whitespaces))
        }
        return resultado.map(aparar).filter { !$0.isEmpty }
    }

    /// Drops OCR noise before the first real word: a word starting with a letter that has two or more
    /// letters, or a single letter followed by a space and another word ("A virtude", "A Fé").
    static func aparar(_ frase: String) -> String {
        let escalares = Array(frase.unicodeScalars)
        let encontrados = intervalos(escalares)
        func ehLetra(_ escalar: Unicode.Scalar) -> Bool {
            switch escalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: true
            default: false
            }
        }
        for (indice, intervalo) in encontrados.enumerated() where ehLetra(escalares[intervalo.lowerBound]) {
            let letras = escalares[intervalo].filter(ehLetra).count
            let seguinte = indice + 1 < encontrados.count ? encontrados[indice + 1].lowerBound : nil
            let letraIsolada = letras == 1 && intervalo.upperBound < escalares.count && escalares[intervalo.upperBound] == " "
                && seguinte == intervalo.upperBound + 1 && seguinte.map { ehLetra(escalares[$0]) } == true
            if letras >= 2 || letraIsolada {
                return texto(escalares[intervalo.lowerBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    static func ocorrencias(_ tokens: [String], _ termo: [Set<String>]) -> [Int] {
        guard !termo.isEmpty, tokens.count >= termo.count else { return [] }
        return (0...(tokens.count - termo.count)).filter { indice in
            termo.indices.allSatisfy { termo[$0].contains(tokens[indice + $0]) }
        }
    }

    static func referencia(_ fonte: Fonte) -> String {
        if let data = fonte.data, data.range(of: #"^\d{2}/\d{2}$"#, options: .regularExpression) != nil {
            return data
        }
        return "p. \(fonte.pagina)"
    }

    // MARK: - Analysis

    private struct Candidata {
        let pontos: Int
        let fonte: Int
        let ordem: Int
        let texto: String
        let definicao: Bool
        let divergente: Bool
        let chave: String
    }

    static func analisar(termo: String, fontes: [Fonte], configuracao: Configuracao, hoje: Date,
                         calendario: Calendar = Calendar(identifier: .gregorian)) -> Resultado {
        let limites = configuracao.limites
        // Sources whose text repeats an earlier one (the same book imported twice) are ignored.
        var chavesVistas = Set<String>()
        var duplicadas = 0
        let fontes = fontes.filter { fonte in
            let tokens = palavras(limpar(fonte.texto)).normalizadas
            guard tokens.count >= limites.tokensMinimosDuplicata else { return true }
            guard chavesVistas.insert(tokens.prefix(limites.tokensChaveDuplicata).joined(separator: " ")).inserted else {
                duplicadas += 1
                return false
            }
            return true
        }
        let termoAlternativas = palavras(nfc(termo)).normalizadas.map { Set([$0] + (configuracao.variantes[$0] ?? [])) }
        let palavrasDoTermo = termoAlternativas.reduce(into: Set<String>()) { $0.formUnion($1) }
        // Defining verbs describe the term instead of being associated with it.
        let vazias = Set(configuracao.palavrasVazias).union(configuracao.verbosDefinicao.map(dobrar))
        let definidores = Set(configuracao.verbosDefinicao)
        let divergentes = Set(configuracao.marcadoresDivergencia)

        // Sentences with OCR noise are not quoted as statements (qualidade_texto_v1.json).
        let qualidade = QualidadeTexto.Configuracao.compartilhada
        var frasesComRuido = 0
        var candidatas: [Candidata] = []
        var ocorrenciasPorFonte: [Int] = []
        var comecaComTermo: [Bool] = []
        var associados: [String: Int] = [:]
        var obrasPorAssociado: [String: Set<String>] = [:]
        var formasPorAssociado: [String: [String: Int]] = [:]
        for (posicao, fonte) in fontes.enumerated() {
            let (titulo, limpo) = separarTitulo(limpar(fonte.texto))
            let (_, minusculasTexto, tokens) = palavras(limpo)
            let encontrados = ocorrencias(tokens, termoAlternativas)
            let noTitulo = ocorrencias(palavras(titulo).normalizadas, termoAlternativas).count
            ocorrenciasPorFonte.append(encontrados.count + ocorrencias(palavras(limpar(fonte.rodape)).normalizadas, termoAlternativas).count + noTitulo)
            comecaComTermo.append(noTitulo > 0 || encontrados.contains { $0 < limites.inicioCapitulo })
            for indice in encontrados {
                let depoisInicio = min(tokens.count, indice + termoAlternativas.count)
                let posicoes = Array(max(0, indice - limites.janelaAssociacao)..<indice)
                    + Array(depoisInicio..<min(tokens.count, depoisInicio + limites.janelaAssociacao))
                for posicaoPalavra in posicoes {
                    let palavra = tokens[posicaoPalavra]
                    guard palavra.unicodeScalars.count >= limites.tamanhoMinimoTermoAssociado, !vazias.contains(palavra),
                          !palavrasDoTermo.contains(palavra), !ehNumero(palavra) else { continue }
                    associados[palavra, default: 0] += 1
                    obrasPorAssociado[palavra, default: []].insert(fonte.obraId)
                    formasPorAssociado[palavra, default: [:]][minusculasTexto[posicaoPalavra], default: 0] += 1
                }
            }
            for (ordem, frase) in frases(limpo).enumerated() {
                let (_, minusculas, normalizadas) = palavras(frase)
                guard !ocorrencias(normalizadas, termoAlternativas).isEmpty else { continue }
                let tamanho = frase.unicodeScalars.count
                guard tamanho >= limites.tamanhoMinimoFrase, tamanho <= limites.tamanhoMaximoFrase else { continue }
                if let qualidade, [.ruidosa, .ilegivel].contains(QualidadeTexto.avaliarFrase(frase, configuracao: qualidade).nivel) {
                    frasesComRuido += 1
                    continue
                }
                let definicao = minusculas.contains(where: definidores.contains)
                let pontos = (definicao ? 3 : 0) + (fonte.area == "dicionariosMaconicos" ? 2 : 0) + (fonte.area != "bibliotecaMaconica" ? 1 : 0)
                candidatas.append(Candidata(pontos: pontos, fonte: posicao, ordem: ordem, texto: frase, definicao: definicao,
                    divergente: minusculas.contains(where: divergentes.contains),
                    chave: String(String.UnicodeScalarView(normalizadas.joined(separator: " ").unicodeScalars.prefix(120)))))
            }
        }

        var vistas = Set<String>()
        let unicas = candidatas.sorted {
            if $0.pontos != $1.pontos { return $0.pontos > $1.pontos }
            if $0.fonte != $1.fonte { return $0.fonte < $1.fonte }
            return $0.ordem < $1.ordem
        }.filter { vistas.insert($0.chave).inserted }

        func escolher(_ grupo: [Candidata], _ limite: Int, excluindo excluidas: Set<[Int]> = []) -> [Candidata] {
            var escolhidas: [Candidata] = []
            var obras = Set<String>()
            for candidata in grupo where !excluidas.contains([candidata.fonte, candidata.ordem]) {
                guard obras.insert(fontes[candidata.fonte].obraId).inserted else { continue }
                escolhidas.append(candidata)
                if escolhidas.count == limite { break }
            }
            return escolhidas
        }

        let definicoes = escolher(unicas.filter { $0.definicao && fontes[$0.fonte].area == "dicionariosMaconicos" }, limites.definicoes)
        let resumo = escolher(unicas, limites.resumo, excluindo: Set(definicoes.map { [$0.fonte, $0.ordem] }))
        let divergencias = escolher(unicas.filter(\.divergente), limites.divergencias)
        func trecho(_ candidata: Candidata) -> Trecho { Trecho(texto: candidata.texto, fonte: fontes[candidata.fonte].id) }

        var porArea: [String: Int] = [:]
        for fonte in fontes { porArea[fonte.area, default: 0] += 1 }
        var obras: [String: (titulo: String, ocorrencias: Int, fontes: Int, primeira: Int)] = [:]
        for (posicao, fonte) in fontes.enumerated() {
            var entrada = obras[fonte.obraId] ?? (fonte.tituloObra, 0, 0, posicao)
            entrada.ocorrencias += ocorrenciasPorFonte[posicao]
            entrada.fontes += 1
            obras[fonte.obraId] = entrada
        }
        let centrais = obras.map { (id: $0.key, dados: $0.value) }.sorted {
            if $0.dados.ocorrencias != $1.dados.ocorrencias { return $0.dados.ocorrencias > $1.dados.ocorrencias }
            if $0.dados.fontes != $1.dados.fontes { return $0.dados.fontes > $1.dados.fontes }
            return $0.id < $1.id
        }.prefix(limites.obrasCentrais)
        var dedicados: [String] = []
        var obrasDedicadas = Set<String>()
        for (posicao, fonte) in fontes.enumerated() where comecaComTermo[posicao] && dedicados.count < limites.capitulosDedicados {
            if obrasDedicadas.insert(fonte.obraId).inserted { dedicados.append(fonte.id) }
        }
        let termosAssociados = associados.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limites.termosAssociados)
            .map { item in
                // Shown in its most frequent written form; ties keep the smallest form.
                let forma = (formasPorAssociado[item.key] ?? [:]).min { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }?.key ?? item.key
                return TermoAssociado(termo: item.key, forma: forma, ocorrencias: item.value, obras: obrasPorAssociado[item.key]?.count ?? 0)
            }

        var perguntas: [Pergunta] = []
        for candidata in resumo where perguntas.count < limites.perguntas {
            let escalares = Array(candidata.texto.unicodeScalars)
            let normalizadas = palavras(candidata.texto).normalizadas
            for associado in termosAssociados {
                guard let indice = normalizadas.firstIndex(of: associado.termo) else { continue }
                let intervalo = intervalos(escalares)[indice]
                perguntas.append(Pergunta(
                    pergunta: texto(escalares[..<intervalo.lowerBound]) + "_____" + texto(escalares[intervalo.upperBound...]),
                    resposta: texto(escalares[intervalo]), fonte: fontes[candidata.fonte].id))
                break
            }
        }

        func citar(_ posicao: Int) -> String { "\(fontes[posicao].tituloObra), \(referencia(fontes[posicao]))" }
        var roteiro: [Etapa] = []
        if let primeira = definicoes.first {
            roteiro.append(Etapa(etapa: "Definição", texto: "Comece pela definição em \(citar(primeira.fonte))."))
        } else {
            roteiro.append(Etapa(etapa: "Definição", texto: "Nenhum dicionário do acervo define o termo; comece pela fonte central."))
        }
        if let primeira = centrais.first {
            let inicio = fontes.firstIndex { dedicados.contains($0.id) && $0.obraId == primeira.id } ?? primeira.dados.primeira
            roteiro.append(Etapa(etapa: "Fonte central",
                texto: "Leia \(primeira.dados.titulo) (\(primeira.dados.ocorrencias) ocorrências), a partir de \(referencia(fontes[inicio]))."))
        }
        let breviarios = fontes.indices.filter { fontes[$0].area == "breviarios" }.prefix(3)
        if !breviarios.isEmpty {
            roteiro.append(Etapa(etapa: "Breviários", texto: "Leia nos breviários: " + breviarios.map(citar).joined(separator: "; ") + "."))
        }
        if centrais.count > 1 {
            roteiro.append(Etapa(etapa: "Aprofundamento",
                texto: "Aprofunde em: " + centrais.dropFirst().prefix(3).map(\.dados.titulo).joined(separator: "; ") + "."))
        }
        if divergencias.count > 1 {
            roteiro.append(Etapa(etapa: "Comparação", texto: "Compare \(citar(divergencias[0].fonte)) com \(citar(divergencias[1].fonte))."))
        } else if centrais.count > 1 {
            let lista = Array(centrais)
            roteiro.append(Etapa(etapa: "Comparação", texto: "Compare como \(lista[0].dados.titulo) e \(lista[1].dados.titulo) tratam o tema."))
        }
        roteiro.append(Etapa(etapa: "Síntese", texto: "Escreva uma síntese citando a obra e a página de cada trecho usado."))

        let formato = DateFormatter()
        formato.calendar = calendario
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.timeZone = calendario.timeZone
        formato.dateFormat = "yyyy-MM-dd"
        let revisao = configuracao.revisao.map { passo in
            Revisao(data: formato.string(from: calendario.date(byAdding: .day, value: passo.dias, to: hoje) ?? hoje), tarefa: passo.tarefa)
        }

        return Resultado(
            definicoes: definicoes.map(trecho),
            resumo: resumo.map(trecho),
            divergencias: divergencias.map(trecho),
            metricas: Metricas(fontes: fontes.count, obras: obras.count, ocorrencias: ocorrenciasPorFonte.reduce(0, +), duplicadas: duplicadas,
                               frasesComRuido: frasesComRuido,
                               porArea: porArea.map { (area: $0.key, fontes: $0.value) }
                                .sorted { $0.fontes != $1.fontes ? $0.fontes > $1.fontes : $0.area < $1.area }),
            obrasCentrais: centrais.map { ObraCentral(obraId: $0.id, titulo: $0.dados.titulo, ocorrencias: $0.dados.ocorrencias, fontes: $0.dados.fontes) },
            capitulosDedicados: dedicados,
            termosAssociados: termosAssociados,
            perguntas: perguntas,
            roteiro: roteiro,
            revisao: revisao
        )
    }
}
