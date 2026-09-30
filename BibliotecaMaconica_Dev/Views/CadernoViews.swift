import SwiftUI
import UniformTypeIdentifiers

/// The notebook as a JSON file for the system export sheet.
struct CadernoArquivo: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var dados: Data

    init(dados: Data) { self.dados = dados }

    init(configuration: ReadConfiguration) throws {
        dados = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: dados)
    }
}

/// Study notebook: what is kept on this device, export and import of the portable file, and the sync
/// options. Same sections and messages as Android `StudyNotebookScreen`.
struct CadernoEstudoView: View {
    let tema: TemaLeitura
    /// Work titles by id, for where each note comes from.
    var titulos: () -> [String: String] = { [:] }
    /// Opens a reading or a saved dossier (breviario:// link).
    var abrir: (URL) -> Void = { _ in }
    @State private var resumo = (leituras: 0, dossies: 0, cartoes: 0)
    @State private var arquivo: CadernoArquivo?
    @State private var exportando = false
    @State private var importando = false
    @State private var mensagem = ""
    @State private var opcao = CadernoSincronizacao.opcaoEscolhida
    @State private var sincronizando = false
    @State private var ultima = CadernoSincronizacao.ultimaSincronizacao
    @State private var codigo = ContaPropriaCaderno.codigoGuardado
    @State private var codigoDigitado = ""
    @State private var mostrandoCodigo = false
    private let conta = ContaPropriaCaderno.Configuracao.compartilhada
    private let configuracao = CadernoEstudo.Configuracao.compartilhada

    /// Options offered on this device: iCloud here, Google Drive on Android; the own account when published.
    private var opcoes: [CadernoSincronizacao.Opcao] {
        [.nenhuma, .icloud] + (ContaPropriaCaderno.disponivel ? [.contaPropria] : [])
    }

    private func nome(_ opcao: CadernoSincronizacao.Opcao) -> String {
        switch opcao {
        case .nenhuma: rotulo("opcaoNenhuma")
        case .icloud: rotulo("opcaoICloud")
        case .contaPropria: rotulo("opcaoContaPropria")
        }
    }

    private func rotulo(_ chave: String, _ valores: [String: String] = [:]) -> String {
        configuracao?.rotulo(chave, valores) ?? chave
    }

