import CryptoKit
import Foundation
import Security

/// The app's own account: a sync code without e-mail or password; the notebook is encrypted on the
/// device and the server keeps only the encrypted file. Mirrors `Tools/conta_propria_referencia.mjs`;
/// `casos_conta_propria_v1.json` holds the golden cases both apps reproduce.
enum ContaPropriaCaderno {
    struct Configuracao: Decodable {
        let schemaVersion: Int
        let alfabeto: String
        let bytesCodigo: Int
        let tamanhoGrupo: Int
        let prefixoConta: String
        let prefixoCredencial: String
        let prefixoChave: String
        let tamanhoMaximoBytes: Int
        let servidor: String
        let rotulos: [String: String]

        static let compartilhada: Configuracao? = {
            guard let url = Bundle.main.url(forResource: "conta_propria_v1", withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let configuracao = try? JSONDecoder().decode(Configuracao.self, from: dados),
                  configuracao.schemaVersion == 1 else { return nil }
            return configuracao
        }()

        func rotulo(_ chave: String) -> String { rotulos[chave] ?? chave }
    }

    struct Derivacao: Equatable {
        let conta: String
        let credencial: String
        let chave: Data
    }

    // MARK: - Código

    static func formatar(_ bytes: Data, _ c: Configuracao) -> String {
        let alfabeto = Array(c.alfabeto)
        var bits = 0, valor = 0, saida = ""
        for byte in bytes {
            valor = ((valor << 8) | Int(byte)) & 0xFFFF
            bits += 8
            while bits >= 5 {
                saida.append(alfabeto[(valor >> (bits - 5)) & 31])
                bits -= 5
            }
        }
        if bits > 0 { saida.append(alfabeto[(valor << (5 - bits)) & 31]) }
        return agrupar(saida, c)
    }

    /// "ABCDEFGH..." as "ABCD-EFGH-...".
    static func agrupar(_ codigo: String, _ c: Configuracao) -> String {
        stride(from: 0, to: codigo.count, by: c.tamanhoGrupo)
            .map { String(codigo.dropFirst($0).prefix(c.tamanhoGrupo)) }
            .joined(separator: "-")
    }

    static func novoCodigo(_ c: Configuracao) -> String {
        var bytes = Data(count: c.bytesCodigo)
        let resultado = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, c.bytesCodigo, $0.baseAddress!) }
        precondition(resultado == errSecSuccess, "Random bytes unavailable")
        return formatar(bytes, c)
    }

    /// Upper case, without hyphens and spaces; nil unless it has the exact length and only alphabet letters.
    static func normalizar(_ codigo: String, _ c: Configuracao) -> String? {
        let limpo = codigo.uppercased().filter { $0 != "-" && !$0.isWhitespace }
        let tamanho = (c.bytesCodigo * 8 + 4) / 5
        guard limpo.count == tamanho, limpo.allSatisfy({ c.alfabeto.contains($0) }) else { return nil }
        return limpo
    }

    private static func sha256(_ texto: String) -> Data { Data(SHA256.hash(data: Data(texto.utf8))) }
    private static func hex(_ dados: Data) -> String { dados.map { String(format: "%02x", $0) }.joined() }

    static func derivar(_ codigo: String, _ c: Configuracao) -> Derivacao {
        Derivacao(conta: String(hex(sha256(c.prefixoConta + codigo)).prefix(32)),
                  credencial: hex(sha256(c.prefixoCredencial + codigo)),
                  chave: sha256(c.prefixoChave + codigo))
    }

    // MARK: - Arquivo cifrado

    /// nonce (12 bytes) + ciphertext + tag (16 bytes), AES-256-GCM.
    static func cifrar(_ dados: Data, chave: Data, nonce: Data? = nil) throws -> Data {
        let n = try nonce.map { try AES.GCM.Nonce(data: $0) } ?? AES.GCM.Nonce()
        guard let combinado = try AES.GCM.seal(dados, using: SymmetricKey(data: chave), nonce: n).combined else {
            throw CadernoSincronizacao.Falha.indisponivel("Não foi possível cifrar o caderno.")
        }
        return combinado
    }

    static func decifrar(_ combinado: Data, chave: Data) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: combinado), using: SymmetricKey(data: chave))
    }

    // MARK: - Código guardado no Keychain

    private static let servico = "caderno-conta-propria"

    static var codigoGuardado: String? {
        let consulta: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servico,
                                       kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(consulta as CFDictionary, &item) == errSecSuccess, let dados = item as? Data else { return nil }
        return String(data: dados, encoding: .utf8)
    }

    static func guardarCodigo(_ codigo: String?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servico]
        SecItemDelete(base as CFDictionary)
        guard let codigo else { return }
        var novo = base
        novo[kSecValueData as String] = Data(codigo.utf8)
        novo[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(novo as CFDictionary, nil)
    }

    // MARK: - Servidor

    /// The published server, or a local one for tests (`contaPropriaServidorTeste`).
    static var servidor: String {
        UserDefaults.standard.string(forKey: "contaPropriaServidorTeste") ?? Configuracao.compartilhada?.servidor ?? ""
    }

    /// The option is offered once the server is published.
    static var disponivel: Bool { !servidor.isEmpty }

    static func provedor() -> ProvedorCaderno? {
        guard disponivel, let configuracao = Configuracao.compartilhada, let codigo = codigoGuardado,
              let normalizado = normalizar(codigo, configuracao) else { return nil }
        return ProvedorContaPropria(servidor: servidor, derivacao: derivar(normalizado, configuracao), configuracao: configuracao)
    }
}

