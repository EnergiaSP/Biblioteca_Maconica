import Foundation

/// Quality of a page or sentence of the collection: the share of suspicious words left by OCR.
/// Mirrors `Tools/qualidade_referencia.py`; `casos_qualidade_v1.json` holds the golden cases both
/// apps reproduce. Works on Unicode scalars after NFC, so lengths are counted in code points.
enum QualidadeTexto {
    struct Configuracao: Decodable {
        struct Limites: Decodable {
            let palavrasMinimasPagina, palavrasMinimasFrase: Int
            let ruidosaPercentual, ilegivelPercentual, letrasSemVogal: Int
            let obraBoaPercentual, obraRegularPercentual: Int
        }
        struct Rotulos: Decodable {
            let paginaRuidosa, paginaIlegivel, fonteRuidosa: String
            let obra: [String: String]
        }
        let schemaVersion: Int
        let limites: Limites
        let bordas, marcasAbreviacao, marcasOrdinais, sinaisNumericos, sinaisInternos: String
        let algarismosRomanos, palavrasDeUmaLetra, vogais: String
        let faixasLatinas, escritasEsperadas: [[UInt32]]
        let prefixosEndereco: [String]
        let rotulos: Rotulos

        static let compartilhada: Configuracao? = {
            guard let url = Bundle.main.url(forResource: "qualidade_texto_v1", withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let configuracao = try? JSONDecoder().decode(Configuracao.self, from: dados),
                  configuracao.schemaVersion == 1 else { return nil }
            return configuracao
        }()
    }

    enum Nivel: String { case curta, legivel, ruidosa, ilegivel }

    struct Avaliacao: Equatable {
        let palavras: Int
        let suspeitas: Int
        let nivel: Nivel
        let motivos: [String: Int]
    }

    /// Character sets of the rule, built once per evaluation.
    struct Conjuntos {
        let bordas, marcas, ordinais, numericos, internos, romanos, umaLetra, vogais: Set<Unicode.Scalar>
        init(_ c: Configuracao) {
            func conjunto(_ texto: String) -> Set<Unicode.Scalar> { Set(texto.unicodeScalars) }
            bordas = conjunto(c.bordas); marcas = conjunto(c.marcasAbreviacao); ordinais = conjunto(c.marcasOrdinais)
            numericos = conjunto(c.sinaisNumericos); internos = conjunto(c.sinaisInternos)
            romanos = conjunto(c.algarismosRomanos); umaLetra = conjunto(c.palavrasDeUmaLetra); vogais = conjunto(c.vogais)
        }
    }

    // MARK: - Unicode

    private static func letra(_ s: Unicode.Scalar) -> Bool {
        switch s.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter: return true
        default: return false
        }
    }

    private static func digito(_ s: Unicode.Scalar) -> Bool { s.properties.generalCategory == .decimalNumber }

    private static func alfanumerico(_ s: Unicode.Scalar) -> Bool {
        if letra(s) { return true }
        switch s.properties.generalCategory {
        case .decimalNumber, .letterNumber, .otherNumber: return true
        default: return false
        }
    }

    private static func maiuscula(_ s: Unicode.Scalar) -> Bool { s.properties.generalCategory == .uppercaseLetter }
    private static func minuscula(_ s: Unicode.Scalar) -> Bool { s.properties.generalCategory == .lowercaseLetter }

    private static func separador(_ s: Unicode.Scalar) -> Bool {
        if ["\t", "\n", "\u{0B}", "\u{0C}", "\r"].contains(s) { return true }
        switch s.properties.generalCategory {
        case .spaceSeparator, .lineSeparator, .paragraphSeparator: return true
        default: return false
        }
    }

    static func palavras(_ texto: String) -> [[Unicode.Scalar]] {
        var resultado: [[Unicode.Scalar]] = []
        var atual: [Unicode.Scalar] = []
        for s in texto.precomposedStringWithCanonicalMapping.unicodeScalars {
            if separador(s) {
                if !atual.isEmpty { resultado.append(atual); atual = [] }
            } else {
                atual.append(s)
            }
        }
        if !atual.isEmpty { resultado.append(atual) }
        return resultado
    }

    // MARK: - Classificação

    private static func aparar(_ t: [Unicode.Scalar], _ c: Set<Unicode.Scalar>) -> [Unicode.Scalar] {
        var inicio = 0, fim = t.count
        while inicio < fim && c.contains(t[inicio]) { inicio += 1 }
        while fim > inicio && c.contains(t[fim - 1]) { fim -= 1 }
        return Array(t[inicio..<fim])
    }

    private static func maconica(_ t: [Unicode.Scalar], _ marcas: Set<Unicode.Scalar>) -> Bool {
        var i = 0, grupos = 0
        while i < t.count {
            let letras = i
            while i < t.count && letra(t[i]) { i += 1 }
            if i == letras { return false }
            let inicioMarcas = i
            while i < t.count && marcas.contains(t[i]) { i += 1 }
            if i == inicioMarcas { return i == t.count && grupos > 0 }
            grupos += 1
        }
        return grupos > 0
    }

    private static func ordinal(_ t: [Unicode.Scalar], _ ordinais: Set<Unicode.Scalar>) -> Bool {
        var corpo = t.last == "." ? Array(t.dropLast()) : t
        guard let marca = corpo.last, ordinais.contains(marca) else { return false }
        corpo.removeLast()
        if corpo.last == "." { corpo.removeLast() }
        guard let primeiro = corpo.first, let ultimo = corpo.last,
              corpo.allSatisfy({ digito($0) || $0 == "." || $0 == "," }) else { return false }
        return digito(primeiro) && digito(ultimo)
    }

