import Foundation

struct PaginaMidia: Codable, Equatable {
    let pagina: Int
    let caminhoRelativo: String
    let largura: Double
    let altura: Double
    let tipo: String

    var urlArquivo: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        return base.appendingPathComponent(caminhoRelativo)
    }
}

struct BreviarioItem: Codable, Identifiable {

    let id: Int
    let data: String
    let titulo: String
    let frase: String
    let texto: String
    let rodape: String?
    let autor: String?
    let pagina: Int?
    let obraID: String
    let paginaMidia: PaginaMidia?

    enum CodingKeys: String, CodingKey {
        case id
        case data
        case titulo
        case frase
        case texto
        case rodape
        case autor
        case pagina
        case obraID
        case paginaMidia
    }

    init(
        id: Int,
        data: String,
        titulo: String,
        frase: String,
        texto: String,
        rodape: String? = nil,
        autor: String? = nil,
        pagina: Int? = nil,
        obraID: String = ObraID.breviarioSeculoXXI,
        paginaMidia: PaginaMidia? = nil
    ) {
        self.id = id
        self.data = data
        self.titulo = titulo
        self.frase = frase
        self.texto = texto
        self.rodape = rodape
        self.autor = autor
        self.pagina = pagina
        self.obraID = obraID
        self.paginaMidia = paginaMidia
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        data = try container.decode(String.self, forKey: .data)
        titulo = try container.decode(String.self, forKey: .titulo)
        frase = try container.decodeIfPresent(String.self, forKey: .frase) ?? ""
        texto = try container.decode(String.self, forKey: .texto)
        rodape = try container.decodeIfPresent(String.self, forKey: .rodape)
        pagina = try container.decodeIfPresent(Int.self, forKey: .pagina)
        obraID = try container.decodeIfPresent(String.self, forKey: .obraID)
            ?? ObraID.breviarioSeculoXXI
        autor = try container.decodeIfPresent(String.self, forKey: .autor)
            ?? (obraID == ObraID.breviarioSeculoXXI ? BreviarioImportService.autorPadrao : nil)
        paginaMidia = try container.decodeIfPresent(PaginaMidia.self, forKey: .paginaMidia)
    }

    var comentarioSalvo: String {
        CommentsService.carregar(data: data, obraID: obraID)
    }

    var chavePersistencia: String {
        "\(obraID)_\(data)"
    }

    var autorDocumental: String? {
        let valor = autor ?? (obraID == ObraID.breviarioSeculoXXI ? BreviarioImportService.autorPadrao : nil)
        guard let valor = valor?.trimmingCharacters(in: .whitespacesAndNewlines), !valor.isEmpty else {
            return nil
        }
        return valor
    }

    var cabecalhoDocumental: String {
        obraID == ObraID.breviarioSeculoXXI ? BreviarioImportService.cabecalho : "Biblioteca Maçônica"
    }

    var dataExportacao: String {
        Self.dataPorExtenso(data)
    }

    var referenciaExibicao: String {
        if data.hasPrefix("P"),
           let pagina = Int(data.dropFirst()) {
            return "Página \(pagina)"
        }

        if let pagina, data.contains("/") == false {
            return "Página \(pagina)"
        }

        return dataExportacao
    }

    var fraseExibicao: String? {
        let fraseLimpa = frase.trimmingCharacters(in: .whitespacesAndNewlines)
        let textoLimpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)

        guard fraseLimpa.isEmpty == false else {
            return nil
        }

        if normalizarParaExibicao(textoLimpo).hasPrefix(normalizarParaExibicao(fraseLimpa)) {
            return nil
        }

