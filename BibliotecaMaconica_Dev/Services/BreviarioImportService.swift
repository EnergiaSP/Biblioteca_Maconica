import Foundation

enum BreviarioImportService {
static let cabecalho = "Breviário Maçônico"
    static let autorPadrao = "Kennyo Ismail"
    static let limitePaginasDiarias = 367

    static func importar(textoOCR: String) -> BreviarioData {
        let linhas = textoOCR
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let autor = extrairAutor(linhas: linhas) ?? autorPadrao
        let indice = extrairIndiceRemissivo(linhas: linhas)
        let secoes = separarPorData(linhas: removerIndiceRemissivo(linhas: linhas))

        let itensImportados = secoes.enumerated().map { indice, secao in
            criarItem(
                id: indice + 1,
                data: secao.data,
                linhas: secao.linhas,
                autor: autor,
                pagina: secao.pagina
            )
        }
        let itens = marcarTextosDuplicados(
            reindexarDatas(removerDuplicatasConhecidas(itensImportados))
        )

        return BreviarioData(
            itens: itens,
            indiceRemissivo: vincularIndice(indice, aos: itens)
        )
    }

    static func importarObraGenerica(
        textoOCR: String,
        tituloObra: String,
        autor: String?,
        obraID: String,
        tipo: BibliotecaObraTipo
    ) -> BreviarioData {
        let linhas = textoOCR
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let autorFinal = autor?.trimmingCharacters(in: .whitespacesAndNewlines).nilSeVazio
            ?? extrairAutor(linhas: linhas)
        let paginas = separarPorPagina(linhas: linhas)

        let itens = paginas.enumerated().compactMap { indice, pagina -> BreviarioItem? in
            var linhasCorpo = limpar(pagina.linhas)
            let rodapeExtraido = extrairRodape(linhas: &linhasCorpo)
            let linhasLimpas = limpar(linhasCorpo)
            let textoImportado = recomporParagrafos(linhasLimpas)
            let textoComRodapeSeparado = separarRodapeEmbutido(
                texto: textoImportado,
                rodape: rodapeExtraido
            )
            let texto = corrigirSubstituicoesOCR(textoComRodapeSeparado.texto)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let rodape = textoComRodapeSeparado.rodape
                .map(corrigirSubstituicoesOCR)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilSeVazio

            let textoFinal = texto.isEmpty
                ? "Texto não reconhecido automaticamente nesta página. Consulte a página original do PDF preservada abaixo."
                : texto

            let tituloDetectado = tituloGenerico(
                linhas: linhasLimpas,
                tituloObra: tituloObra,
                pagina: pagina.pagina,
                tipo: tipo
            )

            return BreviarioItem(
                id: indice + 1,
                data: "P\(pagina.pagina)",
                titulo: tituloDetectado,
                frase: extrairFrase(texto: textoFinal),
                texto: textoFinal,
                rodape: rodape,
                autor: autorFinal,
                pagina: pagina.pagina,
                obraID: obraID
            )
        }

        return BreviarioData(
            itens: itens,
            indiceRemissivo: gerarIndiceRemissivoBasico(itens: itens)
        )
    }

    static func corrigirRodapesEmbutidos(itens: [BreviarioItem]) -> [BreviarioItem] {
        itens.map { item in
            let textoComRodapeSeparado = separarRodapeEmbutido(
                texto: item.texto,
                rodape: item.rodape
            )

            guard textoComRodapeSeparado.texto != item.texto
                    || textoComRodapeSeparado.rodape != item.rodape else {
                return item
            }

            return BreviarioItem(
                id: item.id,
                data: item.data,
                titulo: item.titulo,
                frase: extrairFrase(texto: textoComRodapeSeparado.texto),
                texto: textoComRodapeSeparado.texto,
                rodape: textoComRodapeSeparado.rodape,
                autor: item.autor,
                pagina: item.pagina,
                obraID: item.obraID,
                paginaMidia: item.paginaMidia
            )
        }
    }

