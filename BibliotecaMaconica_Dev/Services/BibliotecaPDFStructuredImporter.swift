import Foundation
import PDFKit

struct BibliotecaPDFStructuredImporter {
    struct Resultado {
        let obra: BibliotecaRAGObra
        let paginas: [BibliotecaRAGPagina]
        let paragrafos: [BibliotecaRAGParagrafo]
        let notas: [BibliotecaRAGNotaRodape]
        let imagens: [BibliotecaRAGImagem]
    }

    static func importar(url: URL, obra: BibliotecaObra) throws -> Resultado {
        guard let documento = PDFDocument(url: url) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var paginas: [BibliotecaRAGPagina] = []
        var paragrafos: [BibliotecaRAGParagrafo] = []
        var notas: [BibliotecaRAGNotaRodape] = []
        var imagens: [BibliotecaRAGImagem] = []

        for indice in 0..<documento.pageCount {
            guard let pagina = documento.page(at: indice) else {
                continue
            }

            let numeroPagina = indice + 1
            let bounds = pagina.bounds(for: .mediaBox)
            let textoPagina = normalizarTextoPagina(pagina.string ?? "")
            let partes = separarTextoERodape(textoPagina)
            let titulo = detectarTitulo(partes.textoPrincipal, fallback: obra.titulo)
            let blocos = separarParagrafos(partes.textoPrincipal)

            paginas.append(
                BibliotecaRAGPagina(
                    obraID: obra.id,
                    numeroOriginal: numeroPagina,
                    titulo: titulo,
                    textoIntegral: textoPagina,
                    largura: Double(bounds.width),
                    altura: Double(bounds.height)
                )
            )

            for (ordem, texto) in blocos.enumerated() {
                paragrafos.append(
                    BibliotecaRAGParagrafo(
                        obraID: obra.id,
                        pagina: numeroPagina,
                        ordem: ordem + 1,
                        texto: texto,
                        capitulo: nil,
                        secao: titulo,
                        temas: obra.assuntos,
                        palavrasChave: palavrasChave(texto: texto, assuntosObra: obra.assuntos)
                    )
                )
            }

            for nota in extrairNotas(partes.rodape, obraID: obra.id, pagina: numeroPagina) {
                notas.append(nota)
            }

            if bounds.width > 0, bounds.height > 0 {
                imagens.append(
                    BibliotecaRAGImagem(
                        id: "\(obra.id)-facsimile-\(numeroPagina)",
                        obraID: obra.id,
                        pagina: numeroPagina,
                        caminhoRelativo: "facsimiles/\(obra.id)/pagina-\(String(format: "%04d", numeroPagina)).jpg",
                        largura: Double(bounds.width),
                        altura: Double(bounds.height),
                        descricaoOCR: nil
                    )
                )
            }
        }

        let ragObra = BibliotecaRAGObra(
            id: obra.id,
            area: obra.area,
            tipo: obra.tipo,
            titulo: obra.titulo,
            autor: obra.autor,
            origem: url.lastPathComponent,
            edicao: nil,
            assuntos: obra.assuntos,
            dataImportacao: Date()
        )

        return Resultado(
            obra: ragObra,
            paginas: paginas,
            paragrafos: paragrafos,
            notas: notas,
            imagens: imagens
        )
    }

    static func importarNoBanco(url: URL, obra: BibliotecaObra, banco: BibliotecaSQLiteService) throws {
        let resultado = try importar(url: url, obra: obra)
        try banco.substituirObra(
            obra: resultado.obra,
            paginas: resultado.paginas,
            paragrafos: resultado.paragrafos,
            notas: resultado.notas,
            imagens: resultado.imagens
        )
    }