    private static func nasFaixas(_ s: Unicode.Scalar, _ faixas: [[UInt32]]) -> Bool {
        faixas.contains { $0[0] <= s.value && s.value <= $0[1] }
    }

    /// A digit with letters on both sides ("c0m"); verse or note numbers glued at the start or end
    /// of a word ("15ele", "gnoses116") are normal.
    private static func digitoEntreLetras(_ t: [Unicode.Scalar]) -> Bool {
        var viuLetra = false, digitoDepoisDeLetra = false
        for s in t {
            if letra(s) {
                if digitoDepoisDeLetra { return true }
                viuLetra = true
            } else if digito(s) && viuLetra {
                digitoDepoisDeLetra = true
            }
        }
        return false
    }

    /// nil: ignored (punctuation only); "normal"; or the reason the word is suspicious.
    static func classificar(_ palavra: String, configuracao: Configuracao) -> String? {
        classificar(Array(palavra.precomposedStringWithCanonicalMapping.unicodeScalars), configuracao, Conjuntos(configuracao))
    }

    static func classificar(_ palavra: [Unicode.Scalar], _ configuracao: Configuracao, _ k: Conjuntos) -> String? {
        var t = aparar(palavra, k.bordas)
        guard t.contains(where: alfanumerico) else { return nil }
        let minusculo = String(String.UnicodeScalarView(t)).lowercased()
        if configuracao.prefixosEndereco.contains(where: { minusculo.hasPrefix($0) }) { return "normal" }
        if maconica(t, k.marcas) || ordinal(t, k.ordinais) { return "normal" }
        let abreviada = t.last == "."
        while t.last == "." { t.removeLast() }
        if t.isEmpty { return nil }
        if t.allSatisfy({ digito($0) || k.numericos.contains($0) }) { return "normal" }
        if t.allSatisfy({ k.romanos.contains($0) }) && (t.allSatisfy(maiuscula) || t.count >= 2) { return "normal" }
        let letras = t.filter(letra)
        let outros = t.contains { !alfanumerico($0) && !k.internos.contains($0) }
        if letras.contains(where: { !nasFaixas($0, configuracao.escritasEsperadas) }) { return "escrita" }
        if digitoEntreLetras(t) { return "misto" }
        if !letras.isEmpty && outros { return "simbolo" }
        if letras.count == 1 && !abreviada && !(t.count == 1 && k.umaLetra.contains(t[0])) { return "solta" }
        if t.count >= 3 && zip(t, t.dropFirst()).contains(where: { minuscula($0) && maiuscula($1) }) { return "caixa" }
        if letras.count >= configuracao.limites.letrasSemVogal
            && letras.allSatisfy({ nasFaixas($0, configuracao.faixasLatinas) })
            && !letras.contains(where: { k.vogais.contains($0) }) && !letras.allSatisfy(maiuscula) { return "semVogal" }
        return "normal"
    }

    // MARK: - Avaliação

    static func avaliar(_ texto: String, minimo: Int, configuracao: Configuracao) -> Avaliacao {
        let conjuntos = Conjuntos(configuracao)
        var contadas = 0, suspeitas = 0
        var motivos: [String: Int] = [:]
        for palavra in palavras(texto) {
            guard let classe = classificar(palavra, configuracao, conjuntos) else { continue }
            contadas += 1
            if classe != "normal" {
                suspeitas += 1
                motivos[classe, default: 0] += 1
            }
        }
        let limites = configuracao.limites
        let nivel: Nivel
        if contadas < minimo {
            nivel = .curta
        } else if suspeitas * 100 >= contadas * limites.ilegivelPercentual {
            nivel = .ilegivel
        } else if suspeitas * 100 >= contadas * limites.ruidosaPercentual {
            nivel = .ruidosa
        } else {
            nivel = .legivel
        }
        return Avaliacao(palavras: contadas, suspeitas: suspeitas, nivel: nivel, motivos: motivos)
    }

    static func avaliarPagina(_ texto: String, configuracao: Configuracao) -> Avaliacao {
        avaliar(texto, minimo: configuracao.limites.palavrasMinimasPagina, configuracao: configuracao)
    }

    static func avaliarFrase(_ texto: String, configuracao: Configuracao) -> Avaliacao {
        avaliar(texto, minimo: configuracao.limites.palavrasMinimasFrase, configuracao: configuracao)
    }

    static func nivelObra(_ contagem: QualidadeTextoObra, configuracao: Configuracao) -> String {
        nivelObra(avaliadas: contagem.avaliadas, ruidosas: contagem.ruidosas, ilegiveis: contagem.ilegiveis, configuracao: configuracao)
    }

    /// Quality of a whole work from its rated pages (short pages are not rated).
    static func nivelObra(avaliadas: Int, ruidosas: Int, ilegiveis: Int, configuracao: Configuracao) -> String {
        guard avaliadas > 0 else { return "semAvaliacao" }
        let legiveis = avaliadas - ruidosas - ilegiveis
        if legiveis * 100 >= avaliadas * configuracao.limites.obraBoaPercentual { return "boa" }
        if legiveis * 100 >= avaliadas * configuracao.limites.obraRegularPercentual { return "regular" }
        return "baixa"
    }
}
