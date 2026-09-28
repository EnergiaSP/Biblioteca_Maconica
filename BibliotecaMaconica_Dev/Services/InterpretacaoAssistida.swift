import Foundation

/// AI-assisted interpretation of a dossier. The AI receives only the excerpts shown in the dossier,
/// numbered [F1], [F2]...; from its answer only sentences with a valid citation are kept, and a
/// literal quotation must exist in a cited excerpt. Mirrors `Tools/ia_referencia.py`;
/// `casos_ia_v1.json` holds the golden cases both apps reproduce.
enum InterpretacaoAssistida {
    typealias Fonte = DossieEstudoAnalise.Fonte
    typealias D = DossieEstudoAnalise

    struct Configuracao: Decodable {
        struct Limites: Decodable {
            let caracteresTrecho: Int
            let caracteresRodape: Int
            let citacaoLiteralMinima: Int
        }
        struct Rotulos: Decodable {
            let titulo, aviso, removidas, fontesCitadas, semFontes, semFontesOficiais: String
        }
        let schemaVersion: Int
        let limites: Limites
        let instrucoes: [String]
        let blocos: [String]
        let rotulos: Rotulos

        static let compartilhada: Configuracao? = {
            guard let url = Bundle.main.url(forResource: "ia_assistida_v1", withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let configuracao = try? JSONDecoder().decode(Configuracao.self, from: dados),
                  configuracao.schemaVersion == 1 else { return nil }
            return configuracao
        }()
    }

    struct FonteOficial: Equatable {
        let titulo, origem, url, observacao: String
    }

    struct Resultado: Equatable {
        let texto: String
        let frasesMantidas: Int
        let frasesRemovidas: Int
        let fontesCitadas: [Int]
    }

    // MARK: - Prompt

    static func prompt(termo: String, fontes: [Fonte], oficiais: [FonteOficial],
                       configuracao: Configuracao, estudo: D.Configuracao) -> String {
        let tokens = D.palavras(D.nfc(termo)).normalizadas.map { Set([$0] + (estudo.variantes[$0] ?? [])) }
        var linhas = configuracao.instrucoes
        linhas += ["", "Organize a resposta nestes blocos, nesta ordem, cada um com o título em uma linha própria:"]
        linhas += configuracao.blocos.enumerated().map { "\($0.offset + 1). \($0.element)" }
        linhas += ["", "TEMA: \(D.limpar(termo))", "", "FONTES OFICIAIS CADASTRADAS (somente referência):"]
        linhas += oficiais.isEmpty
            ? [configuracao.rotulos.semFontesOficiais]
            : oficiais.map { "- \($0.titulo) | \($0.origem) | \($0.url) | \($0.observacao)" }
        linhas += ["", "TRECHOS DO DOSSIÊ:"]
        for (indice, fonte) in fontes.enumerated() {
            linhas.append(linhaFonte(indice + 1, fonte, estudo: estudo))
            linhas.append(trecho(fonte.texto, termo: tokens, limite: configuracao.limites.caracteresTrecho))
            if D.limpar(fonte.rodape).isEmpty == false {
                linhas.append("Notas de rodapé: " + encurtar(fonte.rodape, limite: configuracao.limites.caracteresRodape))
            }
            linhas.append("")
        }
        var texto = linhas.joined(separator: "\n")
        while texto.hasSuffix("\n") { texto.removeLast() }
        return texto
    }

    static func linhaFonte(_ numero: Int, _ fonte: Fonte, estudo: D.Configuracao) -> String {
        "[F\(numero)] \(fonte.tituloObra), \(D.referencia(fonte)) (\(estudo.areas[fonte.area] ?? fonte.area))"
    }

    /// Window of the cleaned text around the first occurrence of the topic, cut at word limits.
    static func trecho(_ texto: String, termo: [Set<String>], limite: Int) -> String {
        let limpo = Array(D.limpar(texto).unicodeScalars)
        guard limpo.count > limite else { return D.texto(ArraySlice(limpo)) }
        let intervalos = D.intervalos(limpo)
        let dobradas = intervalos.map { D.dobrar(D.texto(limpo[$0])) }
        let centro = D.ocorrencias(dobradas, termo).first.map { intervalos[$0].lowerBound } ?? 0
        var inicio = max(0, centro - limite / 3)
        if inicio > 0 {
            inicio = intervalos.first { $0.lowerBound >= inicio }?.lowerBound ?? inicio
        }
        var fim = inicio + limite
        if fim >= limpo.count {
            fim = limpo.count
        } else {
            fim = intervalos.filter { $0.upperBound <= fim && $0.upperBound > inicio }.map(\.upperBound).max() ?? fim
        }
        let corpo = D.texto(limpo[inicio..<fim]).trimmingCharacters(in: .whitespaces)
        return (inicio > 0 ? "… " : "") + corpo + (fim < limpo.count ? " …" : "")
    }