    private static func normalizarTextoPagina(_ texto: String) -> String {
        texto
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { linha in
                linha
                    .replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func separarTextoERodape(_ texto: String) -> (textoPrincipal: String, rodape: String) {
        let linhas = texto.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard linhas.count > 4 else {
            return (texto, "")
        }

        if let separador = linhas.lastIndex(where: { linha in
            let limpa = linha.trimmingCharacters(in: .whitespaces)
            return limpa.count >= 8 && limpa.allSatisfy { caractere in
                caractere == "-" || caractere == "_" || caractere == "—" || caractere == "―"
            }
        }) {
            let principal = linhas[..<separador].joined(separator: "\n")
            let rodape = linhas[linhas.index(after: separador)...].joined(separator: "\n")
            return (principal.trimmingCharacters(in: .whitespacesAndNewlines), rodape.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let possivelRodape = linhas.suffix(8)
        guard let inicioRodapeRelativo = possivelRodape.firstIndex(where: { linha in
            linha.trimmingCharacters(in: .whitespaces).range(of: #"^\d{1,4}\s+\S"#, options: .regularExpression) != nil
        }) else {
            return (texto, "")
        }

        let inicioRodape = inicioRodapeRelativo
        let principal = linhas[..<inicioRodape].joined(separator: "\n")
        let rodape = linhas[inicioRodape...].joined(separator: "\n")
        return (principal.trimmingCharacters(in: .whitespacesAndNewlines), rodape.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func separarParagrafos(_ texto: String) -> [String] {
        let linhas = texto
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        var paragrafos: [String] = []
        var atual: [String] = []

        for linha in linhas {
            if linha.isEmpty {
                finalizarParagrafo(&atual, em: &paragrafos)
                continue
            }

            if deveIniciarNovoParagrafo(linha: linha, anterior: atual.last) {
                finalizarParagrafo(&atual, em: &paragrafos)
            }

            atual.append(linha)
        }

        finalizarParagrafo(&atual, em: &paragrafos)
        return paragrafos
    }

    private static func finalizarParagrafo(_ atual: inout [String], em paragrafos: inout [String]) {
        guard atual.isEmpty == false else {
            return
        }

        let texto = atual.joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if texto.isEmpty == false {
            paragrafos.append(texto)
        }

        atual.removeAll(keepingCapacity: true)
    }

    private static func deveIniciarNovoParagrafo(linha: String, anterior: String?) -> Bool {
        guard let anterior, anterior.isEmpty == false else {
            return false
        }

        if linha.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) != nil {
            return true
        }

        if linha.count < 80, linha == linha.uppercased(), linha.rangeOfCharacter(from: .letters) != nil {
            return true
        }

        let finalizadores = CharacterSet(charactersIn: ".!?;:")
        return anterior.rangeOfCharacter(from: finalizadores, options: .backwards) != nil
            && linha.first?.isUppercase == true
            && anterior.hasSuffix("-") == false
    }

    private static func extrairNotas(_ rodape: String, obraID: String, pagina: Int) -> [BibliotecaRAGNotaRodape] {
        guard rodape.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return []
        }

        var notas: [BibliotecaRAGNotaRodape] = []
        var numeroAtual: String?
        var linhasAtual: [String] = []
        var ocorrenciasPorNumero: [String: Int] = [:]

        func finalizar() {
            guard let numeroAtual else {
                return
            }

            let texto = linhasAtual.joined(separator: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if texto.isEmpty == false {
                let ordem = (ocorrenciasPorNumero[numeroAtual] ?? 0) + 1
                ocorrenciasPorNumero[numeroAtual] = ordem
                notas.append(BibliotecaRAGNotaRodape(
                    obraID: obraID,
                    pagina: pagina,
                    numero: numeroAtual,
                    texto: texto,
                    ordem: ordem
                ))
            }
        }

        for linha in rodape.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let limpa = linha.trimmingCharacters(in: .whitespaces)
            if let match = limpa.range(of: #"^\d{1,4}\b"#, options: .regularExpression) {
                finalizar()
                numeroAtual = String(limpa[match])
                linhasAtual = [String(limpa[match.upperBound...]).trimmingCharacters(in: .whitespaces)]
            } else if limpa.isEmpty == false {
                linhasAtual.append(limpa)
            }
        }

        finalizar()
        return notas
    }

    private static func detectarTitulo(_ texto: String, fallback: String) -> String? {
        let candidatos = texto
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 3 && $0.count < 90 }

        return candidatos.first { linha in
            linha == linha.uppercased() && linha.rangeOfCharacter(from: .letters) != nil
        } ?? candidatos.first ?? fallback
    }

    private static func palavrasChave(texto: String, assuntosObra: [String]) -> [String] {
        let stopwords: Set<String> = [
            "para", "pela", "pelo", "como", "mais", "entre", "sobre", "seus", "suas",
            "este", "esta", "esse", "essa", "aquela", "aquele", "com", "dos", "das",
            "uma", "uns", "que", "por", "sem", "não", "são", "foi", "ser"
        ]
        let tokens = texto
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && stopwords.contains($0) == false }

        var vistos = Set<String>()
        let principais = tokens.filter { token in
            if vistos.contains(token) {
                return false
            }
            vistos.insert(token)
            return true
        }

        return Array((assuntosObra + principais).prefix(16))
    }
}
