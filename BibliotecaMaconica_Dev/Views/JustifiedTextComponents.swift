import SwiftUI
import UIKit

struct JustifiedTextView: View {
    let texto: String
    let font: UIFont
    let color: UIColor
    let lineSpacing: CGFloat
    var chamadasRodape: Set<String> = []
    var destaques: [String] = []
    var corDestaque: UIColor = UIColor.systemYellow.withAlphaComponent(0.28)
    var aoSelecionarTexto: ((String) -> Void)?
    var aoDestacarTexto: ((String) -> Void)?
    @State private var altura: CGFloat = 1

    var body: some View {
        JustifiedTextUIView(
            texto: texto,
            font: font,
            color: color,
            lineSpacing: lineSpacing,
            chamadasRodape: chamadasRodape,
            destaques: destaques,
            corDestaque: corDestaque,
            aoSelecionarTexto: aoSelecionarTexto,
            aoDestacarTexto: aoDestacarTexto,
            altura: $altura
        )
        .frame(maxWidth: .infinity, minHeight: max(altura, font.lineHeight + lineSpacing + 12))
        .clipped()
        .frame(height: max(altura, font.lineHeight + lineSpacing + 12))
    }
}

struct JustifiedTextUIView: UIViewRepresentable {
    let texto: String
    let font: UIFont
    let color: UIColor
    let lineSpacing: CGFloat
    let chamadasRodape: Set<String>
    let destaques: [String]
    let corDestaque: UIColor
    let aoSelecionarTexto: ((String) -> Void)?
    var aoDestacarTexto: ((String) -> Void)? = nil
    @Binding var altura: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.heightTracksTextView = false
        textView.alwaysBounceHorizontal = false
        textView.showsHorizontalScrollIndicator = false
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        coordinator.ativo = false
        coordinator.aoSelecionarTexto = nil
        coordinator.aoDestacarTexto = nil
        uiView.delegate = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(aoSelecionarTexto: aoSelecionarTexto)
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.aoSelecionarTexto = aoSelecionarTexto
        context.coordinator.aoDestacarTexto = aoDestacarTexto
        let assinatura = assinaturaConteudo
        guard context.coordinator.assinaturaConteudo != assinatura else {
            recalcularAltura(textView, assinatura: assinatura, coordinator: context.coordinator)
            return
        }
        context.coordinator.assinaturaConteudo = assinatura

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .justified
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.paragraphSpacing = 10

        let textoAtribuido = NSMutableAttributedString(
            string: texto,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        )

