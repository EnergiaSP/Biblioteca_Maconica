import Foundation

struct BreviarioTextEdit: Codable {
    let titulo: String
    let frase: String
    let texto: String
    let rodape: String?
    let autor: String?
}

enum TextEditsService {

    static func salvar(
        edicao: BreviarioTextEdit,
        para data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) {
        var edicoes = carregarTodas(obraID: obraID)
        edicoes[data] = edicao
        salvarTodas(edicoes, obraID: obraID)
    }

    static func carregar(
        data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) -> BreviarioTextEdit? {
        carregarTodas(obraID: obraID)[data]
    }

    static func remover(
        data: String,
        obraID: String = ObraID.breviarioSeculoXXI
    ) {
        var edicoes = carregarTodas(obraID: obraID)
        edicoes.removeValue(forKey: data)
        salvarTodas(edicoes, obraID: obraID)
    }

    static func aplicarEdicoes(
        em itens: [BreviarioItem],
        obraID: String = ObraID.breviarioSeculoXXI
    ) -> [BreviarioItem] {
        let edicoes = carregarTodas(obraID: obraID)

        guard edicoes.isEmpty == false else {
            return itens
        }

        return itens.map { item in
            guard let edicao = edicoes[item.data] else {
                return item
            }

            return item.atualizado(
                titulo: edicao.titulo,
                frase: edicao.frase,
                texto: edicao.texto,
                rodape: edicao.rodape,
                autor: edicao.autor
            )
        }
    }

    private static func carregarTodas(obraID: String) -> [String: BreviarioTextEdit] {
        guard let dados = UserDefaults.standard.data(forKey: chave(obraID: obraID)),
              let edicoes = try? JSONDecoder().decode([String: BreviarioTextEdit].self, from: dados) else {
            return [:]
        }

        return edicoes
    }

    private static func salvarTodas(_ edicoes: [String: BreviarioTextEdit], obraID: String) {
        guard let dados = try? JSONEncoder().encode(edicoes) else {
            return
        }

        UserDefaults.standard.set(dados, forKey: chave(obraID: obraID))
    }

    private static func chave(obraID: String) -> String {
        obraID == ObraID.breviarioSeculoXXI ? chaveLegada : "\(chaveLegada)_\(obraID)"
    }

    private static let chaveLegada = "edicoes_textos_diarios"
}
