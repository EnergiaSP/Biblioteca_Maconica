import UIKit

extension PDFService {
static func desenharTextoPaginado(
        _ texto: String,
        x: CGFloat,
        y: CGFloat,
        largura: CGFloat,
        layout: Layout,
        fonte: UIFont,
        cor: UIColor,
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat = 0,
        alinhamento: NSTextAlignment = .natural,
        context: UIGraphicsPDFRendererContext,
        pagina: inout Int,
        tituloRodape: String,
        chamadasRodape: Set<String> = []
    ) -> CGFloat {

        let textoLimpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard textoLimpo.isEmpty == false else {
            return y
        }

        let estilo = NSMutableParagraphStyle()
        estilo.lineSpacing = lineSpacing
        estilo.paragraphSpacing = paragraphSpacing
        estilo.alignment = alinhamento

        let atributos: [NSAttributedString.Key: Any] = [
            .font: fonte,
            .foregroundColor: cor,
            .paragraphStyle: estilo
        ]

        let textoAtribuido = NSMutableAttributedString(
            string: textoLimpo,
            attributes: atributos
        )
        aplicarChamadasRodape(
            chamadasRodape,
            em: textoAtribuido,
            fonteBase: fonte
        )

        let textStorage = NSTextStorage(attributedString: textoAtribuido)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        var yAtual = y
        var glyphIndex = 0
        var tentativasSemAvanco = 0

        while glyphIndex < layoutManager.numberOfGlyphs {
            var alturaDisponivel = layout.limiteInferior - yAtual
            if alturaDisponivel < fonte.lineHeight * 2 {
                yAtual = iniciarPaginaPremium(
                    context: context,
                    layout: layout,
                    pagina: &pagina,
                    tituloRodape: tituloRodape
                )
                alturaDisponivel = layout.limiteInferior - yAtual
            }

            let textContainer = NSTextContainer(
                size: CGSize(width: largura, height: alturaDisponivel)
            )
            textContainer.lineFragmentPadding = 0
            textContainer.maximumNumberOfLines = 0
            layoutManager.addTextContainer(textContainer)

            let glyphRange = layoutManager.glyphRange(for: textContainer)
            guard glyphRange.length > 0 else {
                tentativasSemAvanco += 1
                guard tentativasSemAvanco < 2 else {
                    break
                }

                yAtual = iniciarPaginaPremium(
                    context: context,
                    layout: layout,
                    pagina: &pagina,
                    tituloRodape: tituloRodape
                )
                continue
            }

            tentativasSemAvanco = 0
            layoutManager.drawGlyphs(
                forGlyphRange: glyphRange,
                at: CGPoint(x: x, y: yAtual)
            )

            let usedRect = layoutManager.usedRect(for: textContainer)
            yAtual += ceil(usedRect.height)
            glyphIndex = NSMaxRange(glyphRange)

            if glyphIndex < layoutManager.numberOfGlyphs {
                yAtual = iniciarPaginaPremium(
                    context: context,
                    layout: layout,
                    pagina: &pagina,
                    tituloRodape: tituloRodape
                )
            }
        }

        return yAtual
    }

    static func aplicarChamadasRodape(
        _ chamadasRodape: Set<String>,
        em textoAtribuido: NSMutableAttributedString,
        fonteBase: UIFont
    ) {
        guard chamadasRodape.isEmpty == false else {
            return
        }

        let texto = textoAtribuido.string as NSString
        let padrao = #"(?<![\d/])\d{1,4}(?![\d/])"#
        guard let regex = try? NSRegularExpression(pattern: padrao) else {
            return
        }

        let rangeTotal = NSRange(location: 0, length: texto.length)
        for resultado in regex.matches(in: textoAtribuido.string, range: rangeTotal) {
            let numero = texto.substring(with: resultado.range)
            guard chamadasRodape.contains(numero),
                  ehChamadaRodapeVisual(resultado.range, em: texto) else {
                continue
            }

            textoAtribuido.addAttributes(
                [
                    .font: UIFont.systemFont(ofSize: max(fonteBase.pointSize * 0.68, 7)),
                    .baselineOffset: fonteBase.pointSize * 0.36
                ],
                range: resultado.range
            )
        }
    }

