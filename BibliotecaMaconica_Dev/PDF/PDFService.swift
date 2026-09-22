import UIKit

class PDFService {
enum PDFError: Error {
        case naoFoiPossivelCriarArquivo
    }

    struct Layout {
        var cabecalho: String = BreviarioImportService.cabecalho
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margem: CGFloat = 54
        let margemSuperiorConteudo: CGFloat = 88
        let margemInferiorConteudo: CGFloat = 74

        var largura: CGFloat {
            pageRect.width - (margem * 2)
        }

        var limiteInferior: CGFloat {
            pageRect.height - margemInferiorConteudo
        }
    }

    static let corPapel = UIColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1)
    static let corOuro = UIColor(red: 0.72, green: 0.55, blue: 0.20, alpha: 1)
    static let corOuroEscuro = UIColor(red: 0.42, green: 0.30, blue: 0.10, alpha: 1)
    static let corVerdeAcacia = UIColor(red: 0.22, green: 0.38, blue: 0.18, alpha: 1)

    static func gerarPDF(
        item: BreviarioItem,
        comentario: String,
        nomeUsuario: String = "",
        incluirComentario: Bool = false
    ) throws -> URL {

        let nomeArquivo = "Breviario-\(nomeArquivoData(item.referenciaExibicao)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nomeArquivo)
        let layout = Layout()
        let renderer = UIGraphicsPDFRenderer(
            bounds: layout.pageRect,
            format: formatoPDF(titulo: "\(item.referenciaExibicao) - \(item.titulo)", autor: item.autorDocumental)
        )

        try renderer.writePDF(to: url) { context in
            var pagina = 0
            desenharCapa(
                itens: [item],
                incluirComentarios: incluirComentario && comentario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                nomeUsuario: nomeUsuario,
                context: context,
                layout: layout
            )

            var y = iniciarPaginaPremium(
                context: context,
                layout: layout,
                pagina: &pagina,
                tituloRodape: item.referenciaExibicao
            )

            y = desenharItem(
                item,
                comentario: comentario,
                incluirComentario: incluirComentario,
                y: y,
                context: context,
                layout: layout,
                pagina: &pagina,
                indice: nil,
                total: nil
            )
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFError.naoFoiPossivelCriarArquivo
        }

        return url
    }

    static func gerarPDF(
        itens: [BreviarioItem],
        incluirComentarios: Bool,
        nomeUsuario: String = ""
    ) throws -> URL {
        let nomeArquivo = "Breviario-Exportacao-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nomeArquivo)
        let layout = Layout()
        let renderer = UIGraphicsPDFRenderer(
            bounds: layout.pageRect,
            format: formatoPDF(titulo: "Exportação - \(BreviarioImportService.cabecalho)", autor: autorPrincipal(itens))
        )

        try renderer.writePDF(to: url) { context in
            var pagina = 0
            desenharCapa(
                itens: itens,
                incluirComentarios: incluirComentarios,
                nomeUsuario: nomeUsuario,
                context: context,
                layout: layout
            )

            desenharIndiceExportacao(
                itens: itens,
                context: context,
                layout: layout,
                pagina: &pagina
            )

            for (indice, item) in itens.enumerated() {
                var y = iniciarPaginaPremium(
                    context: context,
                    layout: layout,
                    pagina: &pagina,
                    tituloRodape: "\(item.referenciaExibicao) - \(indice + 1)/\(itens.count)"
                )

                y = desenharItem(
                    item,
                    comentario: item.comentarioSalvo,
                    incluirComentario: incluirComentarios,
                    y: y,
                    context: context,
                    layout: layout,
                    pagina: &pagina,
                    indice: indice + 1,
                    total: itens.count
                )

                _ = y
            }
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFError.naoFoiPossivelCriarArquivo
        }

        return url
    }

    static func gerarPDFDestaques(
        item: BreviarioItem,
        destaques: [DestaqueLeitura],
        nomeUsuario: String = ""
    ) throws -> URL {
        let nomeArquivo = "Breviario-Destaques-\(nomeArquivoData(item.referenciaExibicao)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nomeArquivo)
        let layout = Layout()
        let renderer = UIGraphicsPDFRenderer(
            bounds: layout.pageRect,
            format: formatoPDF(titulo: "Destaques - \(item.referenciaExibicao)", autor: item.autor)
        )

        try renderer.writePDF(to: url) { context in
            var pagina = 0
            desenharCapaDestaques(
                item: item,
                destaques: destaques,
                nomeUsuario: nomeUsuario,
                context: context,
                layout: layout
            )

            var y = iniciarPaginaPremium(
                context: context,
                layout: layout,
                pagina: &pagina,
                tituloRodape: "Destaques"
            )

            y = desenhar(
                "Marcadores de \(item.referenciaExibicao)",
                em: CGRect(x: layout.margem, y: y, width: layout.largura, height: 34),
                fonte: .boldSystemFont(ofSize: 20),
                cor: .black
            )

            y += 12
            for destaque in destaques {
                y = desenharBlocoDestaque(
                    destaque.texto,
                    titulo: item.titulo,
                    y: y,
                    context: context,
                    layout: layout,
                    pagina: &pagina
                ) + 14
            }
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFError.naoFoiPossivelCriarArquivo
        }

        return url
    }

    static func gerarPDFDossieEstudo(
        _ dossie: BibliotecaDossieEstudo,
        nomeUsuario: String = "",
        analise: String = ""
    ) throws -> URL {
        let nomeArquivo = "Dossie-Estudo-\(nomeArquivoData(dossie.termo))-\(UUID().uuidString).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nomeArquivo)
        let layout = Layout(cabecalho: "Biblioteca Maçônica")
        let renderer = UIGraphicsPDFRenderer(
            bounds: layout.pageRect,
            format: formatoPDF(
                titulo: "Dossiê de estudo - \(dossie.termo)",
                autor: nomeUsuario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nomeUsuario
            )
        )

        try renderer.writePDF(to: url) { context in
            var pagina = 0

            desenharCapaDossie(
                dossie: dossie,
                nomeUsuario: nomeUsuario,
                context: context,
                layout: layout
            )

            var y = iniciarPaginaPremium(
                context: context,
                layout: layout,
                pagina: &pagina,
                tituloRodape: "Dossiê - \(dossie.termo)"
            )

            y = desenhar(
                "Dossiê de estudo",
                em: CGRect(x: layout.margem, y: y, width: layout.largura, height: 30),
                fonte: .boldSystemFont(ofSize: 20),
                cor: corOuroEscuro
            ) + 14

            y = desenharTextoPaginado(
                textoDossieEstudo(dossie, analise: analise),
                x: layout.margem,
                y: y,
                largura: layout.largura,
                layout: layout,
                fonte: .systemFont(ofSize: 12.5),
                cor: .black,
                lineSpacing: 5,
                paragraphSpacing: 7,
                alinhamento: .justified,
                context: context,
                pagina: &pagina,
                tituloRodape: "Dossiê - \(dossie.termo)"
            )

            _ = y
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFError.naoFoiPossivelCriarArquivo
        }

        return url
    }

    static func formatoPDF(titulo: String, autor: String?) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: titulo,
            kCGPDFContextCreator as String: "Breviário Maçônico do Século XXI"
        ]
        if let autor = autor?.trimmingCharacters(in: .whitespacesAndNewlines), !autor.isEmpty {
            format.documentInfo[kCGPDFContextAuthor as String] = autor
        }
        return format
    }

    static func autorPrincipal(_ itens: [BreviarioItem]) -> String? {
        let autores = itens.compactMap(\.autorDocumental).reduce(into: [String]()) { autores, autor in
            if !autores.contains(autor) { autores.append(autor) }
        }
        return autores.isEmpty ? nil : autores.joined(separator: "; ")
    }
}
