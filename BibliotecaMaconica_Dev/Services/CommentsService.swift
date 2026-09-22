import Foundation
import Security

class CommentsService {
    private static let chaveDatasComComentario = "comentarios_datas_com_conteudo"

    static func salvar(
        comentario: String,
        para data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) {
        let texto = comentario.trimmingCharacters(in: .whitespacesAndNewlines)

        UserDefaults.standard.set(
            comentario,
            forKey: chaveComentario(data: data, obraID: obraID)
        )

        if usaChaveLegada(obraID) {
            UserDefaults.standard.set(comentario, forKey: "comentario_\(data)")
        }

        atualizarIndice(data: data, obraID: obraID, possuiComentario: texto.isEmpty == false)
    }

    static func carregar(
        data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) -> String {

        UserDefaults.standard.string(forKey: chaveComentario(data: data, obraID: obraID))
            ?? (usaChaveLegada(obraID) ? UserDefaults.standard.string(forKey: "comentario_\(data)") : nil)
            ?? ""
    }

    static func datasComComentario(
        datas: [String],
        obraID: String = ObraID.breviarioSeculoXXI
    ) -> Set<String> {
        let defaults = UserDefaults.standard
        let chaveIndice = chaveIndiceComentarios(obraID: obraID)
        var datasIndexadas = Set(defaults.stringArray(forKey: chaveIndice) ?? [])

        if datasIndexadas.isEmpty {
            datasIndexadas = Set(
                datas.filter { data in
                    carregar(data: data, obraID: obraID)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty == false
                }
            )
            defaults.set(Array(datasIndexadas).sorted(), forKey: chaveIndice)
        }

        let datasValidas = Set(datas)
        let datasFiltradas = datasIndexadas.intersection(datasValidas)

        if datasFiltradas.count != datasIndexadas.count {
            defaults.set(Array(datasFiltradas).sorted(), forKey: chaveIndice)
        }

        return datasFiltradas
    }

    private static func atualizarIndice(data: String, obraID: String, possuiComentario: Bool) {
        let defaults = UserDefaults.standard
        let chaveIndice = chaveIndiceComentarios(obraID: obraID)
        var datas = Set(defaults.stringArray(forKey: chaveIndice) ?? [])

        if possuiComentario {
            datas.insert(data)
        } else {
            datas.remove(data)
        }

        defaults.set(Array(datas).sorted(), forKey: chaveIndice)
    }

    private static func chaveComentario(data: String, obraID: String) -> String {
        usaChaveLegada(obraID) ? "comentario_\(data)" : "comentario_\(obraID)_\(data)"
    }

    private static func chaveIndiceComentarios(obraID: String) -> String {
        usaChaveLegada(obraID) ? chaveDatasComComentario : "\(chaveDatasComComentario)_\(obraID)"
    }

    private static func usaChaveLegada(_ obraID: String) -> Bool {
        obraID == ObraID.breviarioSeculoXXI
    }
}

struct DestaqueLeitura: Codable, Identifiable, Equatable {
    let id: UUID
    let texto: String
    let criadoEm: Date

    init(id: UUID = UUID(), texto: String, criadoEm: Date = Date()) {
        self.id = id
        self.texto = texto
        self.criadoEm = criadoEm
    }
}

enum ReflexoesService {

    static func salvar(
        _ reflexao: String,
        para data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) {
        UserDefaults.standard.set(reflexao, forKey: chave(data: data, obraID: obraID))
    }

    static func carregar(
        data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) -> String {
        UserDefaults.standard.string(forKey: chave(data: data, obraID: obraID)) ?? ""
    }

    static func todas(
        datas: [String],
        obraID: String = ObraID.breviarioSeculoXXI
    ) -> [(data: String, texto: String)] {
        datas.compactMap { data in
            let texto = carregar(data: data, obraID: obraID).trimmingCharacters(in: .whitespacesAndNewlines)
            return texto.isEmpty ? nil : (data, texto)
        }
    }

    private static func chave(data: String, obraID: String) -> String {
        obraID == ObraID.breviarioSeculoXXI ? "reflexao_\(data)" : "reflexao_\(obraID)_\(data)"
    }
}

enum DestaquesService {
    static let alterados = Notification.Name("DestaquesLeituraAlterados")

    static func salvar(
        _ destaque: String,
        para data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) {
        let texto = destaque.trimmingCharacters(in: .whitespacesAndNewlines)
        guard texto.isEmpty == false else {
            return
        }

        var destaques = carregar(data: data, obraID: obraID)
        destaques.insert(DestaqueLeitura(texto: texto), at: 0)
        salvar(destaques, para: data, obraID: obraID)
    }