    static func ehChamadaRodapeVisual(_ range: NSRange, em texto: NSString) -> Bool {
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

    static func garantirEspaco(
        y: inout CGFloat,
        altura: CGFloat,
        layout: Layout,
        context: UIGraphicsPDFRendererContext,
        pagina: inout Int,
        tituloRodape: String
    ) {
        guard y + altura > layout.limiteInferior else {
            return
        }

        y = iniciarPaginaPremium(
            context: context,
            layout: layout,
            pagina: &pagina,
            tituloRodape: tituloRodape
        )
    }

    static func desenharSeparador(
        x: CGFloat,
        y: CGFloat,
        largura: CGFloat,
        cor: UIColor
    ) {
        guard let contexto = UIGraphicsGetCurrentContext() else {
            return
        }

        contexto.saveGState()
        contexto.setStrokeColor(cor.cgColor)
        contexto.setLineWidth(1)
        contexto.move(to: CGPoint(x: x, y: y))
        contexto.addLine(to: CGPoint(x: x + largura, y: y))
        contexto.strokePath()
        contexto.restoreGState()
    }

    static func alturaTexto(
        _ texto: String,
        largura: CGFloat,
        fonte: UIFont,
        lineSpacing: CGFloat
    ) -> CGFloat {
        let estilo = NSMutableParagraphStyle()
        estilo.lineSpacing = lineSpacing
        estilo.alignment = .justified

        let atributos: [NSAttributedString.Key: Any] = [
            .font: fonte,
            .paragraphStyle: estilo
        ]

        return ceil(
            (texto as NSString).boundingRect(
                with: CGSize(width: largura, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: atributos,
                context: nil
            ).height
        )
    }

    static func intervaloDescricao(_ itens: [BreviarioItem]) -> String {
        guard let primeiro = itens.first?.referenciaExibicao, let ultimo = itens.last?.referenciaExibicao else {
            return "Nenhum dia selecionado"
        }

        guard primeiro != ultimo else {
            return primeiro
        }

        return "\(primeiro) a \(ultimo)"
    }

    static func desenharCapaDossie(
        dossie: BibliotecaDossieEstudo,
        nomeUsuario: String,
        context: UIGraphicsPDFRendererContext,
        layout: Layout
    ) {
        context.beginPage()
        corPapel.setFill()
        UIBezierPath(rect: layout.pageRect).fill()
        desenharMolduraCapa(layout: layout)
        desenharMarcaDagua(
            centro: CGPoint(x: layout.pageRect.midX, y: layout.pageRect.midY - 20),
            tamanho: 285
        )
        desenharFolhasAcacia(
            centro: CGPoint(x: layout.pageRect.midX, y: layout.pageRect.midY + 215),
            escala: 1.05,
            cor: corVerdeAcacia
        )

        _ = desenhar(
            "Biblioteca Maçônica",
            em: CGRect(x: layout.margem, y: 118, width: layout.largura, height: 34),
            fonte: .systemFont(ofSize: 17, weight: .semibold),
            cor: corOuroEscuro,
            alinhamento: .center
        )

        _ = desenhar(
            "Dossiê de Estudo",
            em: CGRect(x: layout.margem, y: 178, width: layout.largura, height: 48),
            fonte: .boldSystemFont(ofSize: 28),
            cor: .black,
            alinhamento: .center
        )

        _ = desenhar(
            dossie.termo,
            em: CGRect(x: layout.margem, y: 232, width: layout.largura, height: 78),
            fonte: .systemFont(ofSize: 24, weight: .medium),
            cor: corOuroEscuro,
            alinhamento: .center,
            lineSpacing: 4
        )

        let subtitulo = [
            dossie.resumoEscopo,
            "\(dossie.resultados.count) referência(s) encontrada(s)"
        ].joined(separator: " • ")

        _ = desenhar(
            subtitulo,
            em: CGRect(x: layout.margem, y: 340, width: layout.largura, height: 52),
            fonte: .systemFont(ofSize: 13),
            cor: .darkGray,
            alinhamento: .center,
            lineSpacing: 3
        )

        if nomeUsuario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            _ = desenhar(
                nomeUsuario,
                em: CGRect(x: layout.margem, y: 642, width: layout.largura, height: 28),
                fonte: .systemFont(ofSize: 13, weight: .medium),
                cor: .darkGray,
                alinhamento: .center
            )
        }

        _ = desenhar(
            dataHoraAtualFormatada(),
            em: CGRect(x: layout.margem, y: 690, width: layout.largura, height: 24),
            fonte: .systemFont(ofSize: 11),
            cor: .darkGray,
            alinhamento: .center
        )
    }

    static func textoDossieEstudo(_ dossie: BibliotecaDossieEstudo, analise: String = "") -> String {
        var partes: [String] = [
            "Tema\n\(dossie.termo)",
            "Escopo\n\(dossie.resumoEscopo)"
        ]

        if dossie.obrasEnvolvidas.isEmpty == false {
            partes.append(
                "Obras envolvidas\n" + dossie.obrasEnvolvidas
                    .map { obra in
                        let autor = obra.autor.map { " - \($0)" } ?? ""
                        return "• \(obra.titulo)\(autor)"
                    }
                    .joined(separator: "\n")
            )
        }

        if dossie.termosRelacionados.isEmpty == false {
            partes.append("Termos relacionados\n" + dossie.termosRelacionados.joined(separator: ", "))
        }

        partes.append(
            "Roteiro de estudo\n" + dossie.roteiro
                .enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
        )

        partes.append(
            "Perguntas de fixação\n" + dossie.perguntasFixacao
                .map { "• \($0)" }
                .joined(separator: "\n")
        )

        partes.append(
            "Mapa conceitual\n" + dossie.mapaConceitual
                .map { "• \($0)" }
                .joined(separator: "\n")
        )

        partes.append(
            "Cruzamentos de estudo\n" + dossie.cruzamentos
                .map { "• \($0)" }
                .joined(separator: "\n")
        )

        partes.append(
            "Revisão espaçada\n" + dossie.revisaoEspacada
                .map { "• \($0)" }
                .joined(separator: "\n")
        )

        partes.append(
            "Limites da base\n" + dossie.limitesDaBase
                .map { "• \($0)" }
                .joined(separator: "\n")
        )

        let referencias = dossie.resultados.enumerated().map { index, resultado in
            [
                "[F\(index + 1)] \(resultado.obra.titulo) - \(resultado.item.referenciaExibicao)",
                resultado.item.titulo,
                resultado.item.frase,
                resultado.item.texto,
                resultado.item.rodape.flatMap { $0.isEmpty ? nil : "Notas de rodapé\n\($0)" } ?? ""
            ]
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .joined(separator: "\n")
        }

        if referencias.isEmpty == false {
            partes.append("Referências encontradas\n" + referencias.joined(separator: "\n\n"))
        } else {
            partes.append("Referências encontradas\nNenhuma ocorrência encontrada. Refine o tema ou importe novas obras.")
        }

        if !analise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            partes.append("Análise por IA\n" + analise)
        }

        partes.append("Nota de confiabilidade\nEste dossiê foi organizado somente com base nas obras disponíveis no app. Conteúdos externos devem ser aceitos apenas quando forem comprovadamente oficiais e regulares.")

        return partes.joined(separator: "\n\n")
    }

    static func nomeArquivoData(_ data: String) -> String {
        data
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }

    static func dataHoraAtualFormatada() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: Date())
    }
}
