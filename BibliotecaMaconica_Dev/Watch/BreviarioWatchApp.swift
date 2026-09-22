import SwiftUI
import WatchConnectivity
import UserNotifications
import WatchKit

@main
struct BreviarioWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup {
            BreviarioWatchHomeView()
        }
    }
}

struct BreviarioWatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var leitura = BreviarioSnapshotProvider.leituraDoDia()
    @ObservedObject private var notificacoesRouter = WatchNotificationRouter.shared

    @State private var mensagem: String?
    @State private var lido = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    cabecalho

                    resumoLeitura

                    Divider()

                    Button {
                        WatchProgressService.definirLido(leitura.data, obraID: leitura.obraID, lido: lido == false)
                        lido.toggle()
                        mensagem = lido ? "Marcado como lido." : "Leitura marcada como pendente."
                    } label: {
                        Label(lido ? "Lido" : "Marcar lido", systemImage: lido ? "checkmark.seal.fill" : "checkmark.seal")
                    }

                    NavigationLink {
                        leituraCompleta
                    } label: {
                        Label("Abrir leitura", systemImage: "book")
                    }

                    notificacoes

                    if let mensagem {
                        Text(mensagem)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .navigationTitle("Breviário")
            .sheet(item: $notificacoesRouter.leitura) { selecionada in
                NavigationStack {
                    WatchReadingView(leitura: selecionada)
                }
            }
            .alert("Leitura indisponível", isPresented: $notificacoesRouter.indisponivel) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Esta obra não está disponível no relógio. Abra a leitura no iPhone.")
            }
            .onAppear {
                WatchNotificationService.registrarCategorias()
                WatchPhoneProgressSync.shared.iniciar { obraID, data, estado in
                    guard obraID == leitura.obraID, data == leitura.data else { return }
                    lido = estado
                }
                lido = WatchProgressService.estaLido(leitura.data, obraID: leitura.obraID)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    leitura = BreviarioSnapshotProvider.leituraDoDia()
                    lido = WatchProgressService.estaLido(leitura.data, obraID: leitura.obraID)
                }
            }
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(leitura.dataPorExtenso)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if lido {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(leitura.titulo)
                .font(.headline)
                .foregroundStyle(.yellow)
                .lineLimit(3)
        }
    }

    private var resumoLeitura: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resumo")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(leitura.resumo)
                .font(.footnote)
                .lineLimit(8)

            Text(leitura.autor)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var leituraCompleta: some View {
        WatchReadingView(leitura: leitura)
    }

    private var notificacoes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notificações")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Teste 5s") {
                WatchNotificationService.agendarTeste { sucesso in
                    Task { @MainActor in
                        mensagem = sucesso ? "Teste agendado." : "Permissao negada."
                    }
                }
            }

            Button("Ativar 08:00") {
                WatchNotificationService.agendarNotificacaoDiaria { sucesso in
                    Task { @MainActor in
                        mensagem = sucesso ? "Notificacao diaria ativa." : "Permissao negada."
                    }
                }
            }

            Button("Cancelar") {
                WatchNotificationService.cancelarNotificacaoDiaria()
                mensagem = "Notificacao cancelada."
            }
        }
    }
}

private struct WatchReadingView: View {
    let leitura: BreviarioSnapshot
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(leitura.dataPorExtenso).font(.caption2).foregroundStyle(.secondary)
                Text(leitura.titulo).font(.headline).foregroundStyle(.yellow)
                Text(leitura.texto).font(.footnote)
                if let notes = leitura.rodape, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider()
                    Text("Notas de rodapé").font(.caption).bold()
                    Text(notes).font(.footnote)
                }
            }
        }
        .navigationTitle("Leitura")
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = WatchNotificationRouter.shared
        WatchNotificationService.registrarCategorias()
        WatchPhoneProgressSync.shared.iniciar { _, _, _ in }
    }
}

final class WatchNotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = WatchNotificationRouter()
    @Published var leitura: BreviarioSnapshot?
    @Published var indisponivel = false

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let payload = response.notification.request.content.userInfo
        if let data = payload["data"] as? String {
            let obraID = payload["obraID"] as? String ?? "breviario_seculo_xxi"
            let encontrada = BreviarioSnapshotProvider.leitura(data: data, obraID: obraID)
            DispatchQueue.main.async {
                self.leitura = encontrada
                self.indisponivel = encontrada == nil
            }
        }
        completionHandler()
    }
}

enum WatchProgressService {

    static func estaLido(_ data: String, obraID: String) -> Bool {
        Set(UserDefaults.standard.stringArray(forKey: chaveConcluidos(obraID: obraID)) ?? []).contains(data)
    }

    static func definirLido(_ data: String, obraID: String, lido: Bool) {
        definirLidoLocal(data, obraID: obraID, lido: lido)
        WatchPhoneProgressSync.shared.enviar(obraID: obraID, data: data, lido: lido)
    }

    static func definirLidoLocal(_ data: String, obraID: String, lido: Bool) {
        var concluidos = Set(UserDefaults.standard.stringArray(forKey: chaveConcluidos(obraID: obraID)) ?? [])

        if lido {
            concluidos.insert(data)
        } else {
            concluidos.remove(data)
        }

        UserDefaults.standard.set(Array(concluidos).sorted(), forKey: chaveConcluidos(obraID: obraID))
    }

    private static func chaveConcluidos(obraID: String) -> String {
        obraID == "breviario_seculo_xxi" ? "leituras_concluidas" : "leituras_concluidas_\(obraID)"
    }
}

final class WatchPhoneProgressSync: Sendable {
    static let shared = WatchPhoneProgressSync()
    private let transport = ReadingProgressSyncTransport()

    func iniciar(aoReceber: @escaping @MainActor @Sendable (String, String, Bool) -> Void) {
        transport.start { event in
            WatchProgressService.definirLidoLocal(event.date, obraID: event.workID, lido: event.read)
            aoReceber(event.workID, event.date, event.read)
        }
    }

    func enviar(obraID: String, data: String, lido: Bool) {
        transport.enviar(obraID: obraID, data: data, lido: lido)
    }
}