    static func remover(
        _ destaque: DestaqueLeitura,
        de data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) {
        let destaques = carregar(data: data, obraID: obraID).filter { $0.id != destaque.id }
        salvar(destaques, para: data, obraID: obraID)
    }

    static func carregar(
        data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) -> [DestaqueLeitura] {
        guard let dados = UserDefaults.standard.data(forKey: chave(data: data, obraID: obraID)),
              let destaques = try? JSONDecoder().decode([DestaqueLeitura].self, from: dados) else {
            return []
        }

        return destaques
    }

    static func todos(
        datas: [String],
        obraID: String = ObraID.breviarioSeculoXXI
    ) -> [(data: String, destaques: [DestaqueLeitura])] {
        datas.compactMap { data in
            let destaques = carregar(data: data, obraID: obraID)
            return destaques.isEmpty ? nil : (data, destaques)
        }
    }

    private static func salvar(
        _ destaques: [DestaqueLeitura],
        para data: String,
        obraID: String
    ) {
        guard let dados = try? JSONEncoder().encode(destaques) else {
            return
        }

        UserDefaults.standard.set(dados, forKey: chave(data: data, obraID: obraID))
        NotificationCenter.default.post(name: alterados, object: nil,
                                        userInfo: ["obraID": obraID, "data": data])
    }

    private static func chave(data: String, obraID: String) -> String {
        obraID == ObraID.breviarioSeculoXXI ? "destaques_\(data)" : "destaques_\(obraID)_\(data)"
    }
}

struct AnaliseIA: Codable, Equatable {
    let resumo: String
    let explicacao: String
    let ideiasPrincipais: [String]
    let reflexao: String
    let perguntas: [String]
    let fontes: [String]
    let avisoConfiabilidade: String?
    let geradoEm: Date

    init(
        resumo: String = "",
        explicacao: String = "",
        ideiasPrincipais: [String] = [],
        reflexao: String = "",
        perguntas: [String] = [],
        fontes: [String] = [],
        avisoConfiabilidade: String? = nil,
        geradoEm: Date = Date()
    ) {
        self.resumo = resumo
        self.explicacao = explicacao
        self.ideiasPrincipais = ideiasPrincipais
        self.reflexao = reflexao
        self.perguntas = perguntas
        self.fontes = fontes
        self.avisoConfiabilidade = avisoConfiabilidade
        self.geradoEm = geradoEm
    }
}

enum AnaliseIAService {

    static func salvar(
        _ analise: AnaliseIA,
        para data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) {
        guard let dados = try? JSONEncoder().encode(analise) else {
            return
        }

        UserDefaults.standard.set(dados, forKey: chave(data: data, obraID: obraID))
    }

    static func carregar(
        data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) -> AnaliseIA? {
        guard let dados = UserDefaults.standard.data(forKey: chave(data: data, obraID: obraID)) else {
            return nil
        }

        return try? JSONDecoder().decode(AnaliseIA.self, from: dados)
    }

    private static func chave(data: String, obraID: String) -> String {
        obraID == ObraID.breviarioSeculoXXI ? "analise_ia_\(data)" : "analise_ia_\(obraID)_\(data)"
    }
}

enum GeminiAPIKeyStore {
    private static let servico = "BreviarioMaconicoXXI.GeminiAPIKey"
    private static let conta = "gemini"

    static func carregar() -> String {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: conta,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var resultado: AnyObject?
        let status = SecItemCopyMatching(consulta as CFDictionary, &resultado)
        guard status == errSecSuccess,
              let dados = resultado as? Data,
              let chave = String(data: dados, encoding: .utf8) else {
            return ""
        }

        return chave
    }

    static func salvar(_ chave: String) {
        let chaveLimpa = chave.trimmingCharacters(in: .whitespacesAndNewlines)
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: conta
        ]

        if chaveLimpa.isEmpty {
            SecItemDelete(consulta as CFDictionary)
            return
        }

        let dados = Data(chaveLimpa.utf8)
        let atributos: [String: Any] = [
            kSecValueData as String: dados,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(consulta as CFDictionary, atributos as CFDictionary)
        if status == errSecItemNotFound {
            var novoItem = consulta
            novoItem[kSecValueData as String] = dados
            novoItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(novoItem as CFDictionary, nil)
        }
    }
}

enum GeminiAnaliseService {
    enum GeminiError: LocalizedError {
        case chaveAusente
        case urlInvalida
        case respostaInvalida
        case respostaVazia
        case chaveInvalida
        case limiteGratuitoAtingido
        case modelosIndisponiveis
        case respostaIncompleta
        case fontesInvalidas
        case erroAPI(String)

