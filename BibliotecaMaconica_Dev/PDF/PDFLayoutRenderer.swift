import UIKit

extension PDFService {
static func desenharCapa(
        itens: [BreviarioItem],
        incluirComentarios: Bool,
        nomeUsuario: String,
        context: UIGraphicsPDFRendererContext,
        layout: Layout
    ) {
        context.beginPage()
        corPapel.setFill()
        UIBezierPath(rect: layout.pageRect).fill()

        desenharMolduraCapa(layout: layout)
        desenharFolhasAcacia(
            centro: CGPoint(x: layout.pageRect.midX, y: 108),
            escala: 0.95,
            cor: corVerdeAcacia.withAlphaComponent(0.28)
        )

        desenharCompassoEsquadro(
            centro: CGPoint(x: layout.pageRect.midX, y: 190),
            tamanho: 128,
            corMetal: corOuro,
            corLinha: .black,
            opacidade: 0.95
        )

        _ = desenhar(
            BreviarioImportService.cabecalho,
            em: CGRect(x: layout.margem, y: 282, width: layout.largura, height: 92),
            fonte: .boldSystemFont(ofSize: 29),
            cor: .black,
            alinhamento: .center
        )

        desenharSeparadorDecorativo(
            centroX: layout.pageRect.midX,
            y: 386,
            largura: layout.largura * 0.72,
            cor: corOuro
        )

        let intervalo = intervaloDescricao(itens)
        let possuiUmDia = itens.count == 1
        let comentario = incluirComentarios
            ? (possuiUmDia ? "com comentário salvo" : "com comentários salvos")
            : (possuiUmDia ? "sem comentário salvo" : "sem comentários salvos")
        let descricaoQuantidade = itens.count == 1 ? "1 dia selecionado" : "\(itens.count) dias selecionados"
        _ = desenhar(
            "\(descricaoQuantidade)\n\(intervalo)\n\(comentario)",
            em: CGRect(x: layout.margem, y: 420, width: layout.largura, height: 100),
            fonte: .systemFont(ofSize: 14),
            cor: .darkGray,
            alinhamento: .center,
            lineSpacing: 8
        )

        desenharFolhasAcacia(
            centro: CGPoint(x: layout.pageRect.midX, y: 612),
            escala: 0.72,
            cor: corVerdeAcacia.withAlphaComponent(0.58)
        )

        if !nomeUsuario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = desenhar(nomeUsuario, em: CGRect(x: layout.margem, y: 648, width: layout.largura, height: 28), fonte: .systemFont(ofSize: 12), cor: .darkGray, alinhamento: .center)
        }

        if let autor = autorPrincipal(itens), autor.isEmpty == false {
            _ = desenhar(
                "Autor: \(autor)",
                em: CGRect(x: layout.margem, y: 684, width: layout.largura, height: 28),
                fonte: .systemFont(ofSize: 12),
                cor: .darkGray,
                alinhamento: .center
            )
        }

