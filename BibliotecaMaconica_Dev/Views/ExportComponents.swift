import SwiftUI
import UIKit

struct ExportacaoMultiplaView: View {
    let itens: [BreviarioItem]
    let tema: TemaLeitura
    let exportar: ([BreviarioItem], Bool, FormatoExportacaoMultipla) -> Void
    private let localePortugues = Locale(identifier: "pt_BR")

    @Environment(\.dismiss) private var dismiss
    @State private var selecionados: Set<Int> = []
    @State private var inicio = Date()
    @State private var fim = Date()
    @State private var incluirComentarios = false
    @State private var formato = FormatoExportacaoMultipla.pdf
    @State private var busca = ""
    @State private var mensagemSelecao: String?
    @State private var itensFiltradosCache: [BreviarioItem] = []
    @State private var idsSemanaAtualCache: Set<Int> = []
    @State private var idsMesAtualCache: Set<Int> = []
    @State private var idsIntervaloCache: Set<Int> = []
    @State private var buscaTask: Task<Void, Never>?

    private var itensFiltrados: [BreviarioItem] {
        itensFiltradosCache
    }

    private var itensSelecionados: [BreviarioItem] {
        itens.filter { selecionados.contains($0.id) }
    }

    private var idsSemanaAtual: Set<Int> {
        idsSemanaAtualCache
    }

    private var idsMesAtual: Set<Int> {
        idsMesAtualCache
    }

    private var todosSelecionados: Bool {
        selecionados.count == itens.count && itens.isEmpty == false
    }