        var errorDescription: String? {
            switch self {
            case .chaveAusente:
                "Informe a chave gratuita do Gemini antes de gerar a análise."
            case .urlInvalida:
                "Não foi possível montar a conexão com o Gemini."
            case .respostaInvalida:
                "O Gemini retornou uma resposta inválida."
            case .respostaVazia:
                "O Gemini não retornou conteúdo para salvar."
            case .chaveInvalida:
                "Chave Gemini inválida ou sem permissão. Verifique se a chave foi copiada corretamente no Google AI Studio."
            case .limiteGratuitoAtingido:
                "Limite gratuito atingido. Aguarde a liberação da cota do Gemini ou use outra chave com cota disponível."
            case .modelosIndisponiveis:
                "Os modelos gratuitos configurados não estão disponíveis para esta chave no momento."
            case .respostaIncompleta:
                "A IA interrompeu a resposta. Nenhuma análise parcial foi salva. Tente novamente."
            case .fontesInvalidas:
                "A resposta não possui referências documentais válidas. Nenhuma análise foi salva."
            case .erroAPI(let mensagem):
                mensagem
            }
        }
    }

    private static let modelos = [
        "gemini-2.5-flash-lite",
        "gemini-2.5-flash"
    ]

    static func gerarAnalise(prompt: String, chaveAPI: String) async throws -> String {
        try await gerar(prompt: prompt, chaveAPI: chaveAPI, responseMimeType: "application/json")
    }

    static func gerarTexto(prompt: String, chaveAPI: String) async throws -> String {
        try await gerar(prompt: prompt, chaveAPI: chaveAPI, responseMimeType: nil)
    }

    private static func gerar(
        prompt: String,
        chaveAPI: String,
        responseMimeType: String?
    ) async throws -> String {
        let chave = chaveAPI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard chave.isEmpty == false else {
            throw GeminiError.chaveAusente
        }

        var ultimoErro: Error?
        for modelo in modelos {
            try Task.checkCancellation()
            do {
                return try await gerar(
                    prompt: prompt,
                    chaveAPI: chave,
                    modelo: modelo,
                    responseMimeType: responseMimeType
                )
            } catch let erro as GeminiError {
                switch erro {
                case .chaveInvalida, .limiteGratuitoAtingido, .respostaIncompleta, .fontesInvalidas:
                    throw erro
                default:
                    ultimoErro = erro
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                ultimoErro = error
            }
        }

        if let ultimoErro {
            throw ultimoErro
        }

        throw GeminiError.modelosIndisponiveis
    }

    private static func gerar(
        prompt: String,
        chaveAPI: String,
        modelo: String,
        responseMimeType: String?
    ) async throws -> String {
        let componentes = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelo):generateContent"
        )

        guard let url = componentes?.url else {
            throw GeminiError.urlInvalida
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(chaveAPI, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(
            GeminiRequest(
                contents: [
                    GeminiContent(
                        parts: [
                            GeminiPart(text: prompt)
                        ]
                    )
                ],
                generationConfig: GeminiGenerationConfig(
                    temperature: 0.1,
                    responseMimeType: responseMimeType
                )
            )
        )

        let (dados, resposta) = try await URLSession.shared.data(for: request)
        guard let http = resposta as? HTTPURLResponse else {
            throw GeminiError.respostaInvalida
        }

        if http.statusCode >= 400 {
            if let erro = try? JSONDecoder().decode(GeminiErrorResponse.self, from: dados) {
                throw erroGemini(statusCode: http.statusCode, erro: erro)
            }

            throw GeminiError.erroAPI("Não foi possível gerar a análise. Código \(http.statusCode).")
        }

        return try extrairRespostaCompleta(dados)
    }

    static func extrairRespostaCompleta(_ dados: Data) throws -> String {
        guard let payload = try? JSONDecoder().decode(GeminiResponse.self, from: dados),
              let candidate = payload.candidates.first else {
            throw GeminiError.respostaVazia
        }
        guard candidate.finishReason == "STOP" else { throw GeminiError.respostaIncompleta }
        let texto = candidate.content?.parts.filter { $0.thought != true }.compactMap(\.text).joined(separator: "\n") ?? ""
        guard !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GeminiError.respostaVazia }
        return texto
    }

