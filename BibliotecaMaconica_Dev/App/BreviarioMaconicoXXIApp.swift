import SwiftUI
import WatchConnectivity

@main
struct BreviarioMaconicoXXIApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        UserDataPersistenceService.iniciar()
        PhoneWatchProgressSync.shared.iniciar()
    }

    var body: some Scene {

        WindowGroup {
            ActivationGateView()
        }
    }
}

final class PhoneWatchProgressSync: Sendable {
    static let shared = PhoneWatchProgressSync()
    private let transport = ReadingProgressSyncTransport()

    func iniciar() {
        transport.start { event in
            ReadingProgressService.definirConcluido(event.date, obraID: event.workID, lido: event.read, sincronizar: false)
            NotificationCenter.default.post(name: .progressoLeituraSincronizado, object: nil)
        }
        Task { @MainActor in
            // A grade given on the watch follows the same spaced review as here; the session is sent again.
            transport.observarRevisao(resposta: { resposta in
                guard let configuracao = RevisaoAtiva.Configuracao.compartilhada,
                      let nota = RevisaoAtiva.Nota(rawValue: resposta.nota) else { return }
                CartoesRevisaoStore().responder(id: resposta.id, nota: nota, hoje: DossieSalvo.data(Date()), configuracao: configuracao)
                NotificationCenter.default.post(name: .revisaoAtualizadaPeloRelogio, object: nil)
                self.enviarRevisao()
            })
            enviarRevisao()
        }
    }

    /// Today's review session to the watch, with its labels (relogio_revisao_v1.json).
    @MainActor func enviarRevisao() {
        guard let revisao = RevisaoAtiva.Configuracao.compartilhada, let relogio = RevisaoRelogio.compartilhada else { return }
        let hoje = DossieSalvo.data(Date())
        let sessao = CartoesRevisaoStore().sessao(hoje: hoje, configuracao: revisao)
        let cartoes = sessao.prefix(relogio.limiteCartoes).map {
            CartaoRelogio(id: $0.cartao.id, frente: $0.cartao.frente, verso: $0.cartao.verso, fonte: $0.cartao.fonte)
        }
        transport.enviarBaralho(BaralhoRelogio(hoje: hoje, total: sessao.count, cartoes: Array(cartoes), rotulos: relogio.rotulos))
    }

    func enviar(obraID: String, data: String, lido: Bool) {
        transport.enviar(obraID: obraID, data: data, lido: lido)
    }
}

extension Notification.Name {
    static let progressoLeituraSincronizado = Notification.Name("progressoLeituraSincronizado")
    static let revisaoAtualizadaPeloRelogio = Notification.Name("revisaoAtualizadaPeloRelogio")
}

/// Limit and labels of the review cards on the watch (relogio_revisao_v1.json).
struct RevisaoRelogio: Decodable {
    let schemaVersion: Int
    let limiteCartoes: Int
    let rotulos: [String: String]

    static let compartilhada: RevisaoRelogio? = {
        guard let url = Bundle.main.url(forResource: "relogio_revisao_v1", withExtension: "json"),
              let dados = try? Data(contentsOf: url),
              let configuracao = try? JSONDecoder().decode(RevisaoRelogio.self, from: dados),
              configuracao.schemaVersion == 1 else { return nil }
        return configuracao
    }()
}
