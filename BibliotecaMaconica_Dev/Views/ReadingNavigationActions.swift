import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
func abrirData(_ data: Date) {
        if let item = store.item(dataEscolhida: data) {
            abrirLeitura(item)
            mensagemErro = nil
        } else {
            mensagemErro = "Nenhum texto encontrado para a data selecionada."
        }
    }

    func abrirURLBreviario(_ url: URL, permiteAdiar: Bool = true) {
        guard url.scheme == "breviario" else {
            return
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        let obraQuery = queryItems?
            .first(where: { $0.name == "obra" || $0.name == "obraID" })?
            .value
        let dataQuery = queryItems?
            .first(where: { $0.name == "data" })?
            .value?
            .replacingOccurrences(of: "-", with: "/")

        if let obraQuery, obraQuery != store.obraSelecionada.id {
            if permiteAdiar {
                urlBreviarioPendente = url
            }
            store.selecionarObra(id: obraQuery)
            return
        }

        guard let dataQuery else {
            mensagemErro = "Nao foi possivel abrir a leitura do widget."
            return
        }

        guard let item = store.item(data: dataQuery) else {
            if permiteAdiar, store.carregando || store.itens.isEmpty {
                urlBreviarioPendente = url
                return
            }

            mensagemErro = "Nao foi possivel abrir a leitura do widget."
            return
        }

        abrirLeitura(item)
        urlBreviarioPendente = nil
        mensagemErro = nil
    }

    func processarURLBreviarioPendenteSePossivel() {
        guard let url = urlBreviarioPendente,
              store.carregando == false,
              store.itens.isEmpty == false else {
            return
        }

        abrirURLBreviario(url, permiteAdiar: false)
    }

    func abrirEntradaIndice(_ entrada: IndiceRemissivoEntry, pagina: Int?) {
        if let pagina,
           let item = store.item(paginaDaObra: pagina) {
            abrirLeitura(item)
            mensagemErro = nil
        } else if let data = entrada.datas.first, let item = store.item(data: data) {
            abrirLeitura(item)
            mensagemErro = nil
        } else if let pagina = entrada.paginas.first,
                  let item = store.item(paginaDaObra: pagina) {
            abrirLeitura(item)
            mensagemErro = nil
        } else {
            mensagemErro = "Entrada sem texto vinculado ainda."
            abrirMais(.indicesBiblioteca)
        }
    }

    func abrirProximaLeituraDoMes() {
        guard let item = itensMesAtual.first(where: { leiturasConcluidas.contains($0.data) == false }) else {
            mensagemErro = "Todas as leituras do mês foram concluídas."
            return
        }

        abrirLeitura(item)
        mensagemErro = nil
    }

    func abrirProximaLeituraDaSemana() {
        guard let item = itensSemanaAtual.first(where: { leiturasConcluidas.contains($0.data) == false }) else {
            mensagemErro = "Todas as leituras da semana foram concluídas."
            return
        }

        abrirLeitura(item)
        mensagemErro = nil
    }

    func retrocederDia() {
        guard let item = itemSelecionado,
              let anterior = store.itemAnterior(ao: item) else {
            return
        }

        itemSelecionadoID = anterior.id
        if abaSelecionada == 3 {
            caminhoLeitura = [anterior.id]
        } else {
            caminhoLeitura.removeAll()
        }
    }

    func avancarDia() {
        guard let item = itemSelecionado,
              let proximo = store.proximoItem(ao: item) else {
            return
        }

        itemSelecionadoID = proximo.id
        if abaSelecionada == 3 {
            caminhoLeitura = [proximo.id]
        } else {
            caminhoLeitura.removeAll()
        }
    }

    func copiarTexto(_ item: BreviarioItem, incluirComentario: Bool) {
        UIPasteboard.general.string = textoCompartilhavel(
            item,
            incluirComentario: incluirComentario
        )
        mensagemErro = incluirComentario ? "Texto justificado e comentário copiados." : "Texto justificado copiado."
    }

    func compartilharWhatsApp(_ item: BreviarioItem, incluirComentario: Bool) {
        compartilhamento = Compartilhamento(
            items: [
                textoCompartilhavel(
                    item,
                    incluirComentario: incluirComentario
                )
            ]
        )
        mensagemErro = incluirComentario
            ? "Escolha WhatsApp para enviar o texto justificado com comentário."
            : "Escolha WhatsApp para enviar o texto justificado completo."
    }

    func textoCompartilhavel(
        _ item: BreviarioItem,
        incluirComentario: Bool
    ) -> String {
        let textoBase = textoCompartilhavelJustificado(item)

        guard incluirComentario, comentarioAtualTrimmed.isEmpty == false else {
            return textoBase
        }

        return [
            textoBase,
            "--------------------\n\nComentário pessoal:\n\n\(Self.justificarTextoParaCompartilhamento(comentarioAtualTrimmed, chamadasRodape: item.chamadasRodape))"
        ].joined(separator: "\n\n")
    }

    func textoCompartilhavelJustificado(_ item: BreviarioItem) -> String {
        var partes = [
            item.obraID != ObraID.breviarioSeculoXXI && item.obraID == store.obraSelecionada.id
                ? store.obraSelecionada.titulo : item.cabecalhoDocumental,
            item.referenciaExibicao,
            item.titulo,
            Self.justificarTextoParaCompartilhamento(item.texto, chamadasRodape: item.chamadasRodape)
        ]

        if let rodape = item.rodape?.trimmingCharacters(in: .whitespacesAndNewlines),
           rodape.isEmpty == false {
            let rodapeFormatado = Self.justificarRodapeParaCompartilhamento(
                rodape,
                chamadasRodape: item.chamadasRodape
            )
            partes.append("--------------------\n\nNotas de rodapé:\n\n\(rodapeFormatado)")
        }

        if let autor = item.autorDocumental { partes.append("Autor: \(autor)") }
        return partes.joined(separator: "\n\n")
    }

    nonisolated static func justificarTextoParaCompartilhamento(
        _ texto: String,
        largura: Int = 54,
        chamadasRodape: Set<String> = []
    ) -> String {
        let textoPreparado = converterChamadasRodapeParaSobrescrito(texto, chamadasRodape: chamadasRodape)
        return TextoLeituraFormatter.comParagrafosVisiveis(textoPreparado)
            .components(separatedBy: "\n\n")
            .map { justificarParagrafo($0, largura: largura) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n\n")
    }

    nonisolated static func justificarRodapeParaCompartilhamento(
        _ rodape: String,
        largura: Int = 54,
        chamadasRodape: Set<String>
    ) -> String {
        TextoLeituraFormatter.rodapeComNotasEmLinhas(
            rodape,
            chamadasRodape: chamadasRodape
        )
        .components(separatedBy: "\n")
        .map { justificarParagrafo($0, largura: largura) }
        .filter { $0.isEmpty == false }
        .joined(separator: "\n")
    }

    nonisolated static func converterChamadasRodapeParaSobrescrito(
        _ texto: String,
        chamadasRodape: Set<String>
    ) -> String {
        guard chamadasRodape.isEmpty == false else {
            return texto
        }

        let textoCompleto = texto as NSString
        let padrao = #"(?<![\d/])\d{1,4}(?![\d/])"#
        guard let regex = try? NSRegularExpression(pattern: padrao) else {
            return texto
        }

        var resultado = texto
        let rangeTotal = NSRange(location: 0, length: textoCompleto.length)
        let matches = regex.matches(in: texto, range: rangeTotal).reversed()

        for match in matches {
            let numero = textoCompleto.substring(with: match.range)
            guard chamadasRodape.contains(numero),
                  ehChamadaRodapeParaCompartilhamento(match.range, em: textoCompleto),
                  let rangeSwift = Range(match.range, in: resultado) else {
                continue
            }

            resultado.replaceSubrange(rangeSwift, with: numeroSobrescrito(numero))
        }

        return resultado
    }

    nonisolated static func ehChamadaRodapeParaCompartilhamento(
        _ range: NSRange,
        em texto: NSString
    ) -> Bool {
        guard range.location > 0 else {
            return false
        }

        var indiceAnterior = range.location - 1
        var anteriorValido: UnicodeScalar?
        while indiceAnterior >= 0 {
            guard let anterior = UnicodeScalar(texto.character(at: indiceAnterior)) else {
                return false
            }

            if CharacterSet.whitespacesAndNewlines.contains(anterior) {
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

        let proximoIndice = range.location + range.length
        if proximoIndice < texto.length {
            guard let proximo = UnicodeScalar(texto.character(at: proximoIndice)) else {
                return false
            }

            if CharacterSet.decimalDigits.contains(proximo) || proximo == "/" {
                return false
            }
        }

        return true
    }

    nonisolated static func numeroSobrescrito(_ numero: String) -> String {
        let mapa: [Character: Character] = [
            "0": "⁰",
            "1": "¹",
            "2": "²",
            "3": "³",
            "4": "⁴",
            "5": "⁵",
            "6": "⁶",
            "7": "⁷",
            "8": "⁸",
            "9": "⁹"
        ]

        return String(numero.map { mapa[$0] ?? $0 })
    }

    nonisolated static func justificarParagrafo(_ paragrafo: String, largura: Int) -> String {
        let palavras = paragrafo
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { $0.isEmpty == false }

        guard palavras.isEmpty == false else {
            return ""
        }

        return palavras.joined(separator: " ")
    }
}