/// Reads and writes the encrypted notebook; the version read is sent back, so an upload never replaces
/// one made by another device in between.
final class ProvedorContaPropria: ProvedorCaderno, @unchecked Sendable {
    let opcao = CadernoSincronizacao.Opcao.contaPropria
    private let url: URL
    private let derivacao: ContaPropriaCaderno.Derivacao
    private let configuracao: ContaPropriaCaderno.Configuracao
    private var versao: String?

    init(servidor: String, derivacao: ContaPropriaCaderno.Derivacao, configuracao: ContaPropriaCaderno.Configuracao) {
        url = URL(string: "\(servidor.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/v1/caderno/\(derivacao.conta)")!
        self.derivacao = derivacao
        self.configuracao = configuracao
    }

    private func pedido(_ metodo: String) -> URLRequest {
        var pedido = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        pedido.httpMethod = metodo
        pedido.setValue("Bearer \(derivacao.credencial)", forHTTPHeaderField: "Authorization")
        return pedido
    }

    private func enviar(_ pedido: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (dados, resposta) = try await URLSession.shared.data(for: pedido)
            guard let http = resposta as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            return (dados, http)
        } catch {
            throw CadernoSincronizacao.Falha.indisponivel(configuracao.rotulo("semRede"))
        }
    }

    func ler() async throws -> Data? {
        let (dados, resposta) = try await enviar(pedido("GET"))
        switch resposta.statusCode {
        case 404:
            versao = nil
            return nil
        case 200:
            versao = resposta.value(forHTTPHeaderField: "ETag")
            return try ContaPropriaCaderno.decifrar(dados, chave: derivacao.chave)
        default:
            throw CadernoSincronizacao.Falha.indisponivel(configuracao.rotulo("semRede"))
        }
    }

    func gravar(_ dados: Data) async throws {
        var pedido = pedido("PUT")
        if let versao { pedido.setValue(versao, forHTTPHeaderField: "If-Match") } else { pedido.setValue("*", forHTTPHeaderField: "If-None-Match") }
        pedido.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = try ContaPropriaCaderno.cifrar(dados, chave: derivacao.chave)
        let (_, resposta) = try await enviar(pedido)
        switch resposta.statusCode {
        case 204: versao = resposta.value(forHTTPHeaderField: "ETag")
        case 412: throw CadernoSincronizacao.Falha.indisponivel(configuracao.rotulo("conflito"))
        default: throw CadernoSincronizacao.Falha.indisponivel(configuracao.rotulo("semRede"))
        }
    }
}
