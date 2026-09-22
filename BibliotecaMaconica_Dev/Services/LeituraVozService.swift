import AVFoundation
import Foundation

enum VozLeituraGenero: String, CaseIterable, Identifiable {
    case feminina
    case masculina

    var id: String {
        rawValue
    }

    var titulo: String {
        switch self {
        case .feminina:
            "Feminina"
        case .masculina:
            "Masculina"
        }
    }

    var icone: String {
        switch self {
        case .feminina:
            "person.fill"
        case .masculina:
            "person"
        }
    }

    var avSpeechGender: AVSpeechSynthesisVoiceGender {
        switch self {
        case .feminina:
            .female
        case .masculina:
            .male
        }
    }
}

final class LeituraVozService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {

    @Published private(set) var estaLendo = false
    @Published private(set) var estaPausado = false

    private let sintetizador = AVSpeechSynthesizer()
    private var itemAtualID: Int?

    override init() {
        super.init()
        sintetizador.delegate = self
    }

    func alternarLeitura(
        _ item: BreviarioItem,
        genero: VozLeituraGenero,
        velocidade: Double
    ) {
        if estaLendo, itemAtualID == item.id {
            parar()
            return
        }

        falar(item, genero: genero, velocidade: velocidade)
    }

    func falar(
        _ item: BreviarioItem,
        genero: VozLeituraGenero,
        velocidade: Double
    ) {
        parar()
        itemAtualID = item.id

        let utterance = AVSpeechUtterance(string: textoParaLeitura(item))
        utterance.voice = vozPreferida(genero: genero)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(velocidade)
        utterance.pitchMultiplier = 1.04
        utterance.volume = 1
        utterance.preUtteranceDelay = 0.15
        utterance.postUtteranceDelay = 0.2

        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)

        estaLendo = true
        estaPausado = false
        sintetizador.speak(utterance)
    }

    func alternarPausa() {
        guard estaLendo else {
            return
        }

        if estaPausado {
            sintetizador.continueSpeaking()
            estaPausado = false
        } else {
            sintetizador.pauseSpeaking(at: .word)
            estaPausado = true
        }
    }

    func parar() {
        guard sintetizador.isSpeaking || estaLendo else {
            return
        }

        sintetizador.stopSpeaking(at: .immediate)
        estaLendo = false
        estaPausado = false
        itemAtualID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finalizar()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finalizar()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.estaPausado = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.estaPausado = false
        }
    }

    private func finalizar() {
        DispatchQueue.main.async {
            self.estaLendo = false
            self.estaPausado = false
            self.itemAtualID = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func textoParaLeitura(_ item: BreviarioItem) -> String {
        var partes = [
            dataPorExtenso(item.data),
            item.titulo
        ]

        if let frase = item.fraseExibicao {
            partes.append(textoAmigavel(frase))
        }

        partes.append(textoAmigavel(item.texto))

        if let rodape = item.rodape?.trimmingCharacters(in: .whitespacesAndNewlines),
           rodape.isEmpty == false {
            partes.append("Notas da obra. \(textoAmigavel(rodape))")
        }

        return partes.joined(separator: ".\n\n").replacingOccurrences(of: "..", with: ".")
    }

    private func vozPreferida(genero: VozLeituraGenero) -> AVSpeechSynthesisVoice? {
        let vozesBrasil = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "pt-BR" }

        return vozesBrasil
            .filter { $0.gender == genero.avSpeechGender }
            .max { $0.quality.rawValue < $1.quality.rawValue }
        ?? vozesBrasil.max { $0.quality.rawValue < $1.quality.rawValue }
        ?? AVSpeechSynthesisVoice(language: "pt-BR")
    }

    private func dataPorExtenso(_ data: String) -> String {
        let partes = data.split(separator: "/").compactMap { Int($0) }
        guard partes.count == 2, (1...12).contains(partes[1]) else {
            return data
        }

        let meses = [
            "janeiro",
            "fevereiro",
            "março",
            "abril",
            "maio",
            "junho",
            "julho",
            "agosto",
            "setembro",
            "outubro",
            "novembro",
            "dezembro"
        ]

        return "Dia \(partes[0]) de \(meses[partes[1] - 1])"
    }

    private func textoAmigavel(_ texto: String) -> String {
        texto
            .replacingOccurrences(of: #"\s*&\d+\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*[¹²³⁴⁵⁶⁷⁸⁹⁰]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([,.;:!?])"#, with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
