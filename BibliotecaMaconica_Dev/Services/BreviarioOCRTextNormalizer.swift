import Foundation

extension BreviarioImportService {
static func corrigirSubstituicoesOCR(_ texto: String) -> String {
        let substituicoes = [
            "se}.'Ual": "sexual",
            "1laçônica": "Maçônica",
            "1Iaçonaria": "Maçonaria",
            "11açonaria": "Maçonaria",
            "1façonaria": "Maçonaria",
            "1açonaria": "Maçonaria",
            "1fóveis": "Móveis",
            "Ilumtn1smo": "Iluminismo",
            "NÚlllet'o": "Número",
            "Número8t .____": "Número 81",
            "1encia açoruca": "Ciência Maçônica",
            "Ja tn\"'ISIVC": "A Letra G",
            "I .. uvas": "Luvas",
            "Scncg2l": "Senegal",
            "23rnbia": "Zâmbia",
            "1'íartinismo": "Martinismo",
            "Univetsal": "Universal",
            "Maçonaria \"Universal\" __": "Maçonaria \"Universal\"",
            "JoséCastellani": "José Castellani",
            "Sch.aw": "Schaw",
            "R.ite": "Rite",
            "A Letra \"G»": "A Letra \"G\"",
            "Poli rica": "Política",
            "Réglia": "Régua"
        ]

        return substituicoes.reduce(texto) { parcial, substituicao in
            parcial.replacingOccurrences(of: substituicao.key, with: substituicao.value)
        }
    }

    static func extrairTitulo(linhas: inout [String], data: String) -> String {
        guard data != "00/00" else {
            return "Informações da obra"
        }

        while let primeira = linhas.first, primeira.isEmpty {
            linhas.removeFirst()
        }

        guard let primeira = linhas.first else {
            return "Texto de \(data)"
        }

        if primeira.count <= 90 {
            linhas.removeFirst()
            return primeira
        }

        return "Texto de \(data)"
    }

    static func extrairRodape(linhas: inout [String]) -> String? {
        var rodapes: [String] = []
        var corpo: [String] = []
        var coletandoRodapePorLayout = false

        for linha in linhas {
            if linha == marcadorRodapePorLayout {
                coletandoRodapePorLayout = true
                continue
            }

            if coletandoRodapePorLayout {
                rodapes.append(linha)
            } else if pareceRodape(linha) {
                rodapes.append(linha)
            } else {
                corpo.append(linha)
            }
        }

        linhas = corpo
        let textoRodape = recomporParagrafos(limpar(rodapes))
        return textoRodape.isEmpty ? nil : textoRodape
    }