        aplicarChamadasRodape(em: textoAtribuido)
        aplicarDestaques(em: textoAtribuido)
        textView.attributedText = textoAtribuido
        recalcularAltura(textView, assinatura: assinatura, coordinator: context.coordinator)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView textView: UITextView,
        context: Context
    ) -> CGSize? {
        let largura = max(proposal.width ?? UIScreen.main.bounds.width - 32, 1)
        textView.bounds.size.width = largura
        textView.textContainer.size = CGSize(width: largura, height: .greatestFiniteMagnitude)

        let tamanho = textView.sizeThatFits(
            CGSize(width: largura, height: .greatestFiniteMagnitude)
        )
        let novaAltura = ceil(tamanho.height)

        DispatchQueue.main.async {
            if abs(altura - novaAltura) > 1 {
                altura = novaAltura
            }
        }

        return CGSize(width: largura, height: max(novaAltura, font.lineHeight + lineSpacing + 12))
    }

    private var assinaturaConteudo: String {
        [
            texto,
            "\(font.fontName)-\(font.pointSize)",
            "\(color.hash)",
            "\(lineSpacing)",
            chamadasRodape.sorted().joined(separator: ","),
            destaques.joined(separator: "\u{1F}")
        ].joined(separator: "\u{1E}")
    }

    private func aplicarChamadasRodape(em textoAtribuido: NSMutableAttributedString) {
        guard chamadasRodape.isEmpty == false else {
            return
        }

        let textoCompleto = texto as NSString
        let padrao = #"(?<![\d/])\d{1,4}(?![\d/])"#
        guard let regex = try? NSRegularExpression(pattern: padrao) else {
            return
        }

        let rangeTotal = NSRange(location: 0, length: textoCompleto.length)
        for resultado in regex.matches(in: texto, range: rangeTotal) {
            let numero = textoCompleto.substring(with: resultado.range)
            guard chamadasRodape.contains(numero),
                  ehChamadaRodapeVisual(resultado.range, em: textoCompleto) else {
                continue
            }

            textoAtribuido.addAttributes(
                [
                    .font: UIFont.systemFont(ofSize: max(font.pointSize * 0.68, 8)),
                    .baselineOffset: font.pointSize * 0.36
                ],
                range: resultado.range
            )
        }
    }

    private func ehChamadaRodapeVisual(_ range: NSRange, em texto: NSString) -> Bool {
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

    private func aplicarDestaques(em textoAtribuido: NSMutableAttributedString) {
        let textoCompleto = texto as NSString
        let textoInteiro = NSRange(location: 0, length: textoCompleto.length)

        for destaque in destaques {
            let trecho = destaque.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trecho.isEmpty == false else {
                continue
            }

            var areaBusca = textoInteiro
            while areaBusca.location < textoCompleto.length {
                let range = textoCompleto.range(
                    of: trecho,
                    options: [.literal],
                    range: areaBusca
                )

                guard range.location != NSNotFound else {
                    break
                }

                textoAtribuido.addAttribute(.backgroundColor, value: corDestaque, range: range)
                let proximaLocalizacao = range.location + max(range.length, 1)
                areaBusca = NSRange(
                    location: proximaLocalizacao,
                    length: max(textoCompleto.length - proximaLocalizacao, 0)
                )
            }
        }
    }

    private func recalcularAltura(
        _ textView: UITextView,
        assinatura: String,
        coordinator: Coordinator
    ) {
        DispatchQueue.main.async {
            guard coordinator.ativo else {
                return
            }

            let largura = max(textView.bounds.width, 1)
            textView.textContainer.size = CGSize(
                width: largura,
                height: .greatestFiniteMagnitude
            )
            guard coordinator.ultimaAssinaturaMedida != assinatura
                    || abs(coordinator.ultimaLarguraMedida - largura) > 1 else {
                return
            }

            let tamanho = textView.sizeThatFits(
                CGSize(
                    width: largura,
                    height: .greatestFiniteMagnitude
                )
            )
            let novaAltura = ceil(tamanho.height)
            coordinator.ultimaAssinaturaMedida = assinatura
            coordinator.ultimaLarguraMedida = largura

            if abs(altura - novaAltura) > 1 {
                altura = novaAltura
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var aoSelecionarTexto: ((String) -> Void)?
        var aoDestacarTexto: ((String) -> Void)?
        var ativo = true
        var assinaturaConteudo = ""
        var ultimaAssinaturaMedida = ""
        var ultimaLarguraMedida: CGFloat = 0
        private var ultimoTrechoSelecionado = ""

        init(aoSelecionarTexto: ((String) -> Void)?) {
            self.aoSelecionarTexto = aoSelecionarTexto
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange,
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard ativo, aoDestacarTexto != nil,
                  let selection = Range(range, in: textView.text), !selection.isEmpty else { return nil }
            let excerpt = String(textView.text[selection])
            let highlight = UIAction(title: "Destacar", image: UIImage(systemName: "highlighter")) { [weak self] _ in
                self?.destacar(excerpt)
            }
            return UIMenu(children: [highlight] + suggestedActions)
        }

        func destacar(_ excerpt: String) {
            guard ativo, !excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            aoDestacarTexto?(excerpt)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard textView.selectedRange.length > 0,
                  let range = Range(textView.selectedRange, in: textView.text) else {
                return
            }

            let trecho = String(textView.text[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard trecho.isEmpty == false else {
                return
            }

            guard trecho != ultimoTrechoSelecionado else {
                return
            }
            ultimoTrechoSelecionado = trecho

            DispatchQueue.main.async {
                guard self.ativo else {
                    return
                }
                self.aoSelecionarTexto?(trecho)
            }
        }
    }
}

struct JustifiedEditableTextView: UIViewRepresentable {
    @Binding var texto: String
    let font: UIFont
    let color: UIColor
    let lineSpacing: CGFloat
    let backgroundColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.delegate = context.coordinator
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.typingAttributes = atributos
        return textView
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        uiView.delegate = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(texto: $texto)
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.texto = $texto
        textView.backgroundColor = backgroundColor
        textView.tintColor = color
        textView.typingAttributes = atributos

        let precisaAtualizarTexto = textView.text != texto
        let precisaAtualizarFormato = context.coordinator.assinaturaFormato != assinaturaFormato

        guard precisaAtualizarTexto || precisaAtualizarFormato else {
            return
        }

        let selecao = textView.selectedRange
        textView.attributedText = NSAttributedString(string: texto, attributes: atributos)
        textView.selectedRange = selecaoAjustada(selecao, tamanhoTexto: (texto as NSString).length)
        context.coordinator.assinaturaFormato = assinaturaFormato
    }

    private var assinaturaFormato: String {
        [
            "\(font.fontName)-\(font.pointSize)",
            "\(color.hash)",
            "\(lineSpacing)",
            "\(backgroundColor.hash)"
        ].joined(separator: "\u{1E}")
    }

    private var atributos: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .justified
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.paragraphSpacing = 10

        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func selecaoAjustada(_ selecao: NSRange, tamanhoTexto: Int) -> NSRange {
        let localizacao = min(selecao.location, tamanhoTexto)
        let tamanhoDisponivel = max(tamanhoTexto - localizacao, 0)
        return NSRange(location: localizacao, length: min(selecao.length, tamanhoDisponivel))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var texto: Binding<String>
        var assinaturaFormato = ""

        init(texto: Binding<String>) {
            self.texto = texto
        }

        func textViewDidChange(_ textView: UITextView) {
            texto.wrappedValue = textView.text
        }
    }
}
