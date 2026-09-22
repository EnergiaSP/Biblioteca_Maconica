import Foundation

@MainActor
final class BreviarioStore: ObservableObject {
@Published var obras: [BibliotecaObra] = BibliotecaObra.padroes
    @Published var obraSelecionada: BibliotecaObra = .breviarioSeculoXXI
    @Published var itens: [BreviarioItem] = [] {
        didSet {
            reconstruirIndices()
        }
    }
    @Published var indiceRemissivo: [IndiceRemissivoEntry] = []
    @Published var erro: String?
    @Published var importando = false
    @Published var progressoImportacao: String?
    @Published var carregando = false
    @Published var totalItensPorObra: [String: Int] = [:]
    @Published var fontesOficiais: [FonteOficialMaconica] = []
    var itensPorID: [Int: BreviarioItem] = [:]
    var itensPorData: [String: BreviarioItem] = [:]
    var itensPorPaginaDaObra: [Int: BreviarioItem] = [:]
    var indicesPorID: [Int: Int] = [:]
    var tarefaCarregamento: Task<Void, Never>?
    var tarefaCatalogo: Task<Void, Never>?
    static let chaveObraSelecionada = "biblioteca_obra_selecionada"
    nonisolated static let pastaDados = "BreviarioMaconicoXXI"
    nonisolated static let arquivoCatalogoObras = "catalogo-obras-personalizadas.json"
    nonisolated static let arquivoFontesOficiais = "fontes-oficiais.json"

    var itemDoDia: BreviarioItem? {
        let hoje = Self.formatoData.string(from: Date())
        return itensPorData[hoje] ?? itens.first
    }

    func item(id: Int?) -> BreviarioItem? {
        guard let id else {
            return itemDoDia
        }

        return itensPorID[id] ?? itemDoDia
    }

    func item(data: String) -> BreviarioItem? {
        itensPorData[data]
    }

    func item(dataEscolhida: Date) -> BreviarioItem? {
        let data = Self.formatoData.string(from: dataEscolhida)
        return item(data: data)
    }

    func item(paginaDaObra pagina: Int) -> BreviarioItem? {
        itensPorPaginaDaObra[pagina]
    }

    func itemAnterior(ao item: BreviarioItem) -> BreviarioItem? {
        guard itens.isEmpty == false,
              let indice = indicesPorID[item.id] else {
            return nil
        }

        let indiceAnterior = indice == itens.startIndex ? itens.index(before: itens.endIndex) : itens.index(before: indice)
        return itens[indiceAnterior]
    }

    func proximoItem(ao item: BreviarioItem) -> BreviarioItem? {
        guard itens.isEmpty == false,
              let indice = indicesPorID[item.id] else {
            return nil
        }

        let proximoIndice = itens.index(after: indice)
        return itens.indices.contains(proximoIndice) ? itens[proximoIndice] : itens[itens.startIndex]
    }

    func itensFiltrados(busca: String) -> [BreviarioItem] {
        let termo = busca.trimmingCharacters(in: .whitespacesAndNewlines)

        guard termo.isEmpty == false else {
            return itens
        }

        return itens.filter { item in
            item.data.localizedCaseInsensitiveContains(termo)
            || item.titulo.localizedCaseInsensitiveContains(termo)
            || item.frase.localizedCaseInsensitiveContains(termo)
            || item.texto.localizedCaseInsensitiveContains(termo)
        }
    }

    init() {
        obras = Self.carregarObrasDoCatalogo()
        let obraIDSalva = UserDefaults.standard.string(forKey: Self.chaveObraSelecionada)
            ?? ObraID.breviarioSeculoXXI
        obraSelecionada = obras.first(where: { $0.id == obraIDSalva })
            ?? .breviarioSeculoXXI
        carregar()
        carregarFontesOficiais()
        atualizarCatalogo()
    }

    func carregar() {
        carregar(obraID: obraSelecionada.id)
    }

    func selecionarObra(id obraID: String) {
        guard let obra = obras.first(where: { $0.id == obraID }) else {
            erro = "Obra nao encontrada na biblioteca."
            return
        }

        obraSelecionada = obra
        UserDefaults.standard.set(obra.id, forKey: Self.chaveObraSelecionada)
        carregar(obraID: obra.id)
    }

    func carregar(obraID: String) {
        let obra = obras.first(where: { $0.id == obraID }) ?? .breviarioSeculoXXI
        obraSelecionada = obra
        let url = urlImportado(obraID: obra.id)
            ?? obra.recursoJSON.flatMap { Bundle.main.url(forResource: $0, withExtension: "json") }

        guard let url else {
            carregarObraRAG(obraID: obra.id)
            return
        }

        tarefaCarregamento?.cancel()
        importando = false
        carregando = true
        itens = []
        indiceRemissivo = []
        erro = nil

        tarefaCarregamento = Task {
            do {
                let dadosCarregados = try await Task.detached(priority: .userInitiated) {
                    try Self.carregarDados(url: url, obraID: obra.id)
                }.value

                guard Task.isCancelled == false else {
                    return
                }

                itens = dadosCarregados.itens
                indiceRemissivo = dadosCarregados.indiceRemissivo
                atualizarSnapshotCompartilhado()
                erro = nil
                carregando = false
                tarefaCarregamento = nil
                atualizarCatalogo()
            } catch {
                guard Task.isCancelled == false else {
                    return
                }

                self.erro = "Nao foi possivel carregar o breviario."
                carregando = false
                tarefaCarregamento = nil
            }
        }
    }