    static func separarRodapeEmbutido(texto: String, rodape: String?) -> (texto: String, rodape: String?) {
        guard let inicioRodape = inicioRodapeEmbutido(em: texto) else {
            return (texto, rodape)
        }

        let corpo = String(texto[..<inicioRodape])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let nota = String(texto[inicioRodape...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard corpo.count > 120, nota.count > 20 else {
            return (texto, rodape)
        }

        let partesRodape = [rodape, nota]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        return (
            texto: corpo,
            rodape: partesRodape.isEmpty ? nil : partesRodape.joined(separator: "\n\n")
        )
    }

    static func inicioRodapeEmbutido(em texto: String) -> String.Index? {
        let nsTexto = texto as NSString
        let tamanho = nsTexto.length
        let inicioMinimo = max(120, Int(Double(tamanho) * 0.45))
        let padroes = [
            #"(?<!\S)(\d{3,4})\s+(?=(?:[A-ZÁÀÂÃÉÈÊÍÓÔÕÖÚÇ]{2,}|Idem|Ibidem|DE\s+[A-ZÁÀÂÃÉÈÊÍÓÔÕÖÚÇ]{2,}))"#,
            #"(?<!\S)(?:\d{1,3}[!#]\d?|\d[!#]\d{2}|[1Il]{2}#)\s+(?=[A-ZÁÀÂÃÉÈÊÍÓÔÕÖÚÇ]{2,})"#
        ]

        let candidatos = padroes.flatMap { padrao -> [NSTextCheckingResult] in
            guard let regex = try? NSRegularExpression(pattern: padrao) else {
                return []
            }

            return regex.matches(
                in: texto,
                range: NSRange(location: 0, length: tamanho)
            )
        }
        .filter { $0.range.location >= inicioMinimo }
        .sorted { $0.range.location < $1.range.location }

        guard let primeiro = candidatos.first,
              let range = Range(primeiro.range, in: texto) else {
            return nil
        }

        return range.lowerBound
    }

    static func recomporParagrafos(_ linhas: [String]) -> String {
        var paragrafos: [String] = []
        var paragrafoAtual = ""

        for linha in linhas {
            let linhaLimpa = linha.trimmingCharacters(in: .whitespacesAndNewlines)

            guard linhaLimpa.isEmpty == false else {
                finalizarParagrafo(&paragrafoAtual, em: &paragrafos)
                continue
            }

            if deveManterLinhaSeparada(linhaLimpa) {
                finalizarParagrafo(&paragrafoAtual, em: &paragrafos)
                paragrafos.append(linhaLimpa)
                continue
            }

            if paragrafoAtual.isEmpty {
                paragrafoAtual = linhaLimpa
            } else {
                paragrafoAtual += " " + linhaLimpa
            }
        }

        finalizarParagrafo(&paragrafoAtual, em: &paragrafos)

        return paragrafos.joined(separator: "\n\n")
    }

    static func finalizarParagrafo(_ paragrafo: inout String, em paragrafos: inout [String]) {
        let texto = paragrafo.trimmingCharacters(in: .whitespacesAndNewlines)

        if texto.isEmpty == false {
            paragrafos.append(texto)
        }

        paragrafo = ""
    }

    static func deveManterLinhaSeparada(_ linha: String) -> Bool {
        if primeiraData(em: linha) != nil || marcadorPagina(em: linha) != nil {
            return true
        }

        if pareceRodape(linha) {
            return true
        }

        return linha.range(
            of: #"^([IVXLCDM]+\.|\d{1,3}[\.\)]|[-•])\s+.+"#,
            options: .regularExpression
        ) != nil
    }

    static func pareceRodape(_ linha: String) -> Bool {
        let normalizada = linha.trimmingCharacters(in: .whitespacesAndNewlines)
        let minuscula = normalizada.lowercased()

        if minuscula.hasPrefix("rodapé:")
            || minuscula.hasPrefix("rodape:")
            || minuscula.hasPrefix("nota:")
            || minuscula.hasPrefix("notas:")
            || minuscula.hasPrefix("observação:")
            || minuscula.hasPrefix("observacao:") {
            return true
        }

        return normalizada.range(
            of: #"^(\*|\d{1,2}[\.\)]|[¹²³⁴⁵⁶⁷⁸⁹⁰])\s+.+"#,
            options: .regularExpression
        ) != nil
    }

    static func primeiraData(em linha: String) -> String? {
        guard let range = linha.range(
            of: #"^\s*(0[1-9]|[12][0-9]|3[01])/(0[1-9]|1[0-2])\b"#,
            options: .regularExpression
        ) else {
            return nil
        }

        return String(linha[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func marcadorPagina(em linha: String) -> Int? {
        guard let match = linha.firstMatch(of: /^--- PAGINA (\d+) ---$/) else {
            return nil
        }

        return Int(match.1)
    }

    static func normalizar(_ texto: String) -> String {
        texto.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extrairAutor(linhas: [String]) -> String? {
        for linha in linhas.prefix(80) {
            let minuscula = linha.lowercased()

            if minuscula.hasPrefix("autor:") || minuscula.hasPrefix("autor ") {
                return limparAutor(linha)
            }

            if minuscula.hasPrefix("por ") && linha.count <= 80 {
                return String(linha.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    static func limparAutor(_ linha: String) -> String {
        linha
            .replacingOccurrences(of: "Autor:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Autor", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extrairFrase(texto: String) -> String {
        let linhas = texto.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard let primeira = linhas.first, primeira.count <= 320 else {
            return ""
        }

        return primeira
    }
}