    static func validarCitacoes(_ texto: String, quantidadeFontes: Int) throws {
        guard quantidadeFontes > 0 else { throw GeminiError.fontesInvalidas }
        let pattern = try NSRegularExpression(pattern: #"\[F([0-9]+)\]"#)
        let matches = pattern.matches(in: texto, range: NSRange(texto.startIndex..., in: texto))
        guard !matches.isEmpty, matches.allSatisfy({ match in
            guard let range = Range(match.range(at: 1), in: texto), let id = Int(texto[range]) else { return false }
            return (1...quantidadeFontes).contains(id)
        }) else { throw GeminiError.fontesInvalidas }
    }

    private static func erroGemini(statusCode: Int, erro: GeminiErrorResponse) -> GeminiError {
        let mensagem = erro.error.message
        let status = erro.error.status?.uppercased() ?? ""

        if statusCode == 401 || statusCode == 403
            || status.contains("API_KEY_INVALID")
            || status.contains("PERMISSION_DENIED")
            || mensagem.localizedCaseInsensitiveContains("API key not valid") {
            return .chaveInvalida
        }

        if statusCode == 429
            || status.contains("RESOURCE_EXHAUSTED")
            || mensagem.localizedCaseInsensitiveContains("quota")
            || mensagem.localizedCaseInsensitiveContains("rate limit") {
            return .limiteGratuitoAtingido
        }

        if statusCode == 404
            || mensagem.localizedCaseInsensitiveContains("not found")
            || mensagem.localizedCaseInsensitiveContains("not supported")
            || mensagem.localizedCaseInsensitiveContains("model") {
            return .modelosIndisponiveis
        }

        return .erroAPI(mensagem)
    }
}

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String?
    let thought: Bool?

    init(text: String?) {
        self.text = text
        self.thought = nil
    }
}

private struct GeminiGenerationConfig: Encodable {
    let temperature: Double
    let responseMimeType: String?
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent?
    let finishReason: String?
}

private struct GeminiErrorResponse: Decodable {
    let error: GeminiAPIError
}

private struct GeminiAPIError: Decodable {
    let code: Int?
    let message: String
    let status: String?
}

enum ReadingProgressService {

    static func favoritos(obraID: String = ObraID.breviarioSeculoXXI) -> Set<String> {
        carregarSet(chaveFavoritos, obraID: obraID)
    }

    static func concluidos(obraID: String = ObraID.breviarioSeculoXXI) -> Set<String> {
        carregarSet(chaveConcluidos, obraID: obraID)
    }

    static func recentes(obraID: String = ObraID.breviarioSeculoXXI) -> [String] {
        UserDefaults.standard.stringArray(forKey: chave(chaveRecentes, obraID: obraID)) ?? []
    }

    static func registrarRecente(
        _ data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) {
        var recentes = recentes(obraID: obraID).filter { $0 != data }
        recentes.insert(data, at: 0)

        if recentes.count > limiteRecentes {
            recentes = Array(recentes.prefix(limiteRecentes))
        }

        UserDefaults.standard.set(recentes, forKey: chave(chaveRecentes, obraID: obraID))
    }

    static func alternarFavorito(
        _ data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) {
        var favoritos = favoritos(obraID: obraID)

        if favoritos.contains(data) {
            favoritos.remove(data)
        } else {
            favoritos.insert(data)
        }

        salvarSet(favoritos, chave: chaveFavoritos, obraID: obraID)
    }

    static func alternarConcluido(
        _ data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) {
        definirConcluido(data, obraID: obraID, lido: concluidos(obraID: obraID).contains(data) == false)
    }

    static func definirConcluido(
        _ data: String,
        obraID: String = ObraID.breviarioSeculoXXI,
        lido: Bool,
        sincronizar: Bool = true
    ) {
        var valores = concluidos(obraID: obraID)
        if lido { valores.insert(data) } else { valores.remove(data) }
        salvarSet(valores, chave: chaveConcluidos, obraID: obraID)
        if sincronizar {
            PhoneWatchProgressSync.shared.enviar(obraID: obraID, data: data, lido: lido)
        }
    }

    private static func carregarSet(_ chaveBase: String, obraID: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: chave(chaveBase, obraID: obraID)) ?? [])
    }

    private static func salvarSet(_ valores: Set<String>, chave chaveBase: String, obraID: String) {
        UserDefaults.standard.set(Array(valores).sorted(), forKey: chave(chaveBase, obraID: obraID))
    }

    private static func chave(_ chaveBase: String, obraID: String) -> String {
        obraID == ObraID.breviarioSeculoXXI ? chaveBase : "\(chaveBase)_\(obraID)"
    }

    private static let chaveFavoritos = "leituras_favoritas"
    private static let chaveConcluidos = "leituras_concluidas"
    private static let chaveRecentes = "leituras_recentes"
    private static let limiteRecentes = 5
}
