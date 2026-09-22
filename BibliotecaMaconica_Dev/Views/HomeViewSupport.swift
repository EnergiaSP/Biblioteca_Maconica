import SwiftUI
import UIKit

enum FormatoExportacaoMultipla: String, CaseIterable, Identifiable {
    case pdf
    case texto

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .pdf:
            "PDF"
        case .texto:
            "Texto"
        }
    }

    var icone: String {
        switch self {
        case .pdf:
            "doc.richtext"
        case .texto:
            "doc.plaintext"
        }
    }
}

enum TelaMais: String {
    case menu
    case colecoes
    case buscaBiblioteca
    case dossieEstudo
    case indicesBiblioteca
    case acervoOffline
    case fontesOficiais
    case solicitarObra
    case ia
    case estatisticas
    case configuracoes
}

enum ConfiguracaoSecao: String, CaseIterable, Hashable {
    case aparencia
    case leitura
    case pdf
    case ia
    case voz
    case notificacoes
    case dados

    var titulo: String {
        switch self {
        case .aparencia:
            "Aparência"
        case .leitura:
            "Leitura"
        case .pdf:
            "PDF Premium"
        case .ia:
            "Inteligência artificial"
        case .voz:
            "Ouvir texto"
        case .notificacoes:
            "Notificação diária"
        case .dados:
            "Dados"
        }
    }

    var icone: String {
        switch self {
        case .aparencia:
            "paintpalette"
        case .leitura:
            "textformat.size"
        case .pdf:
            "doc.richtext"
        case .ia:
            "sparkles"
        case .voz:
            "speaker.wave.2"
        case .notificacoes:
            "bell.badge"
        case .dados:
            "externaldrive"
        }
    }
}

enum TextoLeituraFormatter {
    static func rodapeComNotasEmLinhas(_ texto: String, chamadasRodape: Set<String>) -> String {
        let normalizado = texto
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizado.isEmpty == false,
              chamadasRodape.isEmpty == false else {
            return normalizado
        }

        let textoNSString = normalizado as NSString
        let padrao = #"(?<![\d/])\d{1,4}(?=\s+[A-ZÁÉÍÓÚÂÊÔÃÕÇ])"#
        guard let regex = try? NSRegularExpression(pattern: padrao) else {
            return normalizado
        }

        var resultado = normalizado
        let matches = regex.matches(
            in: normalizado,
            range: NSRange(location: 0, length: textoNSString.length)
        )
        .filter { match in
            let numero = textoNSString.substring(with: match.range)
            return chamadasRodape.contains(numero)
                && ehInicioVisualDeNota(match.range, em: textoNSString)
        }
        .reversed()

        for match in matches {
            guard match.range.location > 0,
                  let range = Range(match.range, in: resultado) else {
                continue
            }

            let prefixo = resultado[..<range.lowerBound]
            if prefixo.hasSuffix("\n") {
                continue
            }

            resultado.insert(contentsOf: "\n", at: range.lowerBound)
        }

        return resultado
            .components(separatedBy: "\n")
            .map(limparEspacosInternos)
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
    }

    static func comParagrafosVisiveis(_ texto: String, comprimentoMinimo: Int = 520) -> String {
        let normalizado = texto
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizado.isEmpty == false else {
            return ""
        }

        let paragrafosExistentes = normalizado
            .components(separatedBy: "\n\n")
            .map(limparEspacosInternos)
            .filter { $0.isEmpty == false }

        if paragrafosExistentes.count > 1 {
            return paragrafosExistentes.joined(separator: "\n\n")
        }

        let palavras = normalizado
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { $0.isEmpty == false }

        var paragrafos: [String] = []
        var atual = ""

        for palavra in palavras {
            atual = atual.isEmpty ? palavra : "\(atual) \(palavra)"

            if atual.count >= comprimentoMinimo,
               encerraFrase(palavra),
               permiteQuebraAposFrase(atual) {
                paragrafos.append(atual)
                atual = ""
            }
        }

        let restante = atual.trimmingCharacters(in: .whitespacesAndNewlines)
        if restante.isEmpty == false {
            paragrafos.append(restante)
        }

        return paragrafos.isEmpty ? normalizado : paragrafos.joined(separator: "\n\n")
    }

