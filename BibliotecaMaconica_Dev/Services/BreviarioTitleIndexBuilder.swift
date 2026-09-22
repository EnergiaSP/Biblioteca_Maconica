import Foundation

extension BreviarioImportService {
static func tituloGenerico(
        linhas: [String],
        tituloObra: String,
        pagina: Int,
        tipo: BibliotecaObraTipo
    ) -> String {
        if let titulo = tituloEstruturado(linhas: linhas, tipo: tipo) {
            return titulo
        }

        let candidato = linhas.first { linha in
            let linhaLimpa = linha.trimmingCharacters(in: .whitespacesAndNewlines)
            return linhaLimpa.count >= 4
                && linhaLimpa.count <= 90
                && pareceRodape(linhaLimpa) == false
                && primeiraData(em: linhaLimpa) == nil
        }

        if let candidato {
            return corrigirSubstituicoesOCR(candidato)
        }

        return "\(tituloObra) - página \(pagina)"
    }

    static func tituloEstruturado(
        linhas: [String],
        tipo: BibliotecaObraTipo
    ) -> String? {
        let candidatos = linhas.prefix(12).map {
            corrigirSubstituicoesOCR($0.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        .filter { $0.isEmpty == false }

        let padroes: [String]
        switch tipo {
        case .dicionario:
            padroes = [
                #"^[A-ZÁÉÍÓÚÂÊÔÃÕÇ][A-ZÁÉÍÓÚÂÊÔÃÕÇ\s\-]{2,60}$"#,
                #"^(Verbete|Termo)\s*[:\-]\s*.{2,80}$"#
            ]
        case .judiciario:
            padroes = [
                #"^(Art\.|Artigo|Capítulo|Capitulo|Seção|Secao|Título|Titulo)\s+.{1,90}$"#,
                #"^(Norma|Regulamento|Constituição|Constituicao|Código|Codigo)\s+.{1,90}$"#
            ]
        case .livro, .apostila:
            padroes = [
                #"^(Capítulo|Capitulo|Parte|Livro|Aula|Instrução|Instrucao)\s+.{1,90}$"#,
                #"^[IVXLCDM]+\s*[\-–.]\s*.{2,90}$"#
            ]
        case .artigo:
            padroes = [
                #"^(Resumo|Introdução|Introducao|Seção|Secao|Conclusão|Conclusao)\s*$"#,
                #"^.{8,90}$"#
            ]
        case .breviarioDiario:
            return nil
        }

        for candidato in candidatos {
            guard pareceRodape(candidato) == false,
                  primeiraData(em: candidato) == nil else {
                continue
            }

            if padroes.contains(where: { candidato.range(of: $0, options: .regularExpression) != nil }) {
                return candidato
            }
        }

        return nil
    }

    static func gerarIndiceRemissivoBasico(itens: [BreviarioItem]) -> [IndiceRemissivoEntry] {
        var ocorrencias: [String: (paginas: Set<Int>, datas: Set<String>)] = [:]
        let ignoradas: Set<String> = [
            "ainda", "assim", "cada", "como", "com", "das", "dos", "de", "da", "do", "em", "entre",
            "essa", "esse", "esta", "este", "isto", "mais", "mas", "não", "nas", "nos", "para", "pela",
            "pelo", "por", "que", "sao", "são", "seu", "sua", "suas", "seus", "uma", "uns", "ver"
        ]

        for item in itens {
            let texto = [item.titulo, item.frase, item.texto]
                .joined(separator: " ")
                .folding(options: [.caseInsensitive], locale: Locale(identifier: "pt_BR"))

            let palavras = texto
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { palavra in
                    palavra.count >= 5
                        && ignoradas.contains(palavra.lowercased()) == false
                        && palavra.rangeOfCharacter(from: .decimalDigits) == nil
                }

            let frequencia = Dictionary(grouping: palavras, by: { $0.lowercased() })
                .mapValues(\.count)
                .filter { $0.value >= 2 }

            for termo in frequencia.keys.prefix(36) {
                var registro = ocorrencias[termo] ?? (paginas: [], datas: [])
                if let pagina = item.pagina {
                    registro.paginas.insert(pagina)
                }
                registro.datas.insert(item.data)
                ocorrencias[termo] = registro
            }
        }

        return ocorrencias
            .sorted { primeira, segunda in
                primeira.key.localizedCaseInsensitiveCompare(segunda.key) == .orderedAscending
            }
            .prefix(400)
            .enumerated()
            .map { indice, elemento in
                IndiceRemissivoEntry(
                    id: indice + 1,
                    termo: elemento.key.capitalized(with: Locale(identifier: "pt_BR")),
                    paginas: elemento.value.paginas.sorted(),
                    datas: elemento.value.datas.sorted()
                )
            }
    }

    static func limpar(_ linhas: [String]) -> [String] {
        var resultado = linhas

        while resultado.first?.isEmpty == true {
            resultado.removeFirst()
        }

        while resultado.last?.isEmpty == true {
            resultado.removeLast()
        }

        return resultado
    }

    static let marcadorRodapePorLayout = "<<<RODAPE_POR_LINHA_DO_PDF>>>"
}
extension String {
    var nilSeVazio: String? {
        isEmpty ? nil : self
    }
}