    private func contagens(_ caderno: CadernoEstudo.Caderno) -> [String: String] {
        ["leituras": "\(caderno.leituras.count)", "dossies": "\(caderno.dossies.count)", "cartoes": "\(caderno.cartoes.count)"]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(rotulo("titulo"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(tema.destaque)
                Text("Neste aparelho: \(resumo.leituras) leitura(s) com anotações, \(resumo.dossies) dossiê(s) salvo(s) e \(resumo.cartoes) cartão(ões) de revisão.")
                    .foregroundStyle(tema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("notebook.summary")

                if let configuracao {
                    CadernoPorTemaView(tema: tema, configuracao: configuracao, titulos: titulos, abrir: abrir)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Levar para outro aparelho")
                        .font(.headline)
                        .foregroundStyle(tema.textoPrincipal)
                    Text("O arquivo abre no iPhone, no iPad e no Android. Ao importar, nada do que já está no aparelho é apagado: anotações diferentes ficam as duas.")
                        .font(.subheadline)
                        .foregroundStyle(tema.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(rotulo("exportar")) { exportar() }
                        .buttonStyle(AccessibleActionButtonStyle(tema: tema))
                        .accessibilityIdentifier("notebook.export")
                    Button(rotulo("importar")) { importando = true }
                        .buttonStyle(AccessibleActionButtonStyle(tema: tema, prominent: false))
                        .accessibilityIdentifier("notebook.import")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tema.painel)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                sincronizacao

                if !mensagem.isEmpty {
                    Text(mensagem)
                        .foregroundStyle(tema.textoPrincipal)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("notebook.message")
                }
            }
            .padding()
            .frame(maxWidth: 760, alignment: .leading)
        }
        .onAppear { atualizarResumo() }
        .fileExporter(isPresented: $exportando, document: arquivo, contentType: .json,
                      defaultFilename: "caderno-biblioteca-maconica-\(DossieSalvo.data(Date()))") { resultado in
            if case .failure(let erro) = resultado { mensagem = "Não foi possível exportar. \(erro.localizedDescription)" }
        }
        .fileImporter(isPresented: $importando, allowedContentTypes: [.json]) { resultado in
            if case .success(let url) = resultado { importar(url) }
        }
    }

    private var sincronizacao: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(rotulo("sincronizacao"))
                .font(.headline)
                .foregroundStyle(tema.textoPrincipal)
            Text(rotulo("descricaoSincronizacao"))
                .font(.subheadline)
                .foregroundStyle(tema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            Picker(rotulo("sincronizacao"), selection: $opcao) {
                ForEach(opcoes) { Text(nome($0)).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .tint(tema.destaque)
            .accessibilityIdentifier("notebook.sync.option")
            .onChange(of: opcao) { _, nova in
                CadernoSincronizacao.opcaoEscolhida = nova
                if nova != .nenhuma { sincronizar() }
            }
            if opcao == .contaPropria {
                contaPropria
            }
            if opcao != .nenhuma && (opcao != .contaPropria || codigo != nil) {
                Button(sincronizando ? "Sincronizando..." : rotulo("sincronizar")) { sincronizar() }
                    .buttonStyle(AccessibleActionButtonStyle(tema: tema))
                    .disabled(sincronizando)
                    .accessibilityIdentifier("notebook.sync.now")
                if let ultima {
                    Text(rotulo("sincronizado", ["data": ultima.formatted(date: .numeric, time: .shortened)]))
                        .font(.caption)
                        .foregroundStyle(tema.textoSecundario)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Sync code of the own account: create one, enter the one of another device, show, copy or leave.
    @ViewBuilder
    private var contaPropria: some View {
        if let codigo, let conta {
            Text(conta.rotulo("codigo"))
                .font(.subheadline)
                .foregroundStyle(tema.textoSecundario)
            Text(mostrandoCodigo ? codigo : String(repeating: "••••-", count: 7) + "••••")
                .font(.body.monospaced())
                .foregroundStyle(tema.textoPrincipal)
                .textSelection(.enabled)
                .accessibilityIdentifier("notebook.account.code")
            Text(conta.rotulo("avisoCodigo"))
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { botoesConta(codigo, conta) }
                VStack(alignment: .leading, spacing: 8) { botoesConta(codigo, conta) }
            }
        } else if let conta {
            Button(conta.rotulo("criar")) {
                let novo = ContaPropriaCaderno.novoCodigo(conta)
                ContaPropriaCaderno.guardarCodigo(novo)
                codigo = novo
                mostrandoCodigo = true
                sincronizar()
            }
            .buttonStyle(AccessibleActionButtonStyle(tema: tema))
            .accessibilityIdentifier("notebook.account.create")
            TextField(conta.rotulo("codigo"), text: $codigoDigitado)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .padding(10)
                .background(tema.textoSecundario.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("notebook.account.input")
            Button(conta.rotulo("entrar")) {
                guard let normalizado = ContaPropriaCaderno.normalizar(codigoDigitado, conta) else {
                    mensagem = conta.rotulo("codigoInvalido")
                    return
                }
                let formatado = ContaPropriaCaderno.agrupar(normalizado, conta)
                ContaPropriaCaderno.guardarCodigo(formatado)
                codigo = formatado
                codigoDigitado = ""
                sincronizar()
            }
            .buttonStyle(AccessibleActionButtonStyle(tema: tema, prominent: false))
            .disabled(codigoDigitado.isEmpty)
            .accessibilityIdentifier("notebook.account.enter")
        }
    }

    @ViewBuilder
    private func botoesConta(_ codigo: String, _ conta: ContaPropriaCaderno.Configuracao) -> some View {
        Button(conta.rotulo("mostrar")) { mostrandoCodigo.toggle() }
            .buttonStyle(AccessibleActionButtonStyle(tema: tema, prominent: false))
        Button(conta.rotulo("copiar")) { UIPasteboard.general.string = codigo }
            .buttonStyle(AccessibleActionButtonStyle(tema: tema, prominent: false))
        Button(conta.rotulo("sair")) {
            ContaPropriaCaderno.guardarCodigo(nil)
            self.codigo = nil
            mostrandoCodigo = false
        }
        .buttonStyle(AccessibleActionButtonStyle(tema: tema, prominent: false))
    }

    private func sincronizar() {
        guard let configuracao, let provedor = CadernoSincronizacao.provedor(opcao), !sincronizando else { return }
        sincronizando = true
        Task { @MainActor in
            defer { sincronizando = false }
            do {
                let caderno = try await CadernoSincronizacao.sincronizar(com: provedor, configuracao: configuracao)
                ultima = CadernoSincronizacao.ultimaSincronizacao
                atualizarResumo()
                mensagem = rotulo("importado", contagens(caderno))
            } catch {
                mensagem = error.localizedDescription
            }
        }
    }

    private func atualizarResumo() {
        guard let configuracao else { return }
        let caderno = CadernoEstudo.coletar(configuracao: configuracao)
        resumo = (caderno.leituras.count, caderno.dossies.count, caderno.cartoes.count)
    }

    private func exportar() {
        guard let configuracao else { return }
        let caderno = CadernoEstudo.coletar(configuracao: configuracao)
        do {
            arquivo = CadernoArquivo(dados: try CadernoEstudo.codificar(caderno))
            mensagem = rotulo("exportado", contagens(caderno))
            exportando = true
        } catch {
            mensagem = "Não foi possível exportar. \(error.localizedDescription)"
        }
    }

    private func importar(_ url: URL) {
        guard let configuracao else { return }
        let acesso = url.startAccessingSecurityScopedResource()
        defer { if acesso { url.stopAccessingSecurityScopedResource() } }
        guard let dados = try? Data(contentsOf: url),
              let importado = CadernoEstudo.decodificar(dados, configuracao: configuracao) else {
            mensagem = rotulo("invalido")
            return
        }
        let mesclado = CadernoEstudo.mesclar(local: CadernoEstudo.coletar(configuracao: configuracao), importado: importado,
                                             hoje: DossieSalvo.data(Date()), configuracao: configuracao)
        CadernoEstudo.aplicar(mesclado)
        atualizarResumo()
        mensagem = rotulo("importado", contagens(mesclado))
    }
}

/// Every note of the notebook in one list, searchable, grouped by the themes of the saved dossiers.
struct CadernoPorTemaView: View {
    let tema: TemaLeitura
    let configuracao: CadernoEstudo.Configuracao
    let titulos: () -> [String: String]
    let abrir: (URL) -> Void
    @State private var consulta = ""
    @State private var anotacoes: [CadernoEstudo.Anotacao] = []
    @State private var temas: [CadernoEstudo.Tema] = []
    @State private var limite = 30

    private var regra: CadernoEstudo.RegraPorTema { configuracao.porTema }
    private var encontradas: [CadernoEstudo.Anotacao] { CadernoEstudo.buscar(anotacoes, consulta: consulta) }

    var body: some View {
        let encontradas = encontradas
        VStack(alignment: .leading, spacing: 10) {
            Text(regra.rotulo("titulo"))
                .font(.headline)
                .foregroundStyle(tema.textoPrincipal)
            Text(regra.rotulo("descricao"))
                .font(.subheadline)
                .foregroundStyle(tema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
            TextField(regra.rotulo("buscar"), text: $consulta)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .accessibilityIdentifier("notebook.theme.search")
            if !temas.isEmpty {
                Text(regra.rotulo("temas"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tema.textoPrincipal)
                FluxoDeChips(espaco: 8) {
                    ForEach(temas) { item in
                        Button("\(item.tema) (\(item.quantidade))") { consulta = item.tema; limite = 30 }
                            .buttonStyle(.bordered)
                            .tint(tema.destaque)
                            .accessibilityIdentifier("notebook.theme.\(item.tema)")
                    }
                }
            }
            Text(regra.rotulo("quantidade", ["n": "\(encontradas.count)"]))
                .font(.caption)
                .foregroundStyle(tema.textoSecundario)
                .accessibilityIdentifier("notebook.theme.count")
            if encontradas.isEmpty {
                Text(regra.rotulo("vazio")).foregroundStyle(tema.textoSecundario)
            } else {
                ShareLink(item: CadernoEstudo.exportar(encontradas, consulta: consulta, configuracao: configuracao)) {
                    Label(regra.rotulo("exportar"), systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("notebook.theme.export")
                ForEach(encontradas.prefix(limite)) { anotacao in
                    anotacaoView(anotacao)
                }
                if encontradas.count > limite {
                    Button("Mostrar mais") { limite += 30 }
                        .accessibilityIdentifier("notebook.theme.more")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { carregar() }
    }

    private func anotacaoView(_ anotacao: CadernoEstudo.Anotacao) -> some View {
        Button {
            if let url = link(anotacao) { abrir(url) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(anotacao.rotulo) — \(anotacao.origem)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tema.destaque)
                if !anotacao.texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(anotacao.texto)
                        .font(.callout)
                        .foregroundStyle(tema.textoPrincipal)
                        .multilineTextAlignment(.leading)
                        .lineLimit(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(tema.background.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityHint(regra.rotulo("abrir"))
        .accessibilityIdentifier("notebook.note")
    }

    private func link(_ anotacao: CadernoEstudo.Anotacao) -> URL? {
        var componentes = URLComponents()
        componentes.scheme = "breviario"
        if let dossie = anotacao.dossieId {
            componentes.host = "dossie"
            componentes.queryItems = [URLQueryItem(name: "id", value: dossie)]
        } else if let obra = anotacao.obraId, let data = anotacao.data {
            componentes.host = "leitura"
            componentes.queryItems = [URLQueryItem(name: "obra", value: obra), URLQueryItem(name: "data", value: data.replacingOccurrences(of: "/", with: "-"))]
        } else {
            return nil
        }
        return componentes.url
    }

    private func carregar() {
        let caderno = CadernoEstudo.coletar(configuracao: configuracao)
        anotacoes = CadernoEstudo.anotacoes(caderno, titulos: titulos(), configuracao: configuracao)
        temas = CadernoEstudo.temas(caderno, anotacoes: anotacoes)
    }
}
