import SwiftUI

/// Kind and duration of the app's short messages, decided in one place: success is not shown as an
/// error, progress stays until replaced, and longer or error messages stay longer on screen.
enum AvisoApp {
    enum Tipo: Equatable {
        case progresso, erro, alerta, sucesso

        var icone: String {
            switch self {
            case .progresso: "clock"
            case .erro: "xmark.octagon.fill"
            case .alerta: "exclamationmark.triangle"
            case .sucesso: "checkmark.circle.fill"
            }
        }

        /// Backgrounds with white text at 4.5:1 or more.
        var fundo: Color {
            switch self {
            case .progresso: Color(red: 0.20, green: 0.23, blue: 0.30)
            case .erro: Color(red: 0.70, green: 0.11, blue: 0.11)
            case .alerta: Color(red: 0.60, green: 0.30, blue: 0.02)
            case .sucesso: Color(red: 0.08, green: 0.42, blue: 0.24)
            }
        }
    }

    private static let progresso = ["gerando", "consultando", "montando", "baixando", "preparando", "organizando", "atualizando"]
    private static let erro = ["não foi possível", "nao foi possivel", "falha", "falhou", "erro", "inválid", "invalid",
                               "indisponível", "indisponivel", "interrompid"]
    private static let alerta = ["não ", "nao ", "nenhum", "nenhuma", "selecione", "informe", "desativad", "foi excluído",
                                 "sem ocorrências", "refine"]

    static func tipo(_ mensagem: String) -> Tipo {
        let texto = mensagem.lowercased()
        if progresso.contains(where: { texto.hasPrefix($0) }) || texto.hasSuffix("...") || texto.hasSuffix("…") {
            return .progresso
        }
        if erro.contains(where: { texto.contains($0) }) { return .erro }
        if alerta.contains(where: { texto.contains($0) }) { return .alerta }
        return .sucesso
    }

    /// Seconds on screen; nil keeps a progress message until the next one replaces it.
    static func duracao(_ mensagem: String) -> Double? {
        let palavras = Double(mensagem.split(separator: " ").count)
        switch tipo(mensagem) {
        case .progresso: return nil
        case .erro: return max(8, min(12, palavras * 0.5))
        case .alerta: return max(6, min(10, palavras * 0.4))
        case .sucesso: return max(4, min(8, palavras * 0.35))
        }
    }
}