    private static func limparEspacosInternos(_ texto: String) -> String {
        texto
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func encerraFrase(_ palavra: String) -> Bool {
        var palavraNormalizada = palavra
        while let ultimo = palavraNormalizada.last,
              ["\"", "”", "'", "’"].contains(ultimo) {
            palavraNormalizada.removeLast()
        }

        let finais: Set<Character> = [".", "!", "?"]
        guard let ultimo = palavraNormalizada.last, finais.contains(ultimo) else {
            return false
        }

        let abreviacoes = ["p.", "pp.", "vol.", "ed.", "n.", "no.", "dr.", "sr.", "sra."]
        return abreviacoes.contains(palavraNormalizada.lowercased()) == false
    }

    private static func permiteQuebraAposFrase(_ textoAtual: String) -> Bool {
        let trechoFinal = String(textoAtual.suffix(120))
        return trechoFinal.contains("...") == false
    }

    private static func ehInicioVisualDeNota(_ range: NSRange, em texto: NSString) -> Bool {
        guard range.location > 0 else {
            return true
        }

        var indiceAnterior = range.location - 1
        while indiceAnterior >= 0 {
            guard let anterior = UnicodeScalar(texto.character(at: indiceAnterior)) else {
                return false
            }

            if CharacterSet.whitespacesAndNewlines.contains(anterior) {
                indiceAnterior -= 1
                continue
            }

            if CharacterSet.decimalDigits.contains(anterior) || anterior == "/" {
                return false
            }

            return true
        }

        return true
    }
}

struct AccessibleActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    let tema: TemaLeitura
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .foregroundStyle(enabled && prominent ? tema.textoSobreDestaque : tema.textoSecundario)
            .background(enabled && prominent ? tema.fundoDestaque : tema.textoSecundario.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed && enabled ? 0.85 : 1)
    }
}

enum TemaLeitura: String, CaseIterable, Identifiable {
    case escuro
    case claro
    case sepia

    static var allCases: [TemaLeitura] {
        [.escuro, .claro, .sepia]
    }

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .escuro:
            "Escuro"
        case .claro:
            "Claro"
        case .sepia:
            "Sépia"
        }
    }

    var icone: String {
        switch self {
        case .escuro:
            "moon"
        case .claro:
            "sun.max"
        case .sepia:
            "book.closed"
        }
    }

    var background: Color {
        backgroundColors[0]
    }

    var backgroundColors: [Color] {
        switch self {
        case .escuro:
            [
                Color(red: 0.02, green: 0.02, blue: 0.03),
                Color(red: 0.04, green: 0.13, blue: 0.20)
            ]
        case .claro:
            [
                Color(red: 0.98, green: 0.98, blue: 0.96),
                Color(red: 0.90, green: 0.93, blue: 0.94)
            ]
        case .sepia:
            [
                Color(red: 0.96, green: 0.91, blue: 0.80),
                Color(red: 0.84, green: 0.74, blue: 0.56)
            ]
        }
    }

    var textoPrincipal: Color {
        switch self {
        case .escuro:
            .white
        case .claro:
            Color(red: 0.08, green: 0.08, blue: 0.08)
        case .sepia:
            .black
        }
    }

    var textoSecundario: Color {
        switch self {
        case .escuro:
            Color(red: 0.84, green: 0.82, blue: 0.78)
        case .claro:
            Color(red: 0.25, green: 0.25, blue: 0.25)
        case .sepia:
            Color(red: 0.19, green: 0.16, blue: 0.12)
        }
    }

    var destaque: Color {
        switch self {
        case .escuro:
            .yellow
        case .claro:
            Color(red: 0.55, green: 0.38, blue: 0.04)
        case .sepia:
            .black
        }
    }

    var corSelecaoTema: Color {
        switch self {
        case .escuro:
            .white
        case .claro, .sepia:
            .black
        }
    }

    var textoSobreDestaque: Color {
        .black
    }

    var fundoDestaque: Color {
        switch self {
        case .escuro: destaque
        case .claro: Color(red: 230.0 / 255, green: 204.0 / 255, blue: 148.0 / 255)
        case .sepia: Color(red: 209.0 / 255, green: 179.0 / 255, blue: 122.0 / 255)
        }
    }

    var sucesso: Color {
        switch self {
        case .escuro:
            Color(red: 33.0 / 255, green: 163.0 / 255, blue: 101.0 / 255)
        case .claro:
            Color(red: 23.0 / 255, green: 108.0 / 255, blue: 53.0 / 255)
        case .sepia:
            Color(red: 15.0 / 255, green: 77.0 / 255, blue: 39.0 / 255)
        }
    }

    var painel: Color {
        switch self {
        case .escuro:
            .black.opacity(0.28)
        case .claro:
            .white.opacity(0.78)
        case .sepia:
            Color(red: 0.74, green: 0.60, blue: 0.38).opacity(0.28)
        }
    }

    var textoUIColor: UIColor {
        UIColor(textoPrincipal)
    }

    var textoSecundarioUIColor: UIColor {
        UIColor(textoSecundario)
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .claro, .sepia:
            .light
        case .escuro:
            .dark
        }
    }
}