    static func encurtar(_ texto: String, limite: Int) -> String {
        let limpo = Array(D.limpar(texto).unicodeScalars)
        guard limpo.count > limite else { return D.texto(ArraySlice(limpo)) }
        let corte = limpo[0...limite].lastIndex(of: " ") ?? 0
        return D.texto(limpo[0..<(corte > 0 ? corte : limite)]) + " …"
    }

    // MARK: - Filter

    // Fixed patterns; if one ever failed to compile, nothing would be accepted (fail closed).
    private static let citacao = try? NSRegularExpression(pattern: #"\[F([0-9]+)\]"#)
    private static let marcador = try? NSRegularExpression(pattern: #"^([-*•]|[0-9]+[.)]) "#)
    private static let citacoesSeguidas = try? NSRegularExpression(pattern: #"(?: ?\[F[0-9]+\])+\.?"#)
    private static let aspas = try? NSRegularExpression(pattern: #"“([^”]*)”|"([^"]*)""#)

    /// A line is a heading only when it is one of the requested block titles (with number, # or **).
    static func titulo(_ linha: String, configuracao: Configuracao) -> String? {
        var texto = aparar(aparar(linha.drop { $0 == "#" }).trimmingCharacters(in: CharacterSet(charactersIn: "*")))
        if let achado = marcador?.firstMatch(in: texto, range: NSRange(texto.startIndex..., in: texto)),
           let faixa = Range(achado.range, in: texto) {
            texto.removeSubrange(faixa)
        }
        while texto.hasSuffix(":") { texto.removeLast() }
        texto = aparar(aparar(texto).trimmingCharacters(in: CharacterSet(charactersIn: "*")))
        return configuracao.blocos.first { D.dobrar(D.limpar(texto)) == D.dobrar($0) }
    }

    private static func aparar<S: StringProtocol>(_ texto: S) -> String {
        String(texto).trimmingCharacters(in: .whitespaces)
    }

    private static func ehLetra(_ escalar: Unicode.Scalar) -> Bool {
        switch escalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: true
        default: false
        }
    }

    /// Sentence ends: '.', '!' or '?' followed by a space, not after a word of one or two letters
    /// ("p.", "Sr."); citations right after the end belong to that sentence.
    static func frases(_ corpo: String) -> [String] {
        let escalares = Array(corpo.unicodeScalars)
        var cortes: [Int] = []
        var indice = 0
        while indice < escalares.count {
            let caractere = escalares[indice]
            if ".!?".unicodeScalars.contains(caractere), indice + 1 < escalares.count, escalares[indice + 1] == " " {
                var inicioPalavra = indice
                while inicioPalavra > 0 && ehLetra(escalares[inicioPalavra - 1]) { inicioPalavra -= 1 }
                let letras = indice - inicioPalavra
                if caractere != "." || letras == 0 || letras >= 3 {
                    var fim = indice + 1
                    let resto = D.texto(escalares[fim...])
                    if let achado = citacoesSeguidas?.firstMatch(in: resto, options: .anchored, range: NSRange(resto.startIndex..., in: resto)),
                       let faixa = Range(achado.range, in: resto) {
                        let tamanho = resto[faixa].unicodeScalars.count
                        if fim + tamanho == escalares.count || escalares[fim + tamanho] == " " { fim += tamanho }
                    }
                    cortes.append(fim)
                    indice = fim
                    continue
                }
            }
            indice += 1
        }
        var resultado: [String] = []
        var inicio = 0
        for fim in cortes + [escalares.count] {
            resultado.append(aparar(D.texto(escalares[inicio..<fim])))
            inicio = fim
        }
        return resultado.filter { !$0.isEmpty }
    }

    private static func normalizado(_ texto: String) -> String {
        D.palavras(D.limpar(texto)).normalizadas.joined(separator: " ")
    }

    private static func citacoes(_ frase: String) -> [Int] {
        // A number too large for Int is an invalid source, as in the reference.
        (citacao?.matches(in: frase, range: NSRange(frase.startIndex..., in: frase)) ?? []).compactMap { achado in
            Range(achado.range(at: 1), in: frase).map { Int(frase[$0]) ?? Int.max }
        }
    }

    private static func aspasConferem(_ frase: String, _ ids: [Int], fontes: [Fonte], configuracao: Configuracao) -> Bool {
        guard let aspas, citacao != nil, marcador != nil, citacoesSeguidas != nil else { return false }
        let citados = ids.map { " " + normalizado(fontes[$0 - 1].texto + " " + fontes[$0 - 1].rodape) + " " }
        for achado in aspas.matches(in: frase, range: NSRange(frase.startIndex..., in: frase)) {
            let grupo = achado.range(at: 1).location != NSNotFound ? 1 : 2
            guard let faixa = Range(achado.range(at: grupo), in: frase) else { continue }
            let citado = String(frase[faixa])
            guard D.limpar(citado).unicodeScalars.count >= configuracao.limites.citacaoLiteralMinima else { continue }
            let agulha = " " + normalizado(citado) + " "
            if !citados.contains(where: { $0.contains(agulha) }) { return false }
        }
        return true
    }

    static func filtrar(resposta: String, fontes: [Fonte], configuracao: Configuracao) -> Resultado {
        var secoes: [(titulo: String?, linhas: [String])] = []
        var mantidas = 0
        var removidas = 0
        var citadas = Set<Int>()
        let texto = D.nfc(resposta).replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        for bruta in texto.components(separatedBy: "\n") {
            let linha = D.limpar(bruta.replacingOccurrences(of: "**", with: ""))
            guard !linha.isEmpty else { continue }
            if let titulo = titulo(linha, configuracao: configuracao) {
                secoes.append((titulo, []))
                continue
            }
            var prefixo = ""
            var corpo = linha
            if let achado = marcador?.firstMatch(in: linha, range: NSRange(linha.startIndex..., in: linha)),
               let faixa = Range(achado.range, in: linha), let grupo = Range(achado.range(at: 1), in: linha) {
                prefixo = String(linha[grupo]) + " "
                corpo = String(linha[faixa.upperBound...])
            }
            var aceitas: [String] = []
            for frase in frases(corpo) {
                let ids = citacoes(frase)
                if !ids.isEmpty, ids.allSatisfy({ $0 >= 1 && $0 <= fontes.count }),
                   aspasConferem(frase, ids, fontes: fontes, configuracao: configuracao) {
                    aceitas.append(frase)
                    citadas.formUnion(ids)
                } else {
                    removidas += 1
                }
            }
            if !aceitas.isEmpty {
                mantidas += aceitas.count
                if secoes.isEmpty { secoes.append((nil, [])) }
                secoes[secoes.count - 1].linhas.append(prefixo + aceitas.joined(separator: " "))
            }
        }
        let blocos = secoes.filter { !$0.linhas.isEmpty }.map { secao in
            (secao.titulo.map { $0 + "\n" } ?? "") + secao.linhas.joined(separator: "\n")
        }
        return Resultado(texto: blocos.joined(separator: "\n\n"), frasesMantidas: mantidas,
                         frasesRemovidas: removidas, fontesCitadas: citadas.sorted())
    }

    /// Text shown on screen and in exports; empty when nothing could be kept.
    static func exibicao(_ resultado: Resultado, fontes: [Fonte], configuracao: Configuracao, estudo: D.Configuracao) -> String {
        guard resultado.frasesMantidas > 0 else { return "" }
        let rotulos = configuracao.rotulos
        var linhas = [rotulos.titulo, rotulos.aviso]
        if resultado.frasesRemovidas > 0 {
            linhas.append(rotulos.removidas.replacingOccurrences(of: "{n}", with: String(resultado.frasesRemovidas)))
        }
        linhas += ["", resultado.texto, "", rotulos.fontesCitadas + ":"]
        linhas += resultado.fontesCitadas.map { linhaFonte($0, fontes[$0 - 1], estudo: estudo) }
        return linhas.joined(separator: "\n")
    }
}