    func importarPDF(url: URL, obraID: String? = nil) {
        let obraID = obraID ?? obraSelecionada.id
        tarefaCarregamento?.cancel()
        carregando = false
        importando = true
        progressoImportacao = nil
        erro = nil

        tarefaCarregamento = Task {
            do {
                let dadosImportados = try await Task.detached {
                    try Self.processarImportacao(url: url, obraID: obraID)
                }.value

                guard Task.isCancelled == false else {
                    return
                }

                self.itens = TextEditsService.aplicarEdicoes(em: dadosImportados.itens, obraID: obraID)
                self.indiceRemissivo = dadosImportados.indiceRemissivo
                self.atualizarSnapshotCompartilhado()
                self.itemAtualizadoAposImportacao()
                self.importando = false
                self.progressoImportacao = nil
                self.tarefaCarregamento = nil
                self.atualizarCatalogo()
            } catch {
                guard Task.isCancelled == false else {
                    return
                }

                self.erro = "Nao foi possivel importar o PDF."
                self.importando = false
                self.progressoImportacao = nil
                self.tarefaCarregamento = nil
            }
        }
    }

    func importarPDFsEmLote(_ entradas: [(url: URL, obraID: String)]) {
        guard entradas.isEmpty == false else {
            return
        }

        tarefaCarregamento?.cancel()
        carregando = false
        importando = true
        erro = nil

        tarefaCarregamento = Task {
            var ultimoDados: (obraID: String, dados: BreviarioData)?
            var falhas: [String] = []

            for (indice, entrada) in entradas.enumerated() {
                guard Task.isCancelled == false else {
                    return
                }

                self.progressoImportacao = "Importando \(indice + 1) de \(entradas.count)"

                do {
                    let dadosImportados = try await Task.detached {
                        try Self.processarImportacao(url: entrada.url, obraID: entrada.obraID)
                    }.value
                    ultimoDados = (entrada.obraID, dadosImportados)
                } catch {
                    falhas.append(entrada.url.deletingPathExtension().lastPathComponent)
                }
            }

            guard Task.isCancelled == false else {
                return
            }

            if let ultimoDados {
                self.selecionarObra(id: ultimoDados.obraID)
                self.itens = TextEditsService.aplicarEdicoes(
                    em: ultimoDados.dados.itens,
                    obraID: ultimoDados.obraID
                )
                self.indiceRemissivo = ultimoDados.dados.indiceRemissivo
                self.atualizarSnapshotCompartilhado()
                self.itemAtualizadoAposImportacao()
            }

            self.importando = false
            self.progressoImportacao = nil
            self.tarefaCarregamento = nil
            self.atualizarCatalogo()

            if falhas.isEmpty == false {
                self.erro = "\(falhas.count) arquivo(s) não puderam ser importados."
            }
        }
    }

    func salvarEdicao(item: BreviarioItem, edicao: BreviarioTextEdit) {
        TextEditsService.salvar(edicao: edicao, para: item.data, obraID: item.obraID)
        substituirItem(
            item.atualizado(
                titulo: edicao.titulo,
                frase: edicao.frase,
                texto: edicao.texto,
                rodape: edicao.rodape,
                autor: edicao.autor
            )
        )
    }

    func removerEdicao(item: BreviarioItem) {
        TextEditsService.remover(data: item.data, obraID: item.obraID)
        carregar(obraID: item.obraID)
    }

    func itensDisponiveisParaNotificacao() async -> [BreviarioItem] {
        await itensDisponiveisParaNotificacao(obraIDs: nil)
    }

    func itensDisponiveisParaNotificacao(obraIDs: Set<String>?) async -> [BreviarioItem] {
        let obrasAtivas = obras.filter { obra in
            obra.ativa
                && obra.tipo == .breviarioDiario
                && (obraIDs?.contains(obra.id) ?? true)
        }

        return await Task.detached(priority: .utility) {
            obrasAtivas.flatMap { obra in
                (try? Self.carregarItensDaObra(obra)) ?? []
            }
        }.value
    }

    nonisolated static func carregarItensParaResumo(obra: BibliotecaObra) throws -> [BreviarioItem] {
        try carregarItensDaObra(obra)
    }

    func obras(na area: BibliotecaArea) -> [BibliotecaObra] {
        obras.filter { $0.ativa && $0.area == area }
    }

    func obra(id obraID: String) -> BibliotecaObra? {
        obras.first { $0.id == obraID }
    }

    func criarObraPersonalizada(
        titulo: String,
        autor: String?,
        area: BibliotecaArea,
        tipo: BibliotecaObraTipo,
        assuntos: [String]
    ) throws -> BibliotecaObra {
        let tituloLimpo = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tituloLimpo.isEmpty == false else {
            throw CatalogoError.tituloObrigatorio
        }

        let obra = BibliotecaObra(
            id: Self.criarIDObra(titulo: tituloLimpo),
            titulo: tituloLimpo,
            autor: autor?.trimmingCharacters(in: .whitespacesAndNewlines).nilSeVazio,
            area: area,
            tipo: tipo,
            recursoJSON: nil,
            descricao: "Obra importada pelo usuário.",
            assuntos: assuntos.isEmpty ? ["Obra importada"] : assuntos,
            ativa: true
        )

        var obrasPersonalizadas = try Self.carregarObrasPersonalizadas()
        obrasPersonalizadas.removeAll { $0.id == obra.id }
        obrasPersonalizadas.append(obra)
        try Self.salvarObrasPersonalizadas(obrasPersonalizadas)

        obras = Self.carregarObrasDoCatalogo()
        atualizarCatalogo()
        return obra
    }

    func totalItens(area: BibliotecaArea) -> Int {
        obras(na: area).reduce(0) { parcial, obra in
            parcial + (totalItensPorObra[obra.id] ?? 0)
        }
    }
}
