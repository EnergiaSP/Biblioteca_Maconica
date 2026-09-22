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
    }

    func enviar(obraID: String, data: String, lido: Bool) {
        transport.enviar(obraID: obraID, data: data, lido: lido)
    }
}

extension Notification.Name {
    static let progressoLeituraSincronizado = Notification.Name("progressoLeituraSincronizado")
}
