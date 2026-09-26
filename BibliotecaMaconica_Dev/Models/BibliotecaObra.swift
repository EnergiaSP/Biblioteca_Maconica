import Foundation

enum BibliotecaArea: String, Codable, CaseIterable, Identifiable {
    case breviarios
    case dicionariosMaconicos
    case judiciarioMaconico
    case bibliotecaMaconica

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .breviarios:
            "Breviários"
        case .dicionariosMaconicos:
            "Dicionários Maçônicos"
        case .judiciarioMaconico:
            "Judiciário Maçônico"
        case .bibliotecaMaconica:
            "Biblioteca Maçônica"
        }
    }

    var subtitulo: String {
        switch self {
        case .breviarios:
            "Leituras diárias com notificações, comentários, favoritos e exportações."
        case .dicionariosMaconicos:
            "Consulta por verbetes, termos, símbolos, conceitos e referências."
        case .judiciarioMaconico:
            "Obras, normas, estudos e materiais de organização jurídica maçônica."
        case .bibliotecaMaconica:
            "Livros maçônicos organizados por obra, assunto, autor, índice e estudo."
        }
    }

    var icone: String {
        switch self {
        case .breviarios:
            "calendar.badge.clock"
        case .dicionariosMaconicos:
            "text.book.closed"
        case .judiciarioMaconico:
            "scale.3d"
        case .bibliotecaMaconica:
            "books.vertical"
        }
    }
}

enum BibliotecaObraTipo: String, Codable, CaseIterable, Identifiable {
    case breviarioDiario
    case dicionario
    case judiciario
    case livro
    case apostila
    case artigo

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .breviarioDiario:
            "Breviário diário"
        case .dicionario:
            "Dicionário"
        case .judiciario:
            "Judiciário"
        case .livro:
            "Livro"
        case .apostila:
            "Apostila"
        case .artigo:
            "Artigo"
        }
    }

    var tituloLista: String {
        switch self {
        case .breviarioDiario:
            "Textos"
        case .dicionario:
            "Verbetes"
        case .judiciario:
            "Normas e seções"
        case .livro:
            "Capítulos e páginas"
        case .apostila:
            "Aulas e páginas"
        case .artigo:
            "Seções"
        }
    }

    var referenciaSingular: String {
        switch self {
        case .breviarioDiario:
            "Leitura"
        case .dicionario:
            "Verbete"
        case .judiciario:
            "Seção"
        case .livro:
            "Página"
        case .apostila:
            "Aula"
        case .artigo:
            "Seção"
        }
    }
}

struct BibliotecaFiltroMetadados: Equatable, Sendable {
    var autor = ""
    var assunto = ""

    var descricao: String {
        [("Autor", autor), ("Assunto", assunto)].compactMap { rotulo, valor in
            let limpo = valor.trimmingCharacters(in: .whitespacesAndNewlines)
            return limpo.isEmpty ? nil : "\(rotulo): \(limpo)"
        }.joined(separator: " • ")
    }

    func corresponde(_ obra: BibliotecaObra) -> Bool {
        (autor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || BibliotecaSQLiteService.corresponde(termo: autor, texto: obra.autor ?? ""))
        && (assunto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || BibliotecaSQLiteService.corresponde(termo: assunto, texto: obra.assuntos.joined(separator: " ")))
    }
}

struct BibliotecaObra: Codable, Identifiable, Equatable {
    let id: String
    let titulo: String
    let autor: String?
    let area: BibliotecaArea
    let tipo: BibliotecaObraTipo
    let recursoJSON: String?
    let descricao: String
    let assuntos: [String]
    let ativa: Bool

    static let breviarioSeculoXXI = BibliotecaObra(
        id: ObraID.breviarioSeculoXXI,
        titulo: "Breviário Maçônico - Kennyo Ismail",
        autor: "Kennyo Ismail",
        area: .breviarios,
        tipo: .breviarioDiario,
        recursoJSON: "breviario",
        descricao: "Leituras diárias, índice remissivo, comentários, favoritos, notificações e exportação.",
        assuntos: ["Leitura diária", "Reflexão", "Ética", "Filosofia", "Ritualística"],
        ativa: true
    )

