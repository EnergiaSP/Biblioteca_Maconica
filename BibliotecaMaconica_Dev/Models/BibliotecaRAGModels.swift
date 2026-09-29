import Foundation

struct BibliotecaRAGObra: Codable, Identifiable, Hashable {
    let id: String
    let area: BibliotecaArea
    let tipo: BibliotecaObraTipo
    let titulo: String
    let autor: String?
    let origem: String?
    let edicao: String?
    let assuntos: [String]
    let dataImportacao: Date
}

struct BibliotecaRAGPagina: Codable, Identifiable, Hashable {
    let id: String
    let obraID: String
    let numeroOriginal: Int
    let titulo: String?
    let textoIntegral: String
    let largura: Double
    let altura: Double

    init(
        obraID: String,
        numeroOriginal: Int,
        titulo: String?,
        textoIntegral: String,
        largura: Double,
        altura: Double
    ) {
        self.id = "\(obraID)-pagina-\(numeroOriginal)"
        self.obraID = obraID
        self.numeroOriginal = numeroOriginal
        self.titulo = titulo
        self.textoIntegral = textoIntegral
        self.largura = largura
        self.altura = altura
    }
}

struct BibliotecaRAGParagrafo: Codable, Identifiable, Hashable {
    let id: String
    let obraID: String
    let pagina: Int
    let ordem: Int
    let texto: String
    let capitulo: String?
    let secao: String?
    let temas: [String]
    let palavrasChave: [String]

    init(
        obraID: String,
        pagina: Int,
        ordem: Int,
        texto: String,
        capitulo: String?,
        secao: String?,
        temas: [String],
        palavrasChave: [String]
    ) {
        self.id = "\(obraID)-p\(pagina)-b\(ordem)"
        self.obraID = obraID
        self.pagina = pagina
        self.ordem = ordem
        self.texto = texto
        self.capitulo = capitulo
        self.secao = secao
        self.temas = temas
        self.palavrasChave = palavrasChave
    }
}

struct BibliotecaRAGNotaRodape: Codable, Identifiable, Hashable {
    let id: String
    let obraID: String
    let pagina: Int
    let numero: String
    let texto: String

    init(obraID: String, pagina: Int, numero: String, texto: String, ordem: Int = 1) {
        self.id = "\(obraID)-p\(pagina)-nota-\(numero)-\(ordem)"
        self.obraID = obraID
        self.pagina = pagina
        self.numero = numero
        self.texto = texto
    }
}

struct BibliotecaRAGImagem: Codable, Identifiable, Hashable {
    let id: String
    let obraID: String
    let pagina: Int
    let caminhoRelativo: String
    let largura: Double
    let altura: Double
    let descricaoOCR: String?
}

struct BibliotecaRAGResultadoBusca: Identifiable, Hashable {
    let id: String
    let obraID: String
    let tituloObra: String
    let area: BibliotecaArea
    let pagina: Int
    let blocoID: String
    let trecho: String
    let ranking: Double

    func comRanking(_ novo: Double) -> Self {
        .init(id: id, obraID: obraID, tituloObra: tituloObra, area: area, pagina: pagina, blocoID: blocoID, trecho: trecho, ranking: novo)
    }

    func comTrecho(_ novo: String) -> Self {
        .init(id: id, obraID: obraID, tituloObra: tituloObra, area: area, pagina: pagina, blocoID: blocoID, trecho: novo, ranking: ranking)
    }
}

struct BibliotecaRAGCatalogo: Codable {
    let versaoFormato: Int
    let estrategia: String
    let geradoEm: String
    let origem: String?
    let baseURL: String?
    let pacotes: [BibliotecaRAGPacote]
    let totais: BibliotecaRAGCatalogoTotais
}

struct BibliotecaRAGCatalogoTotais: Codable {
    let pacotes: Int
    let obras: Int
    let paginas: Int
    let paragrafos: Int
    let notas: Int
    let blocosFTS: Int
    let tamanhoBytes: Int
}

struct BibliotecaRAGPacote: Codable, Identifiable, Hashable {
    let area: BibliotecaArea
    let titulo: String
    let arquivo: String
    let url: String?
    let sha256: String?
    let nivel: String?
    let tamanhoBytes: Int
    let estatisticas: BibliotecaRAGPacoteEstatisticas
    let obras: [BibliotecaRAGPacoteObra]

    var id: String { arquivo }

    var obraIDs: Set<String> {
        Set(obras.map(\.id))
    }
}

struct BibliotecaRAGPacoteEstatisticas: Codable, Hashable {
    let obras: Int
    let paginas: Int
    let paragrafos: Int
    let notas: Int
    let imagens: Int
    let blocosFTS: Int
}

struct BibliotecaRAGPacoteObra: Codable, Identifiable, Hashable {
    let id: String
    let titulo: String
    let autor: String?
    let tipo: BibliotecaObraTipo
    let paginas: Int
    let paragrafos: Int
    let notas: Int
    let assuntos: [String]
    /// Work with the same content (the same book imported twice), marked by Tools/marcar_duplicatas_catalogo.py.
    var duplicataDe: String? = nil
    /// Pages rated for OCR noise by Tools/avaliar_qualidade_acervo.py (qualidade_texto_v1.json).
    var qualidadeTexto: QualidadeTextoObra? = nil
}

/// Rated, noisy and unreadable pages of a work, as recorded in the catalog.
struct QualidadeTextoObra: Codable, Hashable {
    let avaliadas: Int
    let ruidosas: Int
    let ilegiveis: Int
}

struct BibliotecaRAGContextoIA: Codable {
    let pergunta: String
    let trechos: [BibliotecaRAGParagrafo]
    let notas: [BibliotecaRAGNotaRodape]
    let fontesOficiais: [FonteOficialMaconica]

    var possuiBaseDocumentalSuficiente: Bool {
        // A registered URL alone is not retrieved documentary evidence.
        trechos.contains { !$0.texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || notas.contains { !$0.texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

enum BibliotecaRAGPoliticaIA {
    static let instrucaoRestritiva = """
    Responda somente com base nos trechos documentais recuperados da biblioteca e nas fontes oficiais previamente aprovadas. Nao invente fatos, referencias, citacoes, paginas, autores ou conclusoes. Quando a base recuperada nao for suficiente, informe claramente que nao encontrou fundamento documental seguro para responder.
    """
}