    static func separarPorData(linhas: [String]) -> [(data: String, linhas: [String], pagina: Int?)] {
        var resultado: [(data: String, linhas: [String], pagina: Int?)] = []
        var dataAtual: String?
        var paginaAtual: Int?
        var paginaDaSecao: Int?
        var buffer: [String] = []
        var primeiraLinhaDaPagina = false
        var proximoDiaOrdinal = 1
        var datasUsadas: Set<String> = []

        func finalizarSecao(data: String?, linhas: [String], pagina: Int?) {
            if let data {
                resultado.append((data, limpar(linhas), pagina))
                datasUsadas.insert(data)

                if let ordinal = ordinalDoDia(data) {
                    proximoDiaOrdinal = ordinal + 1
                }
            } else if limpar(linhas).isEmpty == false {
                resultado.append(("00/00", limpar(linhas), pagina))
            }
        }

        for linha in linhas {
            if let pagina = marcadorPagina(em: linha) {
                finalizarSecao(data: dataAtual, linhas: buffer, pagina: paginaDaSecao)
                buffer = []

                paginaAtual = pagina
                paginaDaSecao = pagina
                dataAtual = pagina <= limitePaginasDiarias
                    ? proximaDataLivre(aPartirDe: proximoDiaOrdinal, datasUsadas: datasUsadas)
                    : nil
                primeiraLinhaDaPagina = true
                continue
            }

            guard linha.isEmpty == false else {
                buffer.append(linha)
                continue
            }

            if let data = primeiraData(em: linha) {
                if primeiraLinhaDaPagina, paginaDaSecao != nil {
                    if paginaDaSecao.map({ $0 <= limitePaginasDiarias }) == true {
                        dataAtual = deveAceitarDataLida(data, proximoDiaOrdinal: proximoDiaOrdinal, datasUsadas: datasUsadas)
                            ? data
                            : proximaDataLivre(aPartirDe: proximoDiaOrdinal, datasUsadas: datasUsadas)
                    } else {
                        dataAtual = data
                    }

                    let restante = linha.replacingOccurrences(of: data, with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if restante.isEmpty == false {
                        buffer.append(restante)
                    }
                    primeiraLinhaDaPagina = false
                    continue
                } else if paginaDaSecao != nil, dataAtual != nil {
                    buffer.append(linha)
                    primeiraLinhaDaPagina = false
                    continue
                } else if data != dataAtual, let dataAtual {
                    finalizarSecao(data: dataAtual, linhas: buffer, pagina: paginaDaSecao)
                    buffer = []
                } else if dataAtual == nil, limpar(buffer).isEmpty == false {
                    finalizarSecao(data: nil, linhas: buffer, pagina: paginaDaSecao)
                    buffer = []
                }

                dataAtual = data
                paginaDaSecao = paginaAtual
                let restante = linha.replacingOccurrences(of: data, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                buffer = restante.isEmpty ? [] : [restante]
                primeiraLinhaDaPagina = false
            } else if primeiraLinhaDaPagina && pareceCabecalhoDataIlegivel(linha) {
                primeiraLinhaDaPagina = false
            } else {
                buffer.append(linha)
                primeiraLinhaDaPagina = false
            }
        }

        finalizarSecao(data: dataAtual, linhas: buffer, pagina: paginaDaSecao)

        return resultado
    }

    static func separarPorPagina(linhas: [String]) -> [(pagina: Int, linhas: [String])] {
        var resultado: [(pagina: Int, linhas: [String])] = []
        var paginaAtual: Int?
        var buffer: [String] = []

        func finalizar() {
            guard let paginaAtual else {
                return
            }

            resultado.append((paginaAtual, limpar(buffer)))
            buffer = []
        }

        for linha in linhas {
            if let pagina = marcadorPagina(em: linha) {
                finalizar()
                paginaAtual = pagina
                buffer = []
                continue
            }

            buffer.append(linha)
        }

        finalizar()

        if resultado.isEmpty {
            let texto = limpar(linhas)
            guard texto.isEmpty == false else {
                return []
            }

            return [(1, texto)]
        }

        return resultado
    }

    static func dataParaOrdinal(_ ordinal: Int) -> String? {
        guard (1...365).contains(ordinal) else {
            return nil
        }

        var componentes = DateComponents()
        componentes.calendar = Calendar(identifier: .gregorian)
        componentes.year = 2023
        componentes.month = 1
        componentes.day = 1

        guard let primeiroDia = componentes.date,
              let data = componentes.calendar?.date(byAdding: .day, value: ordinal - 1, to: primeiroDia) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: data)
    }

    static func proximaDataLivre(aPartirDe ordinalInicial: Int, datasUsadas: Set<String>) -> String? {
        guard ordinalInicial <= 365 else {
            return nil
        }

        for ordinal in ordinalInicial...365 {
            guard let data = dataParaOrdinal(ordinal) else {
                continue
            }

            if datasUsadas.contains(data) == false {
                return data
            }
        }

        return nil
    }

    static func deveAceitarDataLida(
        _ data: String,
        proximoDiaOrdinal: Int,
        datasUsadas: Set<String>
    ) -> Bool {
        guard datasUsadas.contains(data) == false,
              let ordinal = ordinalDoDia(data) else {
            return false
        }

        return ordinal >= proximoDiaOrdinal - 1
            && ordinal <= proximoDiaOrdinal + 1
    }

    static func ordinalDoDia(_ data: String) -> Int? {
        let componentes = data.split(separator: "/").compactMap { Int($0) }

        guard componentes.count == 2 else {
            return nil
        }

        var dataComponentes = DateComponents()
        dataComponentes.calendar = Calendar(identifier: .gregorian)
        dataComponentes.year = 2023
        dataComponentes.month = componentes[1]
        dataComponentes.day = componentes[0]

        var inicioComponentes = DateComponents()
        inicioComponentes.calendar = dataComponentes.calendar
        inicioComponentes.year = 2023
        inicioComponentes.month = 1
        inicioComponentes.day = 1

        guard let dataCalculada = dataComponentes.date,
              let inicio = inicioComponentes.date,
              let diferenca = dataComponentes.calendar?.dateComponents([.day], from: inicio, to: dataCalculada).day,
              diferenca >= 0,
              diferenca < 365 else {
            return nil
        }

        return diferenca + 1
    }

    static func pareceCabecalhoDataIlegivel(_ linha: String) -> Bool {
        let texto = linha.trimmingCharacters(in: .whitespacesAndNewlines)

        guard texto.count <= 8 else {
            return false
        }

        return texto.contains("/")
            || texto.range(of: #"^[A-Z0-9СІDOCI/:\s]+$"#, options: .regularExpression) != nil
    }

    static func criarItem(
        id: Int,
        data: String,
        linhas: [String],
        autor: String?,
        pagina: Int?
    ) -> BreviarioItem {
        var linhasCorpo = linhas
        let titulo = extrairTitulo(linhas: &linhasCorpo, data: data)
        let rodapeLinhas = extrairRodape(linhas: &linhasCorpo)
        let textoImportado = recomporParagrafos(limpar(linhasCorpo))
        let textoComRodapeSeparado = separarRodapeEmbutido(
            texto: textoImportado,
            rodape: rodapeLinhas
        )
        let tituloCorrigido = corrigirSubstituicoesOCR(titulo)
        let texto = corrigirSubstituicoesOCR(textoComRodapeSeparado.texto)
        let rodape = textoComRodapeSeparado.rodape.map(corrigirSubstituicoesOCR)
        let frase = extrairFrase(texto: texto)

        return BreviarioItem(
            id: id,
            data: data,
            titulo: tituloCorrigido,
            frase: frase,
            texto: texto,
            rodape: rodape,
            autor: autor,
            pagina: pagina
        )
    }

    static func removerDuplicatasConhecidas(_ itens: [BreviarioItem]) -> [BreviarioItem] {
        let paginasDuplicadasDoOCR: Set<Int> = [76, 77]

        return itens.filter { item in
            if item.texto.trimmingCharacters(in: .whitespacesAndNewlines) == "," {
                return false
            }

            if let pagina = item.pagina, paginasDuplicadasDoOCR.contains(pagina) {
                return false
            }

            return true
        }
    }

    static func reindexarDatas(_ itens: [BreviarioItem]) -> [BreviarioItem] {
        itens.enumerated().map { indice, item in
            BreviarioItem(
                id: indice + 1,
                data: dataParaOrdinal(indice + 1) ?? item.data,
                titulo: item.titulo,
                frase: item.frase,
                texto: item.texto,
                rodape: item.rodape,
                autor: item.autor,
                pagina: item.pagina,
                obraID: item.obraID,
                paginaMidia: item.paginaMidia
            )
        }
    }

    static func marcarTextosDuplicados(_ itens: [BreviarioItem]) -> [BreviarioItem] {
        var textosVistos: Set<String> = []

        return itens.map { item in
            let chave = normalizarParaComparacao(item.texto)

            guard chave.isEmpty == false else {
                return item
            }

            if textosVistos.contains(chave) {
                let texto = """
                O PDF OCR fornecido repete integralmente aqui um texto ja importado em outra data. Para manter a fidelidade da obra, o conteudo duplicado foi removido desta entrada ate que a pagina correta seja fornecida.
                """

                return BreviarioItem(
                    id: item.id,
                    data: item.data,
                    titulo: "\(item.titulo) - texto duplicado no PDF OCR",
                    frase: texto,
                    texto: texto,
                    rodape: "Observacao de importacao: texto duplicado detectado no PDF OCR original.",
                    autor: item.autor,
                    pagina: item.pagina,
                    obraID: item.obraID,
                    paginaMidia: item.paginaMidia
                )
            }

            textosVistos.insert(chave)
            return item
        }
    }

    static func normalizarParaComparacao(_ texto: String) -> String {
        texto
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    static func extrairIndiceRemissivo(linhas: [String]) -> [IndiceRemissivoEntry] {
        let linhasIndice = linhasDoIndice(linhas: linhas)

        return linhasIndice.flatMap(criarEntradasIndice)
            .enumerated()
            .map { indice, entrada in
                IndiceRemissivoEntry(
                    id: indice + 1,
                    termo: corrigirSubstituicoesOCR(entrada.termo),
                    paginas: entrada.paginas,
                    datas: []
                )
            }
    }

    static func linhasDoIndice(linhas: [String]) -> [String] {
        guard let inicio = linhas.firstIndex(where: { linha in
            let normalizada = normalizar(linha)
            return normalizada.contains("indice remissivo")
                || normalizada == "indice"
                || normalizada == "index"
        }) else {
            return []
        }

        return Array(linhas[(inicio + 1)...])
    }

    static func removerIndiceRemissivo(linhas: [String]) -> [String] {
        guard let inicio = linhas.firstIndex(where: { linha in
            let normalizada = normalizar(linha)
            return normalizada.contains("indice remissivo")
                || normalizada == "indice"
                || normalizada == "index"
        }) else {
            return linhas
        }

        return Array(linhas[..<inicio])
    }
}
