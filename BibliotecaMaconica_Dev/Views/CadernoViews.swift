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
    @State private var resumo = (leituras: 0, dossies: 0, cartoes: 0)
    @State private var arquivo: CadernoArquivo?
    @State private var exportando = false
    @State private var importando = false
    @State private var mensagem = ""
    private let configuracao = CadernoEstudo.Configuracao.compartilhada

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
