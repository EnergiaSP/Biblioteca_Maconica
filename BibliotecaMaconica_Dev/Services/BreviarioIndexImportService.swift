import Foundation

extension BreviarioImportService {
static func criarEntradasIndice(_ linha: String) -> [(termo: String, paginas: [Int])] {
        let linhaLimpa = linha.trimmingCharacters(in: .whitespacesAndNewlines)

        guard linhaLimpa.isEmpty == false,
              linhaLimpa.range(of: #"\d+"#, options: .regularExpression) != nil else {
            return []
        }

        let linhaComColunasSeparadas = linhaLimpa.replacingOccurrences(
            of: #"(?<=\d)\s+(?=[A-ZÀ-Ý])"#,
            with: "\u{1E}",
            options: .regularExpression
        )

        return linhaComColunasSeparadas
            .split(separator: "\u{1E}")
            .compactMap { criarEntradaIndice(String($0)) }
    }

    static func criarEntradaIndice(_ segmento: String) -> (termo: String, paginas: [Int])? {
        let segmentoLimpo = segmento.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let rangePaginas = segmentoLimpo.range(
            of: #"\s+\d+(?:\s*[,;]\s*\d+)*\s*$"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let paginas = segmentoLimpo[rangePaginas].matches(of: /\d+/).compactMap {
            Int($0.output)
        }

        let termo = segmentoLimpo[..<rangePaginas.lowerBound]
            .trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines
                    .union(CharacterSet(charactersIn: ".·•"))
            )

        guard termo.isEmpty == false, paginas.isEmpty == false else {
            return nil
        }

        return (termo, Array(Set(paginas)).sorted())
    }

    static func vincularIndice(
        _ indice: [IndiceRemissivoEntry],
        aos itens: [BreviarioItem]
    ) -> [IndiceRemissivoEntry] {
        let datasPorPagina = itens.reduce(into: [Int: Set<String>]()) { parcial, item in
            if let paginaObra = paginaDaObra(item) {
                parcial[paginaObra, default: []].insert(item.data)
            } else if let paginaInferida = paginaImpressaInferida(item) {
                parcial[paginaInferida, default: []].insert(item.data)
            }
        }

        return indice.map { entrada in
            let datas = entrada.paginas.reduce(into: Set<String>()) { parcial, pagina in
                guard let datasPagina = datasPorPagina[pagina] else {
                    return
                }

                parcial.formUnion(datasPagina)
            }

            return IndiceRemissivoEntry(
                id: entrada.id,
                termo: entrada.termo,
                paginas: entrada.paginas,
                datas: Array(datas).sorted()
            )
        }
    }

    static func paginaDaObra(_ item: BreviarioItem) -> Int? {
        guard let rodape = item.rodape else {
            return nil
        }

        return rodape
            .matches(of: /\b\d{1,3}\b/)
            .compactMap { Int($0.output) }
            .last
    }

    static func paginaImpressaInferida(_ item: BreviarioItem) -> Int? {
        guard let pagina = item.pagina else {
            return nil
        }

        if pagina <= 75 {
            return pagina + 6
        }

        return pagina + 4
    }
}
