import SwiftUI

/// Audio of a whole collection or study path, one reading after another (audio_sequencia_v1.json).
/// Same labels and behavior as Android `AudioSequence`.
enum AudioSequencia {
    struct Configuracao: Decodable {
        let schemaVersion: Int
        let limiteLeituras: Int
        let rotulos: [String: String]

        static let compartilhada: Configuracao? = {
            guard let url = Bundle.main.url(forResource: "audio_sequencia_v1", withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let configuracao = try? JSONDecoder().decode(Configuracao.self, from: dados),
                  configuracao.schemaVersion == 1 else { return nil }
            return configuracao
        }()

        func rotulo(_ chave: String, _ valores: [String: String] = [:]) -> String {
            valores.reduce(rotulos[chave] ?? chave) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
        }
    }
}

/// Small speaker button placed on a collection or study path card.
struct BotaoOuvirSequencia: View {
    let tema: TemaLeitura
    var titulo = ""
    let ouvir: () -> Void

    var body: some View {
        if let configuracao = AudioSequencia.Configuracao.compartilhada {
            Button(action: ouvir) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tema.destaque)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(titulo.isEmpty ? configuracao.rotulo("ouvir") : "\(configuracao.rotulo("ouvir")): \(titulo)")
            .accessibilityIdentifier("audio.sequence.play")
        }
    }
}

/// Progress and controls of the sequence being read.
struct BarraSequenciaAudio: View {
    @ObservedObject var leitorVoz: LeituraVozService
    let tema: TemaLeitura

    var body: some View {
        if let sequencia = leitorVoz.sequencia, let configuracao = AudioSequencia.Configuracao.compartilhada {
            VStack(alignment: .leading, spacing: 10) {
                Label(configuracao.rotulo("ouvindo", ["titulo": sequencia.titulo, "n": "\(sequencia.posicao + 1)",
                                                      "total": "\(sequencia.itens.count)"]), systemImage: "speaker.wave.2")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(tema.textoPrincipal)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("audio.sequence.status")
                Text(sequencia.itens[sequencia.posicao].referenciaExibicao)
                    .font(.caption)
                    .foregroundStyle(tema.textoSecundario)
                HStack(spacing: 10) {
                    Button(configuracao.rotulo(leitorVoz.estaPausado ? "continuar" : "pausar")) { leitorVoz.alternarPausa() }
                        .accessibilityIdentifier("audio.sequence.pause")
                    Button(configuracao.rotulo("proxima")) { leitorVoz.proximaDaSequencia() }
                        .accessibilityIdentifier("audio.sequence.next")
                    Button(configuracao.rotulo("parar")) { leitorVoz.parar() }
                        .accessibilityIdentifier("audio.sequence.stop")
                }
                .buttonStyle(.bordered)
                .tint(tema.destaque)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tema.painel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
