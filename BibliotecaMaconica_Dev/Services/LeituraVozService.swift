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
    /// Readings of a collection or study path read one after another (audio_sequencia_v1.json).
    @Published private(set) var sequencia: Sequencia?

    struct Sequencia: Equatable {
        let titulo: String
        let itens: [BreviarioItem]
        var posicao: Int

        static func == (lhs: Sequencia, rhs: Sequencia) -> Bool {
            lhs.titulo == rhs.titulo && lhs.posicao == rhs.posicao && lhs.itens.map(\.id) == rhs.itens.map(\.id)
        }
    }

    private let sintetizador = AVSpeechSynthesizer()
    private var itemAtualID: Int?
    private var vozSequencia: (genero: VozLeituraGenero, velocidade: Double)?
    private var utteranceAtual: AVSpeechUtterance?

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
        utteranceAtual = utterance
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
        sequencia = nil
        vozSequencia = nil
        // Only this service speaks through the synthesizer, so its own state says whether there is anything to
        // stop; asking the synthesizer (isSpeaking) costs about 170 ms on the main thread on every Back.
        guard estaLendo || estaPausado else {
            return
        }

        sintetizador.stopSpeaking(at: .immediate)
        estaLendo = false
        estaPausado = false
        itemAtualID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let terminada = ObjectIdentifier(utterance)
        DispatchQueue.main.async {
            let atualEhEsta = self.utteranceAtual.map(ObjectIdentifier.init) == terminada
            // In a sequence, the next reading starts when this one ends.
            if atualEhEsta, let atual = self.sequencia, atual.posicao + 1 < atual.itens.count {
                self.lerDaSequencia(atual.posicao + 1)
            } else {
                if atualEhEsta { self.sequencia = nil }
                self.finalizar()
            }
        }
    }

    // MARK: - Sequência

    /// Reads the readings in order, announcing the position of each one.
    func ouvirSequencia(titulo: String, itens: [BreviarioItem], genero: VozLeituraGenero, velocidade: Double, limite: Int) {
        let lista = Array(itens.prefix(limite))
        guard !lista.isEmpty else { return }
        parar()
        vozSequencia = (genero, velocidade)
        sequencia = Sequencia(titulo: titulo, itens: lista, posicao: 0)
        lerDaSequencia(0)
    }

    func proximaDaSequencia() {
        guard let atual = sequencia, atual.posicao + 1 < atual.itens.count else { parar(); return }
        lerDaSequencia(atual.posicao + 1)
    }

    private func lerDaSequencia(_ posicao: Int) {
        guard var atual = sequencia, let voz = vozSequencia, atual.itens.indices.contains(posicao) else { return }
        atual.posicao = posicao
        let item = atual.itens[posicao]
        // The announcement comes from the shared rule, as on Android.
        let anuncio = AudioSequencia.Configuracao.compartilhada?.rotulo("anuncio", ["n": "\(posicao + 1)", "total": "\(atual.itens.count)"]) ?? ""
        let salva = atual
        sintetizador.stopSpeaking(at: .immediate)
        sequencia = salva
        vozSequencia = voz
        itemAtualID = item.id
        let utterance = AVSpeechUtterance(string: anuncio + " " + textoParaLeitura(item))
        utterance.voice = vozPreferida(genero: voz.genero)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(voz.velocidade)
        utterance.pitchMultiplier = 1.04
        utterance.preUtteranceDelay = 0.3
        utterance.postUtteranceDelay = 0.4
        utteranceAtual = utterance
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        estaLendo = true
        estaPausado = false
        sintetizador.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Skipping to the next reading cancels the current one; only the reading still current ends the reading state.
        let cancelada = ObjectIdentifier(utterance)
        DispatchQueue.main.async {
            if self.utteranceAtual.map(ObjectIdentifier.init) == cancelada { self.finalizar() }
        }
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
        estaLendo = false
        estaPausado = false
        itemAtualID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
