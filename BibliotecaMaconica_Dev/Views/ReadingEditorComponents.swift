import SwiftUI
import UIKit

struct IndiceRemissivoView: View {

    let entradas: [IndiceRemissivoEntry]
    @Binding var busca: String
    let tema: TemaLeitura
    let selecionar: (IndiceRemissivoEntry, Int?) -> Void
    @State private var entradasFiltradas: [IndiceRemissivoEntry] = []
    @State private var buscaTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            tema.background
                .ignoresSafeArea()

            List {
                if entradasFiltradas.isEmpty {
                    ContentUnavailableView(
                        "Índice Remissivo",
                        systemImage: "text.magnifyingglass",
                        description: Text("O índice será preenchido pela importação do PDF.")
                    )
                    .foregroundStyle(tema.textoPrincipal)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(entradasFiltradas) { entrada in
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                selecionar(entrada, nil)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(entrada.termo)
                                            .font(.headline)
                                            .foregroundStyle(tema.textoPrincipal)

                                        Text("Páginas: \(entrada.paginasFormatadas)")
                                            .font(.caption)
                                            .foregroundStyle(tema.textoSecundario)

                                        if entrada.datas.isEmpty == false {
                                            Text("Datas: \(entrada.datas.joined(separator: ", "))")
                                                .font(.caption)
                                                .foregroundStyle(tema.textoSecundario)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(tema.destaque)
                                }
                            }
                            .buttonStyle(.plain)

                            if entrada.paginas.isEmpty == false {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(entrada.paginas, id: \.self) { pagina in
                                            Button {
                                                selecionar(entrada, pagina)
                                            } label: {
                                                Text("Pág. \(pagina)")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .foregroundStyle(tema.textoPrincipal)
                                                    .background(tema.destaque.opacity(0.16))
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .accessibilityLabel("Páginas vinculadas")
                            }
                        }
                        .listRowBackground(tema.painel)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(tema.textoPrincipal)
            .tint(tema.destaque)
        }
        .navigationTitle("Índice Remissivo")
        .searchable(text: $busca, prompt: "Buscar no índice")
        .onAppear {
            atualizarEntradasFiltradas()
        }
        .onChange(of: busca) { _, _ in
            agendarBuscaIndice()
        }
        .onChange(of: entradas) { _, _ in
            atualizarEntradasFiltradas()
        }
        .onDisappear {
            buscaTask?.cancel()
            buscaTask = nil
        }
    }

    private func agendarBuscaIndice() {
        buscaTask?.cancel()
        buscaTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard Task.isCancelled == false else {
                return
            }

            atualizarEntradasFiltradas()
        }
    }

    private func atualizarEntradasFiltradas() {
        entradasFiltradas = Self.filtrarEntradas(entradas, busca: busca)
    }

    private static func filtrarEntradas(
        _ entradas: [IndiceRemissivoEntry],
        busca: String
    ) -> [IndiceRemissivoEntry] {
        let termo = busca.trimmingCharacters(in: .whitespacesAndNewlines)

        guard termo.isEmpty == false else {
            return entradas
        }

        return entradas.filter { entrada in
            entrada.termo.localizedCaseInsensitiveContains(termo)
            || entrada.paginasFormatadas.localizedCaseInsensitiveContains(termo)
            || entrada.datasBusca.localizedCaseInsensitiveContains(termo)
        }
    }
}

struct EditarTextoDiarioView: View {

    let item: BreviarioItem
    let salvar: (BreviarioTextEdit) -> Void
    let restaurarOriginal: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var titulo: String
    @State private var frase: String
    @State private var texto: String
    @State private var rodape: String
    @State private var autor: String

    init(
        item: BreviarioItem,
        salvar: @escaping (BreviarioTextEdit) -> Void,
        restaurarOriginal: @escaping () -> Void
    ) {
        self.item = item
        self.salvar = salvar
        self.restaurarOriginal = restaurarOriginal
        _titulo = State(initialValue: item.titulo)
        _frase = State(initialValue: item.frase)
        _texto = State(initialValue: item.texto)
        _rodape = State(initialValue: item.rodape ?? "")
        _autor = State(initialValue: item.autorDocumental ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identificação") {
                    Text(item.data)
                    TextField("Título", text: $titulo, axis: .vertical)
                    TextField("Frase", text: $frase, axis: .vertical)
                    TextField("Autor", text: $autor)
                }

                Section("Texto diário") {
                    TextEditor(text: $texto)
                        .frame(minHeight: 300)
                        .font(.body)
                }

                Section("Rodapé") {
                    TextEditor(text: $rodape)
                        .frame(minHeight: 120)
                }

                Section {
                    Button("Restaurar texto original importado", role: .destructive) {
                        restaurarOriginal()
                    }
                }
            }
            .navigationTitle("Editar texto")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        salvar(
                            BreviarioTextEdit(
                                titulo: titulo.trimmingCharacters(in: .whitespacesAndNewlines),
                                frase: frase.trimmingCharacters(in: .whitespacesAndNewlines),
                                texto: texto.trimmingCharacters(in: .whitespacesAndNewlines),
                                rodape: rodape.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                                autor: autor.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                            )
                        )
                    }
                }
            }
        }
    }
}
