import Foundation
import UserNotifications

enum WatchNotificationService {

    static func registrarCategorias() {
        let abrir = UNNotificationAction(
            identifier: acaoAbrirLeitura,
            title: "Abrir leitura",
            options: [.foreground]
        )

        let categoria = UNNotificationCategory(
            identifier: categoriaLeitura,
            actions: [abrir],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([categoria])
    }

    static func agendarNotificacaoDiaria(hora: Int = 8, minuto: Int = 0, completion: @escaping @Sendable (Bool) -> Void) {
        registrarCategorias()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { permitido, _ in
            guard permitido else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            var requests: [UNNotificationRequest] = []
            var offset = 0
            let agora = Date()

            while requests.count < quantidadeMaximaAgendada, offset < limiteDiasBusca {
                defer { offset += 1 }

                guard let data = Calendar.current.date(byAdding: .day, value: offset, to: agora) else {
                    continue
                }

                var componentes = Calendar.current.dateComponents([.year, .month, .day], from: data)
                componentes.hour = hora
                componentes.minute = minuto

                guard let dataNotificacao = Calendar.current.date(from: componentes),
                      dataNotificacao > agora else {
                    continue
                }

                let leitura = BreviarioSnapshotProvider.leituraDoDia(data: data)
                let conteudo = conteudoNotificacao(leitura: leitura)
                let trigger = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
                let request = UNNotificationRequest(
                    identifier: identificador(data: leitura.data, offset: offset),
                    content: conteudo,
                    trigger: trigger
                )
                requests.append(request)
            }

            guard requests.isEmpty == false else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            Task {
                await removerNotificacoesDoBreviario()

                var sucesso = true
                for request in requests {
                    let adicionou = await adicionar(request)
                    if adicionou == false {
                        sucesso = false
                    }
                }

                await MainActor.run {
                    completion(sucesso)
                }
            }
        }
    }

    static func agendarTeste(completion: @escaping @Sendable (Bool) -> Void) {
        registrarCategorias()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { permitido, _ in
            guard permitido else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            let leitura = BreviarioSnapshotProvider.leituraDoDia()
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(prefixoIdentificador).teste",
                content: conteudoNotificacao(leitura: leitura),
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                    completion(error == nil)
                }
            }
        }
    }

    static func cancelarNotificacaoDiaria() {
        Task {
            await removerNotificacoesDoBreviario()
        }
    }

    private static func conteudoNotificacao(leitura: BreviarioSnapshot) -> UNMutableNotificationContent {
        let conteudo = UNMutableNotificationContent()
        conteudo.title = "\(leitura.data) - \(leitura.titulo)"
        conteudo.subtitle = "Biblioteca Maçônica"
        conteudo.body = resumoNotificacao(leitura)
        conteudo.categoryIdentifier = categoriaLeitura
        conteudo.userInfo = [
            "data": leitura.data,
            "obraID": leitura.obraID,
            "titulo": leitura.titulo
        ]
        conteudo.sound = .default
        return conteudo
    }

    private static func identificador(data: String, offset: Int) -> String {
        "\(prefixoIdentificador).\(offset).\(data.replacingOccurrences(of: "/", with: "-"))"
    }

    private static func adicionar(_ request: UNNotificationRequest) async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    private static func removerNotificacoesDoBreviario() async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let ids = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(prefixoIdentificador) }

                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                continuation.resume()
            }
        }
    }

    private static func resumoNotificacao(_ leitura: BreviarioSnapshot) -> String {
        let texto = leitura.texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard texto.count > limiteCaracteresCorpo else {
            return texto
        }

        let limite = texto.index(texto.startIndex, offsetBy: limiteCaracteresCorpo)
        return "\(texto[..<limite])..."
    }

    private static let prefixoIdentificador = "breviario.watch.notificacao.diaria"
    private static let categoriaLeitura = "breviario.watch.categoria.leitura"
    private static let acaoAbrirLeitura = "breviario.watch.acao.abrir"
    private static let quantidadeMaximaAgendada = 60
    private static let limiteDiasBusca = 90
    private static let limiteCaracteresCorpo = 180
}