    static let breviarioRizzardo = BibliotecaObra(
        id: ObraID.breviarioRizzardo,
        titulo: "Breviário Maçônico - Rizzardo da Camino",
        autor: "Rizzardo da Camino",
        area: .breviarios,
        tipo: .breviarioDiario,
        recursoJSON: "breviario_rizzardo",
        descricao: "365 leituras diárias permanentes, organizadas por data, tema e índice remissivo.",
        assuntos: ["Leitura diária", "Simbolismo", "Filosofia", "Ritualística", "Espiritualidade"],
        ativa: true
    )

    static let dicionarioMaconicoI = BibliotecaObra(
        id: ObraID.dicionarioMaconicoI,
        titulo: "Dicionário Maçônico I",
        autor: nil,
        area: .dicionariosMaconicos,
        tipo: .dicionario,
        recursoJSON: nil,
        descricao: "Campo reservado para o primeiro dicionário maçônico da biblioteca.",
        assuntos: ["Verbetes", "Símbolos", "Conceitos", "Ritos"],
        ativa: true
    )

    static let dicionarioMaconicoII = BibliotecaObra(
        id: ObraID.dicionarioMaconicoII,
        titulo: "Dicionário Maçônico II",
        autor: nil,
        area: .dicionariosMaconicos,
        tipo: .dicionario,
        recursoJSON: nil,
        descricao: "Campo reservado para o segundo dicionário maçônico da biblioteca.",
        assuntos: ["Verbetes", "História", "Terminologia", "Doutrina"],
        ativa: true
    )

    static let judiciarioBase = BibliotecaObra(
        id: ObraID.judiciarioBase,
        titulo: "Judiciário Maçônico",
        autor: nil,
        area: .judiciarioMaconico,
        tipo: .judiciario,
        recursoJSON: nil,
        descricao: "Área preparada para obras, normas, estudos e materiais de judiciário maçônico.",
        assuntos: ["Normas", "Processo", "Jurisprudência", "Organização"],
        ativa: true
    )

    static let bibliotecaGeral = BibliotecaObra(
        id: ObraID.bibliotecaGeral,
        titulo: "Livros Maçônicos",
        autor: nil,
        area: .bibliotecaMaconica,
        tipo: .livro,
        recursoJSON: nil,
        descricao: "Área para inclusão de livros maçônicos de diferentes títulos, autores e origens.",
        assuntos: ["História", "Filosofia", "Ritualística", "Simbologia", "Ética"],
        ativa: true
    )

    static let padroes: [BibliotecaObra] = [
        .breviarioSeculoXXI,
        .breviarioRizzardo,
        .dicionarioMaconicoI,
        .dicionarioMaconicoII,
        .judiciarioBase,
        .bibliotecaGeral
    ]
}

enum ObraID {
    static let breviarioSeculoXXI = "breviario_seculo_xxi"
    static let breviarioRizzardo = "breviario_rizzardo_da_camino"
    static let dicionarioMaconicoI = "dicionario_maconico_i"
    static let dicionarioMaconicoII = "dicionario_maconico_ii"
    static let judiciarioBase = "judiciario_maconico"
    static let bibliotecaGeral = "biblioteca_maconica_livros"
}

enum BibliotecaBuscaEscopo: String, CaseIterable, Identifiable {
    case appTodo
    case area
    case obraAtual

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .appTodo:
            "Todas as obras"
        case .area:
            "Área"
        case .obraAtual:
            "Obra atual"
        }
    }
}

struct BibliotecaResultadoBusca: Identifiable {
    let obra: BibliotecaObra
    let item: BreviarioItem
    let contexto: String
    var ranking: Double = 0
    var blocoID: String? = nil

    var id: String {
        "\(obra.id)-\(blocoID ?? String(item.id))-\(item.data)"
    }
}

struct BibliotecaIndiceObra: Identifiable {
    let obra: BibliotecaObra
    let totalItens: Int
    let totalIndiceRemissivo: Int
    let primeirosTitulos: [String]