        return fraseLimpa
    }

    var resumo: String {
        let textoLimpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        let fraseLimpa = frase.trimmingCharacters(in: .whitespacesAndNewlines)
        // Keep the Home preview independent of whether the reader hides a repeated intro.
        if !fraseLimpa.isEmpty,
           normalizarParaExibicao(fraseLimpa) != normalizarParaExibicao(textoLimpo),
           !textoLimpo.hasPrefix(fraseLimpa) || fraseLimpa.count <= 320 {
            return fraseLimpa
        }
        guard textoLimpo.count > 240 else {
            return textoLimpo
        }

        let limite = textoLimpo.index(textoLimpo.startIndex, offsetBy: 240)
        let prefixo = textoLimpo[..<limite]

        if let ultimoEspaco = prefixo.lastIndex(where: { $0.isWhitespace }) {
            return String(textoLimpo[..<ultimoEspaco]) + "..."
        }

        return String(prefixo) + "..."
    }

    var textoCompartilhavel: String {
        var partes = [
            cabecalhoDocumental,
            referenciaExibicao,
            titulo,
            texto
        ]

        if let rodape = rodape?.trimmingCharacters(in: .whitespacesAndNewlines),
           rodape.isEmpty == false {
            partes.append("--------------------\n\nNotas de rodape:\n\n\(rodape)")
        }

        if let autorDocumental { partes.append("Autor: \(autorDocumental)") }
        return partes.joined(separator: "\n\n")
    }

    var chamadasRodape: Set<String> {
        guard let rodape,
              rodape.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return []
        }

        let texto = rodape as NSString
        let padrao = #"\d{1,4}(?=\s+[A-ZÁÉÍÓÚÂÊÔÃÕÇ])"#
        guard let regex = try? NSRegularExpression(pattern: padrao) else {
            return []
        }

        let resultados = regex.matches(
            in: rodape,
            range: NSRange(location: 0, length: texto.length)
        )

        return Set(
            resultados
                .filter {
                    Self.ehInicioDeNotaRodape($0.range, em: texto)
                    || (Int(texto.substring(with: $0.range)) ?? 0) >= 100
                    && Self.existeChamadaRodapeNoTexto(
                        texto.substring(with: $0.range),
                        em: self.texto
                    )
                }
                .map { texto.substring(with: $0.range) }
        )
    }

    private static func existeChamadaRodapeNoTexto(_ numero: String, em texto: String) -> Bool {
        let textoCompleto = texto as NSString
        let padrao = #"(?<![\d/])\#(numero)(?![\d/])"#
        guard let regex = try? NSRegularExpression(pattern: padrao) else {
            return false
        }

        let rangeTotal = NSRange(location: 0, length: textoCompleto.length)
        return regex.matches(in: texto, range: rangeTotal).contains {
            ehChamadaRodapeNoTexto($0.range, em: textoCompleto)
        }
    }

    private static func ehChamadaRodapeNoTexto(_ range: NSRange, em texto: NSString) -> Bool {
        guard range.location > 0 else {
            return false
        }

        var indiceAnterior = range.location - 1
        var anteriorValido: UnicodeScalar?
        var haviaEspacoAntes = false
        while indiceAnterior >= 0 {
            guard let anterior = UnicodeScalar(texto.character(at: indiceAnterior)) else {
                return false
            }

            if CharacterSet.whitespacesAndNewlines.contains(anterior) {
                haviaEspacoAntes = true
                indiceAnterior -= 1
                continue
            }

            anteriorValido = anterior
            break
        }

        guard let anteriorValido else {
            return false
        }

        if CharacterSet.decimalDigits.contains(anteriorValido) || anteriorValido == "/" {
            return false
        }

        if haviaEspacoAntes {
            return [".", "!", "?", ")", "\"", "”", "»", ":"].contains(anteriorValido)
        }

        return true
    }

    private static func ehInicioDeNotaRodape(_ range: NSRange, em texto: NSString) -> Bool {
        guard range.location > 0 else {
            return true
        }

        var indiceAnterior = range.location - 1
        var encontrouQuebraDeLinha = false
        while indiceAnterior >= 0 {
            guard let anterior = UnicodeScalar(texto.character(at: indiceAnterior)) else {
                return false
            }

            if CharacterSet.whitespacesAndNewlines.contains(anterior) {
                if CharacterSet.newlines.contains(anterior) {
                    encontrouQuebraDeLinha = true
                }
                indiceAnterior -= 1
                continue
            }

            if encontrouQuebraDeLinha {
                return true
            }

            return [".", "!", "?", "/"].contains(anterior)
        }

        return true
    }

    var conteudoIntegralParaIA: String {
        var partes = [
            cabecalhoDocumental,
            "Referência: \(referenciaExibicao)",
            "Titulo: \(titulo)"
        ]
        if let autorDocumental { partes.append("Autor: \(autorDocumental)") }

        let fraseLimpa = frase.trimmingCharacters(in: .whitespacesAndNewlines)
        if fraseLimpa.isEmpty == false {
            partes.append("Frase:\n\(fraseLimpa)")
        }

        partes.append("Texto principal completo:\n\(texto.trimmingCharacters(in: .whitespacesAndNewlines))")

        if let rodape = rodape?.trimmingCharacters(in: .whitespacesAndNewlines),
           rodape.isEmpty == false {
            partes.append("Notas de rodape completas:\n\(rodape)")
        }

        return partes.joined(separator: "\n\n")
    }

    private static func dataPorExtenso(_ data: String) -> String {
        let partes = data.split(separator: "/").compactMap { Int($0) }
        guard partes.count == 2, (1...31).contains(partes[0]), (1...12).contains(partes[1]) else {
            return data
        }

        let meses = [
            "janeiro",
            "fevereiro",
            "março",
            "abril",
            "maio",
            "junho",
            "julho",
            "agosto",
            "setembro",
            "outubro",
            "novembro",
            "dezembro"
        ]

        return String(format: "%02d de %@", partes[0], meses[partes[1] - 1])
    }

    var tempoLeituraEstimado: String {
        let conteudo = [texto, rodape ?? ""].joined(separator: " ")
        let palavras = conteudo
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { $0.trimmingCharacters(in: .punctuationCharacters).isEmpty == false }
            .count
        let minutos = max(1, Int(ceil(Double(palavras) / 180.0)))

        return minutos == 1 ? "1 min de leitura" : "\(minutos) min de leitura"
    }

    func atualizado(
        titulo: String? = nil,
        frase: String? = nil,
        texto: String? = nil,
        rodape: String? = nil,
        autor: String? = nil
    ) -> BreviarioItem {
        BreviarioItem(
            id: id,
            data: data,
            titulo: titulo ?? self.titulo,
            frase: frase ?? self.frase,
            texto: texto ?? self.texto,
            rodape: rodape ?? self.rodape,
            autor: autor ?? self.autor,
            pagina: pagina,
            obraID: obraID,
            paginaMidia: paginaMidia
        )
    }

    private func normalizarParaExibicao(_ texto: String) -> String {
        texto
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}
