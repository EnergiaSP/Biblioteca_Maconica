import Foundation
import UserNotifications

enum NotificationService {

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

    static func agendarNotificacaoDiaria(
        hora: Int,
        minuto: Int,
        itens: [BreviarioItem],
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        registrarCategorias()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { permitido, _ in
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

                guard let data = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else {
                    continue
                }

                var componentes = Calendar.current.dateComponents([.year, .month, .day], from: data)
                componentes.hour = hora
                componentes.minute = minuto

                guard let dataNotificacao = Calendar.current.date(from: componentes),
                      dataNotificacao > agora else {
                    continue
                }

                for item in itensParaData(data, em: itens) {
                    guard requests.count < quantidadeMaximaAgendada else {
                        break
                    }

                    let conteudo = UNMutableNotificationContent()
                    conteudo.title = "\(item.data) - \(item.titulo)"
                    conteudo.subtitle = tituloObra(item.obraID)
                    conteudo.body = resumoNotificacao(item)
                    conteudo.categoryIdentifier = categoriaLeitura
                    conteudo.userInfo = [
                        "obraID": item.obraID,
                        "data": item.data,
                        "url": "breviario://leitura?obra=\(item.obraID)&data=\(item.data.replacingOccurrences(of: "/", with: "-"))"
                    ]
                    conteudo.sound = .default

                    let trigger = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: identificador(data: item.data, obraID: item.obraID, offset: offset),
                        content: conteudo,
                        trigger: trigger
                    )
                    requests.append(request)
                }
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

    static func cancelarNotificacaoDiaria() {
        Task {
            await removerNotificacoesDoBreviario()
        }
    }

    static func agendarTeste(item: BreviarioItem, completion: @escaping @Sendable (Bool) -> Void) {
        registrarCategorias()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { permitido, _ in
            guard permitido else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            let conteudo = UNMutableNotificationContent()
            conteudo.title = "\(item.data) - \(item.titulo)"
            conteudo.subtitle = "Teste de notificacao"
            conteudo.body = resumoNotificacao(item)
            conteudo.categoryIdentifier = categoriaLeitura
            conteudo.userInfo = [
                "obraID": item.obraID,
                "data": item.data,
                "url": "breviario://leitura?obra=\(item.obraID)&data=\(item.data.replacingOccurrences(of: "/", with: "-"))"
            ]
            conteudo.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(prefixoIdentificador).teste",
                content: conteudo,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                    completion(error == nil)
                }
            }
        }
    }

    private static func identificador(data: String, obraID: String, offset: Int) -> String {
        "\(prefixoIdentificador).\(obraID).\(offset).\(data.replacingOccurrences(of: "/", with: "-"))"
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

    private static func itensParaData(_ date: Date, em itens: [BreviarioItem]) -> [BreviarioItem] {
        let data = formatoData.string(from: date)
        return itens.filter { $0.data == data }
    }

    private static func tituloObra(_: String) -> String {
        BreviarioImportService.cabecalho
    }

    private static func resumoNotificacao(_ item: BreviarioItem) -> String {
        let texto = item.texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard texto.count > limiteCaracteresCorpo else {
            return texto
        }

        let limite = texto.index(texto.startIndex, offsetBy: limiteCaracteresCorpo)
        return "\(texto[..<limite])..."
    }

    private static let prefixoIdentificador = "breviario.notificacao.diaria"
    private static let categoriaLeitura = "breviario.categoria.leitura"
    private static let acaoAbrirLeitura = "breviario.acao.abrir"
    private static let quantidadeMaximaAgendada = 60
    private static let limiteDiasBusca = 90
    private static let limiteCaracteresCorpo = 220

    private static let formatoData: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter
    }()
}