        _ = desenhar(
            "Gerado em \(dataHoraAtualFormatada())",
            em: CGRect(x: layout.margem, y: 724, width: layout.largura, height: 24),
            fonte: .systemFont(ofSize: 11),
            cor: .darkGray,
            alinhamento: .center
        )
    }

    static func desenharCapaDestaques(
        item: BreviarioItem,
        destaques: [DestaqueLeitura],
        nomeUsuario: String,
        context: UIGraphicsPDFRendererContext,
        layout: Layout
    ) {
        context.beginPage()
        corPapel.setFill()
        UIBezierPath(rect: layout.pageRect).fill()
        desenharMolduraCapa(layout: layout)
        desenharFolhasAcacia(
            centro: CGPoint(x: layout.pageRect.midX, y: 118),
            escala: 0.78,
            cor: corVerdeAcacia.withAlphaComponent(0.46)
        )
        desenharCompassoEsquadro(
            centro: CGPoint(x: layout.pageRect.midX, y: 202),
            tamanho: 120,
            corMetal: corOuro,
            corLinha: .black,
            opacidade: 0.92
        )
        _ = desenhar(
            "Marcadores de leitura",
            em: CGRect(x: layout.margem, y: 318, width: layout.largura, height: 44),
            fonte: .boldSystemFont(ofSize: 28),
            cor: .black,
            alinhamento: .center
        )
        _ = desenhar(
            "\(item.referenciaExibicao)\n\(item.titulo)\n\(destaques.count) trechos favoritos",
            em: CGRect(x: layout.margem, y: 392, width: layout.largura, height: 110),
            fonte: .systemFont(ofSize: 15),
            cor: .darkGray,
            alinhamento: .center,
            lineSpacing: 8
        )
    }

    static func desenharIndiceExportacao(
        itens: [BreviarioItem],
        context: UIGraphicsPDFRendererContext,
        layout: Layout,
        pagina: inout Int
    ) {
        var y = iniciarPaginaPremium(
            context: context,
            layout: layout,
            pagina: &pagina,
            tituloRodape: "Índice"
        )

        y = desenhar(
            "Índice da exportação",
            em: CGRect(x: layout.margem, y: y, width: layout.largura, height: 34),
            fonte: .boldSystemFont(ofSize: 20),
            cor: .black
        )

        y += 18
        for item in itens {
            if y > layout.limiteInferior - 42 {
                y = iniciarPaginaPremium(
                    context: context,
                    layout: layout,
                    pagina: &pagina,
                    tituloRodape: "Índice"
                )
            }

            y = desenharTextoPaginado(
                "\(item.referenciaExibicao)  \(item.titulo)",
                x: layout.margem,
                y: y,
                largura: layout.largura,
                layout: layout,
                fonte: .systemFont(ofSize: 12, weight: .semibold),
                cor: .black,
                lineSpacing: 4,
                alinhamento: .left,
                context: context,
                pagina: &pagina,
                tituloRodape: "Índice"
            )

            if let paginaOriginal = item.pagina {
                y = desenharTextoPaginado(
                    "Página original: \(paginaOriginal)",
                    x: layout.margem,
                    y: y,
                    largura: layout.largura,
                    layout: layout,
                    fonte: .systemFont(ofSize: 9),
                    cor: .darkGray,
                    lineSpacing: 2,
                    alinhamento: .left,
                    context: context,
                    pagina: &pagina,
                    tituloRodape: "Índice"
                )
            }

            y += 4
        }
    }

    static func desenharItem(
        _ item: BreviarioItem,
        comentario: String,
        incluirComentario: Bool,
        y: CGFloat,
        context: UIGraphicsPDFRendererContext,
        layout: Layout,
        pagina: inout Int,
        indice: Int?,
        total: Int?
    ) -> CGFloat {
        var yAtual = y

        if let indice, let total {
            yAtual = desenhar(
                "Texto \(indice) de \(total)",
                em: CGRect(x: layout.margem, y: yAtual, width: layout.largura, height: 18),
                fonte: .systemFont(ofSize: 9, weight: .semibold),
                cor: UIColor(red: 0.45, green: 0.34, blue: 0.13, alpha: 1)
            )
            yAtual += 10
        }

        yAtual = desenhar(
            item.referenciaExibicao,
            em: CGRect(x: layout.margem, y: yAtual, width: layout.largura, height: 26),
            fonte: .systemFont(ofSize: 16, weight: .semibold),
            cor: corOuroEscuro,
            alinhamento: .center
        )

        let inicioTitulo = yAtual + 4
        yAtual = desenharTextoPaginado(
            item.titulo,
            x: layout.margem,
            y: inicioTitulo,
            largura: layout.largura,
            layout: layout,
            fonte: .boldSystemFont(ofSize: 20),
            cor: .black,
            lineSpacing: 4,
            alinhamento: .center,
            context: context,
            pagina: &pagina,
            tituloRodape: item.referenciaExibicao
        )
        yAtual += 8

        garantirEspaco(y: &yAtual, altura: 78, layout: layout, context: context,
                       pagina: &pagina, tituloRodape: item.referenciaExibicao)

        desenharSeparadorDecorativo(
            centroX: layout.pageRect.midX,
            y: yAtual + 8,
            largura: min(layout.largura * 0.52, 260),
            cor: corOuro.withAlphaComponent(0.82)
        )
        yAtual += 18

        if let paginaOriginal = item.pagina {
            yAtual = desenhar(
                "Página original: \(paginaOriginal)",
                em: CGRect(x: layout.margem, y: yAtual + 6, width: layout.largura, height: 18),
                fonte: .systemFont(ofSize: 9),
                cor: .darkGray
            )
        }

        if let frase = item.fraseExibicao {
            yAtual = desenharBlocoDestaque(
                frase,
                titulo: nil,
                y: yAtual + 14,
                context: context,
                layout: layout,
                pagina: &pagina
            )
        }

        yAtual = desenharTextoPaginado(
            TextoLeituraFormatter.comParagrafosVisiveis(item.texto),
            x: layout.margem,
            y: yAtual + 20,
            largura: layout.largura,
            layout: layout,
            fonte: .systemFont(ofSize: 12.8),
            cor: .black,
            lineSpacing: 7.5,
            alinhamento: .justified,
            context: context,
            pagina: &pagina,
            tituloRodape: item.referenciaExibicao,
            chamadasRodape: item.chamadasRodape
        )

        if let rodape = item.rodape?.trimmingCharacters(in: .whitespacesAndNewlines),
           rodape.isEmpty == false {
            garantirEspaco(y: &yAtual, altura: 94, layout: layout, context: context,
                           pagina: &pagina, tituloRodape: item.referenciaExibicao)
            yAtual += 26
            desenharSeparador(
                x: layout.margem,
                y: yAtual,
                largura: layout.largura,
                cor: UIColor(red: 0.72, green: 0.55, blue: 0.20, alpha: 1)
            )

            yAtual = desenhar(
                "Notas de rodapé",
                em: CGRect(x: layout.margem, y: yAtual + 14, width: layout.largura, height: 22),
                fonte: .boldSystemFont(ofSize: 11),
                cor: UIColor(red: 0.25, green: 0.22, blue: 0.17, alpha: 1)
            )

            let rodapeFormatado = TextoLeituraFormatter.rodapeComNotasEmLinhas(
                rodape,
                chamadasRodape: item.chamadasRodape
            )

            yAtual = desenharTextoPaginado(
                rodapeFormatado,
                x: layout.margem,
                y: yAtual + 8,
                largura: layout.largura,
                layout: layout,
                fonte: .systemFont(ofSize: 10.5),
                cor: .darkGray,
                lineSpacing: 7,
                paragraphSpacing: 0,
                alinhamento: .justified,
                context: context,
                pagina: &pagina,
                tituloRodape: item.referenciaExibicao
            )
        }

        guard incluirComentario else {
            return yAtual
        }

        let comentarioLimpo = comentario.trimmingCharacters(in: .whitespacesAndNewlines)
        guard comentarioLimpo.isEmpty == false else {
            return yAtual
        }

        return desenharComentarioEmNovaPaginaAposLeitura(
            comentarioLimpo,
            item: item,
            context: context,
            layout: layout,
            pagina: &pagina
        )
    }

    static func desenharComentarioEmNovaPaginaAposLeitura(
        _ comentario: String,
        item: BreviarioItem,
        context: UIGraphicsPDFRendererContext,
        layout: Layout,
        pagina: inout Int
    ) -> CGFloat {
        let tituloRodape = "\(item.referenciaExibicao) - Comentário"
        let yComentario = iniciarPaginaPremium(
            context: context,
            layout: layout,
            pagina: &pagina,
            tituloRodape: tituloRodape
        )

        return desenharBlocoComentario(
            comentario,
            chamadasRodape: item.chamadasRodape,
            y: yComentario,
            context: context,
            layout: layout,
            pagina: &pagina,
            tituloRodape: tituloRodape
        )
    }

    static func desenharBlocoDestaque(
        _ texto: String,
        titulo: String?,
        y: CGFloat,
        context: UIGraphicsPDFRendererContext,
        layout: Layout,
        pagina: inout Int
    ) -> CGFloat {
        var yAtual = y
        garantirEspaco(
            y: &yAtual,
            altura: 86,
            layout: layout,
            context: context,
            pagina: &pagina,
            tituloRodape: "Destaque"
        )

        let altura = alturaTexto(texto, largura: layout.largura - 28, fonte: .italicSystemFont(ofSize: 12.5), lineSpacing: 7) + 28
        let rect = CGRect(x: layout.margem, y: yAtual, width: layout.largura, height: max(altura, 62))
        UIColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()

        if let titulo {
            _ = desenhar(
                titulo,
                em: CGRect(x: rect.minX + 14, y: rect.minY + 12, width: rect.width - 28, height: 18),
                fonte: .boldSystemFont(ofSize: 11),
                cor: .darkGray
            )
            yAtual += 22
        }

        yAtual = desenhar(
            texto,
            em: CGRect(x: rect.minX + 14, y: yAtual + 14, width: rect.width - 28, height: rect.height - 22),
            fonte: .italicSystemFont(ofSize: 12.5),
            cor: UIColor(red: 0.25, green: 0.22, blue: 0.17, alpha: 1),
            alinhamento: .justified,
            lineSpacing: 7
        )

        return rect.maxY
    }

    static func desenharBlocoComentario(
        _ texto: String,
        chamadasRodape: Set<String> = [],
        y: CGFloat,
        context: UIGraphicsPDFRendererContext,
        layout: Layout,
        pagina: inout Int,
        tituloRodape: String
    ) -> CGFloat {
        var yAtual = y
        let tituloAltura: CGFloat = 28
        garantirEspaco(
            y: &yAtual,
            altura: 96,
            layout: layout,
            context: context,
            pagina: &pagina,
            tituloRodape: tituloRodape
        )

        yAtual = desenhar(
            "Comentário pessoal",
            em: CGRect(x: layout.margem, y: yAtual + 14, width: layout.largura, height: tituloAltura),
            fonte: .boldSystemFont(ofSize: 13),
            cor: .black
        )

        return desenharTextoPaginado(
            TextoLeituraFormatter.comParagrafosVisiveis(texto),
            x: layout.margem,
            y: yAtual + 6,
            largura: layout.largura,
            layout: layout,
            fonte: .systemFont(ofSize: 12.8),
            cor: .black,
            lineSpacing: 7.5,
            alinhamento: .justified,
            context: context,
            pagina: &pagina,
            tituloRodape: tituloRodape,
            chamadasRodape: chamadasRodape
        )
    }

    static func iniciarPaginaPremium(
        context: UIGraphicsPDFRendererContext,
        layout: Layout,
        pagina: inout Int,
        tituloRodape: String
    ) -> CGFloat {
        pagina += 1
        context.beginPage()

        UIColor.white.setFill()
        UIBezierPath(rect: layout.pageRect).fill()

        desenharMarcaDagua(
            centro: CGPoint(x: layout.pageRect.midX, y: layout.pageRect.midY + 12),
            tamanho: 270
        )
        desenharCabecalho(layout: layout)
        desenharRodape(layout: layout, pagina: pagina, titulo: tituloRodape)
        return layout.margemSuperiorConteudo
    }

    static func desenharCabecalho(layout: Layout) {
        desenharCompassoEsquadro(
            centro: CGPoint(x: layout.pageRect.width - layout.margem - 18, y: 43),
            tamanho: 30,
            corMetal: corOuro,
            corLinha: corOuroEscuro,
            opacidade: 0.85
        )

        _ = desenhar(
            layout.cabecalho,
            em: CGRect(x: layout.margem, y: 30, width: layout.largura - 48, height: 24),
            fonte: .boldSystemFont(ofSize: 12),
            cor: .black
        )

        desenharSeparador(
            x: layout.margem,
            y: 62,
            largura: layout.largura,
            cor: UIColor(red: 0.72, green: 0.55, blue: 0.20, alpha: 1)
        )
    }

    static func desenharRodape(layout: Layout, pagina: Int, titulo: String) {
        let y = layout.pageRect.height - 46
        desenharSeparador(
            x: layout.margem,
            y: y - 10,
            largura: layout.largura,
            cor: UIColor(white: 0.82, alpha: 1)
        )

        _ = desenhar(
            titulo,
            em: CGRect(x: layout.margem, y: y, width: layout.largura * 0.72, height: 18),
            fonte: .systemFont(ofSize: 8.5),
            cor: .darkGray
        )

        _ = desenhar(
            "p. \(pagina)",
            em: CGRect(x: layout.margem + layout.largura * 0.74, y: y, width: layout.largura * 0.26, height: 18),
            fonte: .systemFont(ofSize: 8.5),
            cor: .darkGray,
            alinhamento: .right
        )
    }

    static func desenharMolduraCapa(layout: Layout) {
        UIColor.black.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: layout.pageRect.width, height: 16)).fill()
        UIBezierPath(rect: CGRect(x: 0, y: layout.pageRect.height - 16, width: layout.pageRect.width, height: 16)).fill()

        let externa = layout.pageRect.insetBy(dx: 34, dy: 38)
        let interna = layout.pageRect.insetBy(dx: 44, dy: 48)

        corOuro.setStroke()
        let molduraExterna = UIBezierPath(rect: externa)
        molduraExterna.lineWidth = 2
        molduraExterna.stroke()

        corOuro.withAlphaComponent(0.55).setStroke()
        let molduraInterna = UIBezierPath(rect: interna)
        molduraInterna.lineWidth = 0.8
        molduraInterna.stroke()

        desenharCantoDecorativo(em: CGPoint(x: externa.minX, y: externa.minY), espelhadoX: false, espelhadoY: false)
        desenharCantoDecorativo(em: CGPoint(x: externa.maxX, y: externa.minY), espelhadoX: true, espelhadoY: false)
        desenharCantoDecorativo(em: CGPoint(x: externa.minX, y: externa.maxY), espelhadoX: false, espelhadoY: true)
        desenharCantoDecorativo(em: CGPoint(x: externa.maxX, y: externa.maxY), espelhadoX: true, espelhadoY: true)
    }

    static func desenharCantoDecorativo(
        em ponto: CGPoint,
        espelhadoX: Bool,
        espelhadoY: Bool
    ) {
        guard let contexto = UIGraphicsGetCurrentContext() else {
            return
        }

        contexto.saveGState()
        contexto.translateBy(x: ponto.x, y: ponto.y)
        contexto.scaleBy(x: espelhadoX ? -1 : 1, y: espelhadoY ? -1 : 1)

        corOuro.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 34))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 34, y: 0))
        path.move(to: CGPoint(x: 10, y: 34))
        path.addCurve(
            to: CGPoint(x: 34, y: 10),
            controlPoint1: CGPoint(x: 12, y: 20),
            controlPoint2: CGPoint(x: 20, y: 12)
        )
        path.lineWidth = 1.2
        path.stroke()

        contexto.restoreGState()
    }

    static func desenharSeparadorDecorativo(
        centroX: CGFloat,
        y: CGFloat,
        largura: CGFloat,
        cor: UIColor
    ) {
        cor.setStroke()
        let linha = UIBezierPath()
        linha.move(to: CGPoint(x: centroX - largura / 2, y: y))
        linha.addLine(to: CGPoint(x: centroX + largura / 2, y: y))
        linha.lineWidth = 1.2
        linha.stroke()

        cor.setFill()
        UIBezierPath(ovalIn: CGRect(x: centroX - 4, y: y - 4, width: 8, height: 8)).fill()
        UIBezierPath(ovalIn: CGRect(x: centroX - largura / 2 - 3, y: y - 3, width: 6, height: 6)).fill()
        UIBezierPath(ovalIn: CGRect(x: centroX + largura / 2 - 3, y: y - 3, width: 6, height: 6)).fill()
    }

    static func desenharMarcaDagua(centro: CGPoint, tamanho: CGFloat) {
        desenharCompassoEsquadro(
            centro: centro,
            tamanho: tamanho,
            corMetal: corOuro.withAlphaComponent(0.08),
            corLinha: corOuroEscuro.withAlphaComponent(0.08),
            opacidade: 1
        )
    }

    static func desenharCompassoEsquadro(
        centro: CGPoint,
        tamanho: CGFloat,
        corMetal: UIColor,
        corLinha: UIColor,
        opacidade: CGFloat
    ) {
        guard let contexto = UIGraphicsGetCurrentContext() else {
            return
        }

        contexto.saveGState()
        contexto.setAlpha(opacidade)
        contexto.translateBy(x: centro.x, y: centro.y)

        let escala = tamanho / 128
        contexto.scaleBy(x: escala, y: escala)

        corMetal.setStroke()
        corMetal.setFill()

        let compasso = UIBezierPath()
        compasso.move(to: CGPoint(x: 0, y: -58))
        compasso.addLine(to: CGPoint(x: -48, y: 52))
        compasso.move(to: CGPoint(x: 0, y: -58))
        compasso.addLine(to: CGPoint(x: 48, y: 52))
        compasso.lineWidth = 8
        compasso.lineCapStyle = .round
        compasso.stroke()

        corLinha.setStroke()
        let compassoLinha = UIBezierPath()
        compassoLinha.move(to: CGPoint(x: 0, y: -58))
        compassoLinha.addLine(to: CGPoint(x: -48, y: 52))
        compassoLinha.move(to: CGPoint(x: 0, y: -58))
        compassoLinha.addLine(to: CGPoint(x: 48, y: 52))
        compassoLinha.lineWidth = 2
        compassoLinha.lineCapStyle = .round
        compassoLinha.stroke()

        let topo = UIBezierPath(ovalIn: CGRect(x: -12, y: -70, width: 24, height: 18))
        corMetal.setFill()
        topo.fill()
        corLinha.setStroke()
        topo.lineWidth = 1.2
        topo.stroke()

        corMetal.setStroke()
        let esquadro = UIBezierPath()
        esquadro.move(to: CGPoint(x: -56, y: 24))
        esquadro.addLine(to: CGPoint(x: 0, y: 58))
        esquadro.addLine(to: CGPoint(x: 56, y: 24))
        esquadro.lineWidth = 12
        esquadro.lineJoinStyle = .round
        esquadro.stroke()

        corLinha.setStroke()
        let esquadroLinha = UIBezierPath()
        esquadroLinha.move(to: CGPoint(x: -56, y: 24))
        esquadroLinha.addLine(to: CGPoint(x: 0, y: 58))
        esquadroLinha.addLine(to: CGPoint(x: 56, y: 24))
        esquadroLinha.lineWidth = 2
        esquadroLinha.lineJoinStyle = .round
        esquadroLinha.stroke()

        _ = desenhar(
            "G",
            em: CGRect(x: -22, y: -8, width: 44, height: 42),
            fonte: .boldSystemFont(ofSize: 38),
            cor: corLinha,
            alinhamento: .center
        )

        contexto.restoreGState()
    }

    static func desenharFolhasAcacia(
        centro: CGPoint,
        escala: CGFloat,
        cor: UIColor
    ) {
        guard let contexto = UIGraphicsGetCurrentContext() else {
            return
        }

        contexto.saveGState()
        contexto.translateBy(x: centro.x, y: centro.y)
        contexto.scaleBy(x: escala, y: escala)

        cor.withAlphaComponent(0.66).setStroke()
        let haste = UIBezierPath()
        haste.move(to: CGPoint(x: -94, y: 32))
        haste.addCurve(
            to: CGPoint(x: 94, y: 32),
            controlPoint1: CGPoint(x: -44, y: -30),
            controlPoint2: CGPoint(x: 44, y: -30)
        )
        haste.lineWidth = 1.3
        haste.stroke()

        for indice in stride(from: 5, through: 0, by: -1) {
            for lado in [-1, 1] {
                let x = CGFloat(lado) * CGFloat(12 + indice * 14)
                let y = CGFloat(22 - indice * 7)
                desenharFolhaAcacia(
                    centro: CGPoint(x: x, y: y),
                    largura: 13 + CGFloat(indice % 2),
                    altura: 27 + CGFloat(indice % 3),
                    angulo: CGFloat(lado) * CGFloat(-34 + indice * 5) * .pi / 180,
                    cor: cor,
                    variacao: CGFloat(indice) / 6
                )
            }
        }

        desenharFolhaAcacia(
            centro: CGPoint(x: 0, y: -8),
            largura: 14,
            altura: 30,
            angulo: 0,
            cor: cor,
            variacao: 0.15
        )

        contexto.restoreGState()
    }

    static func desenharFolhaAcacia(
        centro: CGPoint,
        largura: CGFloat,
        altura: CGFloat,
        angulo: CGFloat,
        cor: UIColor,
        variacao: CGFloat
    ) {
        guard let contexto = UIGraphicsGetCurrentContext() else {
            return
        }

        contexto.saveGState()
        contexto.translateBy(x: centro.x, y: centro.y)
        contexto.rotate(by: angulo)

        let folha = caminhoFolhaAcacia(largura: largura, altura: altura)

        contexto.saveGState()
        contexto.translateBy(x: 1.4, y: 1.8)
        UIColor.black.withAlphaComponent(0.11).setFill()
        folha.fill()
        contexto.restoreGState()

        let verdeBase = UIColor(
            red: 0.18 + variacao * 0.03,
            green: 0.43 + variacao * 0.16,
            blue: 0.18 + variacao * 0.04,
            alpha: cor.cgColor.alpha
        )
        let verdeLuz = UIColor(
            red: 0.48,
            green: 0.68 + variacao * 0.10,
            blue: 0.28,
            alpha: cor.cgColor.alpha
        )

        contexto.saveGState()
        folha.addClip()
        let espaco = CGColorSpaceCreateDeviceRGB()
        let cores = [verdeLuz.cgColor, verdeBase.cgColor] as CFArray
        let posicoes: [CGFloat] = [0.0, 1.0]
        if let gradiente = CGGradient(colorsSpace: espaco, colors: cores, locations: posicoes) {
            contexto.drawLinearGradient(
                gradiente,
                start: CGPoint(x: -largura * 0.65, y: -altura * 0.45),
                end: CGPoint(x: largura * 0.55, y: altura * 0.48),
                options: []
            )
        }
        contexto.restoreGState()

        UIColor(red: 0.11, green: 0.28, blue: 0.12, alpha: cor.cgColor.alpha * 0.55).setStroke()
        folha.lineWidth = 0.45
        folha.stroke()

        UIColor(red: 0.88, green: 0.96, blue: 0.58, alpha: cor.cgColor.alpha * 0.58).setStroke()
        let nervura = UIBezierPath()
        nervura.move(to: CGPoint(x: 0, y: -altura / 2 + 3))
        nervura.addLine(to: CGPoint(x: 0, y: altura / 2 - 3))
        nervura.lineWidth = 0.75
        nervura.stroke()

        UIColor(red: 0.94, green: 1.0, blue: 0.68, alpha: cor.cgColor.alpha * 0.32).setStroke()
        for lado in [-1, 1] {
            for indice in 0..<3 {
                let y = -altura * 0.22 + CGFloat(indice) * altura * 0.17
                let nervuraLateral = UIBezierPath()
                nervuraLateral.move(to: CGPoint(x: 0, y: y))
                nervuraLateral.addCurve(
                    to: CGPoint(x: CGFloat(lado) * largura * 0.42, y: y + altura * 0.12),
                    controlPoint1: CGPoint(x: CGFloat(lado) * largura * 0.14, y: y + altura * 0.02),
                    controlPoint2: CGPoint(x: CGFloat(lado) * largura * 0.30, y: y + altura * 0.08)
                )
                nervuraLateral.lineWidth = 0.32
                nervuraLateral.stroke()
            }
        }

        contexto.restoreGState()
    }

    static func caminhoFolhaAcacia(largura: CGFloat, altura: CGFloat) -> UIBezierPath {
        let folha = UIBezierPath()
        folha.move(to: CGPoint(x: 0, y: -altura / 2))
        folha.addCurve(
            to: CGPoint(x: 0, y: altura / 2),
            controlPoint1: CGPoint(x: largura * 0.78, y: -altura * 0.30),
            controlPoint2: CGPoint(x: largura * 0.72, y: altura * 0.28)
        )
        folha.addCurve(
            to: CGPoint(x: 0, y: -altura / 2),
            controlPoint1: CGPoint(x: -largura * 0.72, y: altura * 0.28),
            controlPoint2: CGPoint(x: -largura * 0.78, y: -altura * 0.30)
        )
        return folha
    }

    static func desenhar(
        _ texto: String,
        em rect: CGRect,
        fonte: UIFont,
        cor: UIColor,
        alinhamento: NSTextAlignment = .natural,
        lineSpacing: CGFloat = 0
    ) -> CGFloat {

        let estilo = NSMutableParagraphStyle()
        estilo.alignment = alinhamento
        estilo.lineSpacing = lineSpacing

        let atributos: [NSAttributedString.Key: Any] = [
            .font: fonte,
            .foregroundColor: cor,
            .paragraphStyle: estilo
        ]

        texto.draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: atributos,
            context: nil
        )
        return rect.maxY
    }
}