    var body: some View {
        NavigationStack {
            List {
                if let mensagemSelecao {
                    Section {
                        Label(mensagemSelecao, systemImage: "checkmark.seal.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(tema.sucesso)
                            .accessibilityLabel(mensagemSelecao)
                    }
                    .listRowBackground(tema.painel)
                }

                Section("Intervalo sequencial") {
                    DatePicker("Início", selection: $inicio, displayedComponents: [.date])
                        .environment(\.locale, localePortugues)
                    DatePicker("Fim", selection: $fim, displayedComponents: [.date])
                        .environment(\.locale, localePortugues)

                    Button {
                        selecionarIntervalo()
                    } label: {
                        acaoSelecaoRapida(
                            titulo: "Selecionar intervalo",
                            detalhe: "Do início ao fim escolhidos",
                            icone: "calendar.badge.plus",
                            quantidade: quantidadeIntervaloSelecionavel(),
                            completo: intervaloEstaSelecionado()
                        )
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(tema.painel)

                Section("Seleções rápidas") {
                    Button {
                        selecionarSemanaAtual()
                    } label: {
                        acaoSelecaoRapida(
                            titulo: "Selecionar semana atual",
                            detalhe: "Inclui todos os dias desta semana",
                            icone: "calendar.badge.checkmark",
                            quantidade: idsSemanaAtual.count,
                            completo: contemTodos(idsSemanaAtual)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        selecionarMesAtual()
                    } label: {
                        acaoSelecaoRapida(
                            titulo: "Selecionar mês atual",
                            detalhe: "Inclui todos os textos do mês",
                            icone: "calendar",
                            quantidade: idsMesAtual.count,
                            completo: contemTodos(idsMesAtual)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        selecionarTodos()
                    } label: {
                        acaoSelecaoRapida(
                            titulo: "Selecionar todos os dias",
                            detalhe: "Exportação completa do ano",
                            icone: "checkmark.circle",
                            quantidade: itens.count,
                            completo: todosSelecionados
                        )
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(tema.painel)

                Section("Opções") {
                    Picker("Formato", selection: $formato) {
                        ForEach(FormatoExportacaoMultipla.allCases) { formato in
                            Label(formato.titulo, systemImage: formato.icone)
                                .tag(formato)
                        }
                    }

                    Toggle("Incluir comentários salvos", isOn: $incluirComentarios)

                    HStack {
                        Label("\(itensSelecionados.count) dias selecionados", systemImage: "checklist")
                            .foregroundStyle(tema.textoSecundario)

                        Spacer()

                        Button("Limpar") {
                            selecionados.removeAll()
                            mensagemSelecao = "Seleção limpa."
                        }
                        .disabled(selecionados.isEmpty)
                    }
                }
                .listRowBackground(tema.painel)

                Section("Dias alternados ou manuais") {
                    ForEach(itensFiltrados) { item in
                        Button {
                            alternar(item)
                        } label: {
                            let selecionado = selecionados.contains(item.id)
                            HStack(spacing: 12) {
                                Image(systemName: selecionado ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selecionado ? .green : tema.textoSecundario)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(item.data) - \(item.titulo)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(tema.textoPrincipal)

                                    Text(item.resumo)
                                        .font(.caption)
                                        .foregroundStyle(tema.textoSecundario)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 8)

                                if selecionado {
                                    Text("Selecionado")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(tema.textoPrincipal)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(selecionado ? tema.sucesso.opacity(0.12) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selecionado ? tema.sucesso.opacity(0.38) : Color.clear, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(tema.painel)
            }
            .navigationTitle("Exportar dias")
            .searchable(text: $busca, prompt: "Buscar dia, título ou texto")
            .environment(\.locale, localePortugues)
            .scrollContentBackground(.hidden)
            .background(tema.background)
            .foregroundStyle(tema.textoPrincipal)
            .tint(tema.destaque)
            .preferredColorScheme(tema.preferredColorScheme)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Exportar") {
                        exportar(itensSelecionados, incluirComentarios, formato)
                    }
                    .disabled(selecionados.isEmpty)
                }
            }
            .onAppear {
                atualizarCachesExportacao()
            }
            .onChange(of: busca) { _, _ in
                agendarBuscaExportacao()
            }
            .onChange(of: inicio) { _, _ in
                atualizarIntervaloExportacaoCache()
            }
            .onChange(of: fim) { _, _ in
                atualizarIntervaloExportacaoCache()
            }
            .onDisappear {
                buscaTask?.cancel()
                buscaTask = nil
            }
        }
    }

    private func atualizarCachesExportacao() {
        itensFiltradosCache = Self.filtrarItensExportacao(itens, busca: busca)
        idsSemanaAtualCache = idsParaDatas(datasSemanaAtual())
        idsMesAtualCache = montarIDsMesAtual()
        atualizarIntervaloExportacaoCache()
    }

    private func atualizarIntervaloExportacaoCache() {
        idsIntervaloCache = idsParaDatas(datasIntervaloSelecionado())
    }

    private func agendarBuscaExportacao() {
        buscaTask?.cancel()
        buscaTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard Task.isCancelled == false else {
                return
            }

            itensFiltradosCache = Self.filtrarItensExportacao(itens, busca: busca)
        }
    }

    private static func filtrarItensExportacao(_ itens: [BreviarioItem], busca: String) -> [BreviarioItem] {
        let termo = busca.trimmingCharacters(in: .whitespacesAndNewlines)
        guard termo.isEmpty == false else {
            return itens
        }

        return itens.filter { item in
            item.data.localizedCaseInsensitiveContains(termo)
            || item.titulo.localizedCaseInsensitiveContains(termo)
            || item.texto.localizedCaseInsensitiveContains(termo)
        }
    }

    private func alternar(_ item: BreviarioItem) {
        if selecionados.contains(item.id) {
            selecionados.remove(item.id)
            mensagemSelecao = "\(item.data) removido da seleção."
        } else {
            selecionados.insert(item.id)
            mensagemSelecao = "\(item.data) selecionado para exportação."
        }
    }

    private func acaoSelecaoRapida(
        titulo: String,
        detalhe: String,
        icone: String,
        quantidade: Int,
        completo: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: completo ? "checkmark.circle.fill" : icone)
                .font(.title3)
                .foregroundStyle(completo ? tema.sucesso : tema.destaque)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(tema.textoPrincipal)

                Text("\(detalhe) - \(quantidade) dias")
                    .font(.caption)
                    .foregroundStyle(tema.textoSecundario)
            }

            Spacer()

            if completo {
                Text("Selecionado")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(tema.textoPrincipal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tema.sucesso.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(completo ? tema.sucesso.opacity(0.10) : tema.painel)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(completo ? tema.sucesso.opacity(0.38) : tema.destaque.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func selecionarIntervalo() {
        let ids = idsIntervaloCache
        selecionados.formUnion(ids)
        mensagemSelecao = "Intervalo selecionado: \(ids.count) dias adicionados."
    }

    private func selecionarSemanaAtual() {
        selecionados.formUnion(idsSemanaAtual)
        mensagemSelecao = "Semana atual selecionada: \(idsSemanaAtual.count) dias adicionados."
    }

    private func selecionarMesAtual() {
        selecionados.formUnion(idsMesAtual)
        mensagemSelecao = "Mês atual selecionado: \(idsMesAtual.count) dias adicionados."
    }

    private func selecionarTodos() {
        selecionados = Set(itens.map(\.id))
        mensagemSelecao = "Todos os \(selecionados.count) dias foram selecionados."
    }

    private func contemTodos(_ ids: Set<Int>) -> Bool {
        ids.isEmpty == false && ids.isSubset(of: selecionados)
    }

    private func idsParaDatas(_ datas: Set<String>) -> Set<Int> {
        Set(itens.filter { datas.contains($0.data) }.map(\.id))
    }

    private func montarIDsMesAtual() -> Set<Int> {
        let mesAtual = Calendar.current.component(.month, from: Date())
        return Set(itens.filter { mesDaData($0.data) == mesAtual }.map(\.id))
    }

    private func intervaloEstaSelecionado() -> Bool {
        contemTodos(idsIntervaloCache)
    }

    private func quantidadeIntervaloSelecionavel() -> Int {
        idsIntervaloCache.count
    }

    private func datasIntervaloSelecionado() -> Set<String> {
        datasEntre(inicio, fim)
    }

    private func datasSemanaAtual() -> Set<String> {
        var calendario = Calendar(identifier: .gregorian)
        calendario.firstWeekday = 1
        guard let intervalo = calendario.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }

        return datasEntre(intervalo.start, calendario.date(byAdding: .day, value: -1, to: intervalo.end) ?? intervalo.end)
    }

    private func datasEntre(_ primeira: Date, _ segunda: Date) -> Set<String> {
        let calendario = Calendar.current
        let dataInicial = min(primeira, segunda)
        let dataFinal = max(primeira, segunda)
        let formatter = DateFormatter()
        formatter.locale = localePortugues
        formatter.dateFormat = "dd/MM"

        var datas: Set<String> = []
        var dataAtual = calendario.startOfDay(for: dataInicial)
        let limite = calendario.startOfDay(for: dataFinal)

        while dataAtual <= limite {
            datas.insert(formatter.string(from: dataAtual))
            guard let proxima = calendario.date(byAdding: .day, value: 1, to: dataAtual) else {
                break
            }
            dataAtual = proxima
        }

        return datas
    }

    private func mesDaData(_ data: String) -> Int? {
        let componentes = data.split(separator: "/")
        guard componentes.count == 2 else {
            return nil
        }

        return Int(componentes[1])
    }
}

struct FonteOficialCard: View {
    let fonte: FonteOficialMaconica
    let tema: TemaLeitura
    let abrir: () -> Void
    let remover: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(tema.destaque)

                VStack(alignment: .leading, spacing: 4) {
                    Text(fonte.titulo)
                        .font(.headline)
                        .foregroundStyle(tema.textoPrincipal)

                    Text(fonte.origem)
                        .font(.subheadline)
                        .foregroundStyle(tema.textoSecundario)
                }

                Spacer()

                Button(action: remover) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityLabel("Remover fonte oficial")
            }

            if fonte.observacao.isEmpty == false {
                Text(fonte.observacao)
                    .font(.callout)
                    .foregroundStyle(tema.textoSecundario)
                    .lineLimit(3)
            }

            if fonte.url.isEmpty == false {
                Button(action: abrir) {
                    Label(fonte.url, systemImage: "link")
                        .lineLimit(1)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(tema.destaque)
            }
        }
        .padding()
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SolicitacaoObraCard: View {
    let solicitacao: SolicitacaoInclusaoObra
    let tema: TemaLeitura

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(solicitacao.area.titulo)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(tema.destaque)

                Spacer()

                Text(solicitacao.status.titulo)
                    .font(.caption)
                    .foregroundStyle(tema.textoSecundario)
            }

            Text(solicitacao.titulo)
                .font(.headline)
                .foregroundStyle(tema.textoPrincipal)

            if solicitacao.autor.isEmpty == false {
                Text(solicitacao.autor)
                    .font(.subheadline)
                    .foregroundStyle(tema.textoSecundario)
            }

            if solicitacao.observacao.isEmpty == false {
                Text(solicitacao.observacao)
                    .font(.caption)
                    .foregroundStyle(tema.textoSecundario)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(tema.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ConfigurarNotificacaoView: View {

    @Binding var ativa: Bool
    @Binding var hora: Int
    @Binding var minuto: Int
    let obras: [BibliotecaObra]
    @Binding var obrasSelecionadas: Set<String>
    let carregarItens: (Set<String>) async -> [BreviarioItem]
    let informarResultado: (String) -> Void
    private let localePortugues = Locale(identifier: "pt_BR")

    @Environment(\.dismiss) private var dismiss
    @State private var horario: Date
    @State private var mensagemResultado: String?

    init(
        ativa: Binding<Bool>,
        hora: Binding<Int>,
        minuto: Binding<Int>,
        obras: [BibliotecaObra],
        obrasSelecionadas: Binding<Set<String>>,
        carregarItens: @escaping (Set<String>) async -> [BreviarioItem],
        informarResultado: @escaping (String) -> Void
    ) {
        _ativa = ativa
        _hora = hora
        _minuto = minuto
        self.obras = obras
        _obrasSelecionadas = obrasSelecionadas
        self.carregarItens = carregarItens
        self.informarResultado = informarResultado

        var componentes = DateComponents()
        componentes.hour = hora.wrappedValue
        componentes.minute = minuto.wrappedValue
        _horario = State(initialValue: Calendar.current.date(from: componentes) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Notificação diária") {
                    Toggle("Ativar", isOn: $ativa)

                    DatePicker(
                        "Horário",
                        selection: $horario,
                        displayedComponents: [.hourAndMinute]
                    )
                    .environment(\.locale, localePortugues)
                }

                Section("Breviários incluídos") {
                    ForEach(obras) { obra in
                        Toggle(obra.titulo, isOn: bindingObra(obra.id))
                    }
                }

                Section {
                    Button("Salvar configuração") {
                        salvar()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Enviar teste em 5 segundos") {
                        testar()
                    }
                    .buttonStyle(.bordered)

                    Button("Cancelar notificação", role: .destructive) {
                        ativa = false
                        NotificationService.cancelarNotificacaoDiaria()
                        informarResultadoLocal("Notificação diária cancelada.")
                        dismiss()
                    }
                }

                if let mensagemResultado {
                    Section {
                        Label(mensagemResultado, systemImage: iconeResultado(mensagemResultado))
                            .font(.caption)
                            .foregroundStyle(corResultado(mensagemResultado))
                    }
                }
            }
            .navigationTitle("Notificação")
            .environment(\.locale, localePortugues)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func salvar() {
        let componentes = Calendar.current.dateComponents([.hour, .minute], from: horario)
        hora = componentes.hour ?? 8
        minuto = componentes.minute ?? 0

        guard ativa else {
            NotificationService.cancelarNotificacaoDiaria()
            informarResultadoLocal("Notificação diária desativada.")
            dismiss()
            return
        }

        guard obrasSelecionadas.isEmpty == false else {
            informarResultadoLocal("Selecione pelo menos um breviário para notificar.")
            return
        }

        Task {
            let itens = await carregarItens(obrasSelecionadas)

            await MainActor.run {
                guard itens.isEmpty == false else {
                    informarResultadoLocal("Nenhum texto diário encontrado para notificar.")
                    return
                }

                NotificationService.agendarNotificacaoDiaria(
                    hora: hora,
                    minuto: minuto,
                    itens: itens
                ) { sucesso in
                    DispatchQueue.main.async {
                        informarResultadoLocal(
                            sucesso
                                ? "Notificação diária agendada."
                                : "Permissão de notificação não concedida."
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private func testar() {
        Task {
            let itens = await carregarItens(obrasSelecionadas)

            await MainActor.run {
                guard let item = itens.first(where: { $0.data == dataAtual }) ?? itens.first else {
                    informarResultadoLocal("Nenhum texto diário encontrado para testar.")
                    return
                }

                NotificationService.agendarTeste(item: item) { sucesso in
                    DispatchQueue.main.async {
                        informarResultadoLocal(
                            sucesso
                                ? "Teste agendado para daqui a 5 segundos."
                                : "Permissão de notificação não concedida."
                        )
                    }
                }
            }
        }
    }

    private func bindingObra(_ obraID: String) -> Binding<Bool> {
        Binding {
            obrasSelecionadas.contains(obraID)
        } set: { selecionado in
            if selecionado {
                obrasSelecionadas.insert(obraID)
            } else {
                obrasSelecionadas.remove(obraID)
            }
        }
    }

    private func informarResultadoLocal(_ mensagem: String) {
        mensagemResultado = mensagem
        informarResultado(mensagem)
    }

    private func iconeResultado(_ mensagem: String) -> String {
        if mensagem.localizedCaseInsensitiveContains("não")
            || mensagem.localizedCaseInsensitiveContains("nenhum") {
            return "exclamationmark.triangle"
        }

        return "checkmark.circle.fill"
    }

    private func corResultado(_ mensagem: String) -> Color {
        if mensagem.localizedCaseInsensitiveContains("não")
            || mensagem.localizedCaseInsensitiveContains("nenhum") {
            return .orange
        }

        return .green
    }

    private var dataAtual: String {
        let formatter = DateFormatter()
        formatter.locale = localePortugues
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: Date())
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