    var id: String { obra.id }
}

struct BibliotecaIndiceArea: Identifiable {
    let area: BibliotecaArea
    let obras: [BibliotecaIndiceObra]

    var id: String { area.id }

    var totalItens: Int {
        obras.reduce(0) { $0 + $1.totalItens }
    }

    var totalIndiceRemissivo: Int {
        obras.reduce(0) { $0 + $1.totalIndiceRemissivo }
    }
}

struct BibliotecaIndiceRemissivoGlobal: Identifiable {
    let termo: String
    let ocorrencias: [BibliotecaResultadoBusca]

    var id: String { termo }
}

struct BibliotecaDossieEstudo: Identifiable {
    let termo: String
    let escopo: BibliotecaBuscaEscopo
    let area: BibliotecaArea?
    let resultados: [BibliotecaResultadoBusca]
    let termosRelacionados: [String]
    let obrasEnvolvidas: [BibliotecaObra]
    let roteiro: [String]
    let perguntasFixacao: [String]
    let mapaConceitual: [String]
    let revisaoEspacada: [String]
    let cruzamentos: [String]
    let limitesDaBase: [String]
    var filtroMetadados: BibliotecaFiltroMetadados = .init()

    var id: String {
        [
            termo,
            escopo.rawValue,
            area?.rawValue ?? "todas",
            filtroMetadados.autor,
            filtroMetadados.assunto
        ].joined(separator: "-")
    }

    var resumoEscopo: String {
        let base = switch escopo {
        case .appTodo:
            "Toda a biblioteca"
        case .area:
            area?.titulo ?? "Área selecionada"
        case .obraAtual:
            "Obra atual"
        }
        return [base, filtroMetadados.descricao].filter { !$0.isEmpty }.joined(separator: " • ")
    }
}

struct ExportacaoEstudoAvancado {
    let titulo: String
    let secoes: [(titulo: String, itens: [String])]

    var textoCompartilhavel: String {
        var partes = [titulo]

        for secao in secoes where secao.itens.isEmpty == false {
            partes.append(
                "\(secao.titulo):\n" + secao.itens
                    .map { "- \($0)" }
                    .joined(separator: "\n")
            )
        }

        return partes.joined(separator: "\n\n")
    }
}

struct SolicitacaoInclusaoObra: Codable {
    let area: BibliotecaArea
    let titulo: String
    let autor: String
    let observacao: String
    let dataCriacao: Date
    let status: StatusSolicitacaoObra

    init(
        area: BibliotecaArea,
        titulo: String,
        autor: String,
        observacao: String,
        dataCriacao: Date,
        status: StatusSolicitacaoObra = .pendente
    ) {
        self.area = area
        self.titulo = titulo
        self.autor = autor
        self.observacao = observacao
        self.dataCriacao = dataCriacao
        self.status = status
    }
}

enum StatusSolicitacaoObra: String, Codable, CaseIterable, Identifiable {
    case pendente
    case aprovada
    case importada

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .pendente:
            "Pendente"
        case .aprovada:
            "Aprovada"
        case .importada:
            "Importada"
        }
    }
}

struct FonteOficialMaconica: Codable, Identifiable, Equatable {
    let id: UUID
    let titulo: String
    let origem: String
    let url: String
    let observacao: String
    let dataCriacao: Date

    init(
        id: UUID = UUID(),
        titulo: String,
        origem: String,
        url: String,
        observacao: String,
        dataCriacao: Date = Date()
    ) {
        self.id = id
        self.titulo = titulo
        self.origem = origem
        self.url = url
        self.observacao = observacao
        self.dataCriacao = dataCriacao
    }
}

struct BibliotecaItemID: Hashable, Codable {
    let obraID: String
    let itemID: Int
    let data: String

    var chavePersistencia: String {
        "\(obraID)_\(data)"
    }
}

struct BibliotecaData: Codable {
    let obras: [BibliotecaObra]
    let breviarios: [String: BreviarioData]
}
