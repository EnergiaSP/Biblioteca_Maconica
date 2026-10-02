import SwiftUI
import UserNotifications

/// Review cards on the watch (relogio_revisao_v1.json): today's session sent by the iPhone, kept here
/// so it opens without the phone; each grade goes back to the iPhone, which applies the spaced review.
@MainActor
final class WatchRevisaoStore: ObservableObject {
    static let shared = WatchRevisaoStore()
    private let chave = "revisao_relogio_v1"

    @Published private(set) var baralho: BaralhoRelogio?
    /// Cards graded here and not yet replaced by a new session from the iPhone.
    @Published private(set) var respondidos: Set<String> = []

    private init() {
        baralho = UserDefaults.standard.data(forKey: chave).flatMap { try? JSONDecoder().decode(BaralhoRelogio.self, from: $0) }
    }

    var pendentes: [CartaoRelogio] { (baralho?.cartoes ?? []).filter { !respondidos.contains($0.id) } }

    func receber(_ novo: BaralhoRelogio) {
        baralho = novo
        respondidos = []
        UserDefaults.standard.set(try? JSONEncoder().encode(novo), forKey: chave)
        WatchRevisaoLembrete.agendar(novo)
    }

    func responder(_ cartao: CartaoRelogio, nota: String) {
        respondidos.insert(cartao.id)
        WatchPhoneProgressSync.shared.responder(id: cartao.id, nota: nota)
    }
}

/// Watch reminder of the cards due today, at 19:00, with the labels sent by the iPhone.
enum WatchRevisaoLembrete {
    static let identificador = "revisao-cartoes"

    static func agendar(_ baralho: BaralhoRelogio) {
        let central = UNUserNotificationCenter.current()
        central.removePendingNotificationRequests(withIdentifiers: [identificador])
        guard baralho.total > 0 else { return }
        var hora = DateComponents()
        hora.hour = 19
        hora.minute = 0
        guard let quando = Calendar.current.nextDate(after: Date(), matching: hora, matchingPolicy: .nextTime),
              Calendar.current.isDateInToday(quando) else { return }
        let conteudo = UNMutableNotificationContent()
        conteudo.title = baralho.rotulo("titulo")
        conteudo.body = baralho.rotulo("pendentes", ["n": "\(baralho.total)"])
        conteudo.sound = .default
        let gatilho = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: quando),
                                                    repeats: false)
        central.add(UNNotificationRequest(identifier: identificador, content: conteudo, trigger: gatilho))
    }
}

/// Entry on the watch home: how many cards are due and the way into the session.
struct WatchRevisaoEntrada: View {
    @ObservedObject var store = WatchRevisaoStore.shared

    var body: some View {
        if let baralho = store.baralho {
            NavigationLink {
                WatchRevisaoView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Label(baralho.rotulo("abrir"), systemImage: "rectangle.on.rectangle.angled")
                    Text(store.pendentes.isEmpty ? baralho.rotulo("vazio") : baralho.rotulo("pendentes", ["n": "\(store.pendentes.count)"]))
                        .font(.caption2)
                        .foregroundStyle(.black.opacity(0.75))  // on the gold button (BotaoDourado)
                }
            }
            .accessibilityIdentifier("watch.review")
        }
    }
}

struct WatchRevisaoView: View {
    @ObservedObject var store = WatchRevisaoStore.shared
    @State private var mostrando = false

    var body: some View {
        ScrollView {
            if let baralho = store.baralho, let cartao = store.pendentes.first {
                VStack(alignment: .leading, spacing: 10) {
                    Text(cartao.frente)
                        .font(.footnote)
                    if mostrando {
                        Text(cartao.verso)
                            .font(.headline)
                            .foregroundStyle(Color.douradoRelogio)
                        Text(baralho.rotulo("fonte", ["fonte": cartao.fonte]))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(["errei", "dificil", "acertei"], id: \.self) { nota in
                            Button(baralho.rotulo(nota)) {
                                store.responder(cartao, nota: nota)
                                mostrando = false
                            }
                            .accessibilityIdentifier("watch.review.\(nota)")
                        }
                    } else {
                        Button(baralho.rotulo("mostrar")) { mostrando = true }
                            .accessibilityIdentifier("watch.review.show")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(store.baralho?.rotulo("vazio") ?? "")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.baralho?.rotulo("titulo") ?? "")
    }
}
