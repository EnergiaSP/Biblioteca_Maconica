import Foundation

/// Portable study notebook: the same file on iOS and Android (export, import and the sync options).
/// Importing merges it into the local notebook without losing anything. Mirrors
/// `Tools/caderno_referencia.py`; `casos_caderno_v1.json` holds the golden cases both apps reproduce.
enum CadernoEstudo {
    struct Configuracao: Decodable {
        let schemaVersion: Int
        let formato: String
        let versao: Int
        let marcadorImportacao: String
        let rotulos: [String: String]
        let porTema: RegraPorTema

        static let compartilhada: Configuracao? = {
            guard let url = Bundle.main.url(forResource: "caderno_v1", withExtension: "json"),
                  let dados = try? Data(contentsOf: url),
                  let configuracao = try? JSONDecoder().decode(Configuracao.self, from: dados),
                  configuracao.schemaVersion == 1 else { return nil }
            return configuracao
        }()

        func rotulo(_ chave: String, _ valores: [String: String] = [:]) -> String {
            valores.reduce(rotulos[chave] ?? chave) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
        }
    }

    struct Destaque: Codable, Equatable {
        let id: String
        let texto: String
        /// Milliseconds since 1970.
        let criadoEm: Int64
    }

    struct Edicao: Codable, Equatable {
        var titulo = ""
        var frase = ""
        var texto = ""
        var rodape = ""
        var autor = ""
    }

    struct Leitura: Codable, Equatable {
        let obraId: String
        let data: String
        var comentario = ""
        var reflexao = ""
        var favorita = false
        var lida = false
        var destaques: [Destaque] = []
        var edicao: Edicao?

        var temConteudo: Bool {
            !comentario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !reflexao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || favorita || lida || !destaques.isEmpty || edicao != nil
        }
    }

    /// The AI interpretation saved with a dossier.
    struct Interpretacao: Codable, Equatable {
        let texto: String
        /// Milliseconds since 1970.
        let geradaEm: Int64
    }

    struct Dossie: Codable, Equatable {
        let id: String
        let tema: String
        let area: String?
        let obraId: String?
        let autor: String
        let assunto: String
        var criadoEm: String
        var revisoesConcluidas: [Int]
        var interpretacao: Interpretacao?

        var chave: String {
            [tema, area ?? "", obraId ?? "", autor, assunto]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .joined(separator: "|")
        }
    }

    struct Cartao: Codable, Equatable {
        let cartao: RevisaoAtiva.Cartao
        var dossieId: String
        let tema: String
        var criadoEm: String
        let estado: RevisaoAtiva.Estado
    }

    struct Caderno: Codable, Equatable {
        var formato: String
        var versao: Int
        var leituras: [Leitura] = []
        var dossies: [Dossie] = []
        var cartoes: [Cartao] = []
    }

    // MARK: - Regra comum

    static func vazio(_ configuracao: Configuracao) -> Caderno {
        Caderno(formato: configuracao.formato, versao: configuracao.versao)
    }

    static func valido(formato: String?, versao: Int?, configuracao: Configuracao) -> Bool {
        guard formato == configuracao.formato, let versao else { return false }
        return versao <= configuracao.versao
    }

    /// Stable order and no empty readings, so both apps write the same file.
    static func canonico(_ caderno: Caderno, _ configuracao: Configuracao) -> Caderno {
        var resultado = vazio(configuracao)
        resultado.leituras = caderno.leituras.compactMap { leitura in
            var copia = leitura
            copia.destaques.sort { ($0.criadoEm, $0.texto) < ($1.criadoEm, $1.texto) }
            return copia.temConteudo ? copia : nil
        }.sorted { ($0.obraId, $0.data) < ($1.obraId, $1.data) }
        resultado.dossies = caderno.dossies.map { dossie in
            var copia = dossie
            copia.revisoesConcluidas = Array(Set(dossie.revisoesConcluidas)).sorted()
            if copia.interpretacao?.texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true { copia.interpretacao = nil }
            return copia
        }.sorted { ($0.criadoEm, $0.tema, $0.id) < ($1.criadoEm, $1.tema, $1.id) }
        resultado.cartoes = caderno.cartoes.sorted { $0.cartao.id < $1.cartao.id }
        return resultado
    }

    static func mesclarTexto(_ local: String, _ importado: String, hoje: String, configuracao: Configuracao) -> String {
        let a = local.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = importado.trimmingCharacters(in: .whitespacesAndNewlines)
        if b.isEmpty || a == b || a.contains(b) { return a.isEmpty ? (b.isEmpty ? "" : importado) : local }
        if a.isEmpty || b.contains(a) { return importado }
        let partes = hoje.split(separator: "-").map(String.init)
        let dia = partes.count == 3 ? "\(partes[2])/\(partes[1])/\(partes[0])" : hoje
        return "\(a)\n\n\(configuracao.marcadorImportacao.replacingOccurrences(of: "{data}", with: dia))\n\(b)"
    }

    static func mesclar(local: Caderno, importado: Caderno, hoje: String, configuracao: Configuracao) -> Caderno {
        let local = canonico(local, configuracao)
        let importado = canonico(importado, configuracao)

        var leituras = Dictionary(local.leituras.map { ("\($0.obraId)\u{1F}\($0.data)", $0) }, uniquingKeysWith: { a, _ in a })
        for leitura in importado.leituras {
            let chave = "\(leitura.obraId)\u{1F}\(leitura.data)"
            guard var minha = leituras[chave] else {
                leituras[chave] = leitura
                continue
            }
            minha.comentario = mesclarTexto(minha.comentario, leitura.comentario, hoje: hoje, configuracao: configuracao)
            minha.reflexao = mesclarTexto(minha.reflexao, leitura.reflexao, hoje: hoje, configuracao: configuracao)
            minha.favorita = minha.favorita || leitura.favorita
            minha.lida = minha.lida || leitura.lida
            var textos = Set(minha.destaques.map { $0.texto.trimmingCharacters(in: .whitespacesAndNewlines) })
            for destaque in leitura.destaques where textos.insert(destaque.texto.trimmingCharacters(in: .whitespacesAndNewlines)).inserted {
                minha.destaques.append(destaque)
            }
            minha.edicao = minha.edicao ?? leitura.edicao
            leituras[chave] = minha
        }

        var dossies = Dictionary(local.dossies.map { ($0.chave, $0) }, uniquingKeysWith: { a, _ in a })
        var remapeados: [String: String] = [:]
        for dossie in importado.dossies {
            if var meu = dossies[dossie.chave] {
                remapeados[dossie.id] = meu.id
                meu.criadoEm = min(meu.criadoEm, dossie.criadoEm)
                meu.revisoesConcluidas = Array(Set(meu.revisoesConcluidas).union(dossie.revisoesConcluidas)).sorted()
                // The most recent interpretation is kept; on a tie, the local one.
                if let dela = dossie.interpretacao, dela.geradaEm > (meu.interpretacao?.geradaEm ?? Int64.min) {
                    meu.interpretacao = dela
                }
                dossies[dossie.chave] = meu
            } else {
                dossies[dossie.chave] = dossie
            }
        }

        var cartoes = Dictionary(local.cartoes.map { ($0.cartao.id, $0) }, uniquingKeysWith: { a, _ in a })
        for cartao in importado.cartoes {
            var entrada = cartao
            entrada.dossieId = remapeados[cartao.dossieId] ?? cartao.dossieId
            guard let meu = cartoes[cartao.cartao.id] else {
                cartoes[cartao.cartao.id] = entrada
                continue
            }
            let respostas = { (c: Cartao) in c.estado.acertos + c.estado.erros }
            var vencedor = respostas(entrada) > respostas(meu) ? entrada : meu
            vencedor.criadoEm = min(meu.criadoEm, entrada.criadoEm)
            cartoes[cartao.cartao.id] = vencedor
        }

        var resultado = vazio(configuracao)
        resultado.leituras = Array(leituras.values)
        resultado.dossies = Array(dossies.values)
        resultado.cartoes = Array(cartoes.values)
        return canonico(resultado, configuracao)
    }

    // MARK: - Arquivo

    static func codificar(_ caderno: Caderno) throws -> Data {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try codificador.encode(caderno)
    }

    /// nil when the file is not a notebook of this or an older version.
    static func decodificar(_ dados: Data, configuracao: Configuracao) -> Caderno? {
        guard let cabecalho = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
              valido(formato: cabecalho["formato"] as? String, versao: cabecalho["versao"] as? Int, configuracao: configuracao)
        else { return nil }
        return try? JSONDecoder().decode(Caderno.self, from: dados)
    }
}

// MARK: - Dados deste aparelho

extension CadernoEstudo {
    /// Every reading key saved on this device: "prefixo_data" (Breviário do Século XXI, legacy) or
    /// "prefixo_obra_data". A reading date never contains "_", so the work id is what comes before it.
    private static func leituraDaChave(_ chave: String, prefixo: String) -> (obraId: String, data: String)? {
        guard chave.hasPrefix(prefixo) else { return nil }
        let resto = String(chave.dropFirst(prefixo.count))
        guard !resto.isEmpty else { return nil }
        guard let separador = resto.lastIndex(of: "_") else { return (ObraID.breviarioSeculoXXI, resto) }
        return (String(resto[..<separador]), String(resto[resto.index(after: separador)...]))
    }

    private static func obraDoConjunto(_ chave: String, base: String) -> String? {
        if chave == base { return ObraID.breviarioSeculoXXI }
        return chave.hasPrefix(base + "_") ? String(chave.dropFirst(base.count + 1)) : nil
    }

    /// The notebook of this device: readings, saved dossiers and review cards.
    static func coletar(configuracao: Configuracao, defaults: UserDefaults = .standard) -> Caderno {
        var leituras: [String: Leitura] = [:]
        func alterar(_ obraId: String, _ data: String, _ mudar: (inout Leitura) -> Void) {
            let chave = "\(obraId)\u{1F}\(data)"
            var leitura = leituras[chave] ?? Leitura(obraId: obraId, data: data)
            mudar(&leitura)
            leituras[chave] = leitura
        }
        for (chave, valor) in defaults.dictionaryRepresentation() {
            if let (obra, data) = leituraDaChave(chave, prefixo: "comentario_"), let texto = valor as? String {
                alterar(obra, data) { $0.comentario = texto }
            } else if let (obra, data) = leituraDaChave(chave, prefixo: "reflexao_"), let texto = valor as? String {
                alterar(obra, data) { $0.reflexao = texto }
            } else if let (obra, data) = leituraDaChave(chave, prefixo: "destaques_"), let dados = valor as? Data,
                      let destaques = try? JSONDecoder().decode([DestaqueLeitura].self, from: dados) {
                alterar(obra, data) { leitura in
                    leitura.destaques = destaques.map {
                        Destaque(id: $0.id.uuidString, texto: $0.texto, criadoEm: Int64(($0.criadoEm.timeIntervalSince1970 * 1000).rounded()))
                    }
                }
            } else if let obra = obraDoConjunto(chave, base: "leituras_favoritas"), let datas = valor as? [String] {
                datas.forEach { alterar(obra, $0) { $0.favorita = true } }
            } else if let obra = obraDoConjunto(chave, base: "leituras_concluidas"), let datas = valor as? [String] {
                datas.forEach { alterar(obra, $0) { $0.lida = true } }
            } else if let obra = obraDoConjunto(chave, base: "edicoes_textos_diarios"), let dados = valor as? Data,
                      let edicoes = try? JSONDecoder().decode([String: BreviarioTextEdit].self, from: dados) {
                for (data, edicao) in edicoes {
                    alterar(obra, data) {
                        $0.edicao = Edicao(titulo: edicao.titulo, frase: edicao.frase, texto: edicao.texto,
                                           rodape: edicao.rodape ?? "", autor: edicao.autor ?? "")
                    }
                }
            }
        }
        var caderno = vazio(configuracao)
        caderno.leituras = Array(leituras.values)
        caderno.dossies = DossiesSalvosStore(defaults: defaults).todos().map {
            Dossie(id: $0.id, tema: $0.tema, area: $0.area, obraId: $0.obraId, autor: $0.autor, assunto: $0.assunto,
                   criadoEm: $0.criadoEm, revisoesConcluidas: $0.revisoesConcluidas, interpretacao: $0.interpretacao)
        }
        caderno.cartoes = CartoesRevisaoStore(defaults: defaults).todos().map {
            Cartao(cartao: $0.cartao, dossieId: $0.dossieId, tema: $0.tema, criadoEm: $0.criadoEm, estado: $0.estado)
        }
        return canonico(caderno, configuracao)
    }

    /// Writes a merged notebook to this device. Only adds or completes: the merge already kept
    /// everything that was here.
    static func aplicar(_ caderno: Caderno) {
        for leitura in caderno.leituras {
            let obra = leitura.obraId, data = leitura.data
            if CommentsService.carregar(data: data, obraID: obra) != leitura.comentario {
                CommentsService.salvar(comentario: leitura.comentario, para: data, obraID: obra)
            }
            if ReflexoesService.carregar(data: data, obraID: obra) != leitura.reflexao {
                ReflexoesService.salvar(leitura.reflexao, para: data, obraID: obra)
            }
            if leitura.favorita && !ReadingProgressService.favoritos(obraID: obra).contains(data) {
                ReadingProgressService.definirFavorito(data, obraID: obra, favorita: true)
            }
            if leitura.lida && !ReadingProgressService.concluidos(obraID: obra).contains(data) {
                ReadingProgressService.definirConcluido(data, obraID: obra, lido: true, sincronizar: false)
            }
            if !leitura.destaques.isEmpty {
                DestaquesService.salvar(leitura.destaques.sorted { $0.criadoEm > $1.criadoEm }.map {
                    DestaqueLeitura(id: UUID(uuidString: $0.id) ?? UUID(), texto: $0.texto,
                                    criadoEm: Date(timeIntervalSince1970: TimeInterval($0.criadoEm) / 1000))
                }, para: data, obraID: obra)
            }
            if let edicao = leitura.edicao, TextEditsService.carregar(data: data, obraID: obra) == nil {
                TextEditsService.salvar(edicao: BreviarioTextEdit(titulo: edicao.titulo, frase: edicao.frase, texto: edicao.texto,
                                                                  rodape: edicao.rodape, autor: edicao.autor.isEmpty ? nil : edicao.autor),
                                        para: data, obraID: obra)
            }
        }
        let dossies = DossiesSalvosStore()
        for dossie in caderno.dossies {
            dossies.salvar(DossieSalvo(id: dossie.id, tema: dossie.tema, area: dossie.area, obraId: dossie.obraId,
                                       autor: dossie.autor, assunto: dossie.assunto, criadoEm: dossie.criadoEm,
                                       revisoesConcluidas: dossie.revisoesConcluidas, interpretacao: dossie.interpretacao))
        }
        CartoesRevisaoStore().substituir(caderno.cartoes.map {
            CartoesRevisaoStore.Registro(cartao: $0.cartao, dossieId: $0.dossieId, tema: $0.tema, criadoEm: $0.criadoEm, estado: $0.estado)
        })
    }
}

// MARK: - Caderno por tema

extension CadernoEstudo {
    struct RegraPorTema: Decodable {
        let ordemTipos: [String]
        let tipos: [String: String]
        let referenciaPagina: String
        let origemDossie: String
        let cabecalhoExportacao: String
        let rotulos: [String: String]

        func rotulo(_ chave: String, _ valores: [String: String] = [:]) -> String {
            valores.reduce(rotulos[chave] ?? chave) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
        }
    }

    /// One note of the notebook: a saved dossier (with its interpretation), a highlight, a reflection or a comment.
    struct Anotacao: Decodable, Equatable, Identifiable {
        let tipo: String
        let rotulo: String
        let origem: String
        let texto: String
        let obraId: String?
        let data: String?
        let dossieId: String?

        var id: String { [tipo, obraId ?? "", data ?? "", dossieId ?? "", texto].joined(separator: "\u{1F}") }
    }

    struct Tema: Decodable, Equatable, Identifiable {
        let tema: String
        let quantidade: Int
        var id: String { tema }
    }

    /// Pages by number ("P12"), dates dd/MM by month and day; anything else first.
    static func ordemData(_ data: String?) -> Int {
        guard let data else { return 0 }
        if data.hasPrefix("P"), let pagina = Int(data.dropFirst()), data.dropFirst().allSatisfy(\.isASCII) { return pagina }
        let partes = data.split(separator: "/", omittingEmptySubsequences: false)
        guard partes.count == 2, partes.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isASCII) }),
              let dia = Int(partes[0]), let mes = Int(partes[1]) else { return 0 }
        return mes * 100 + dia
    }

    static func origem(obraId: String, data: String, titulos: [String: String], regra: RegraPorTema) -> String {
        let pagina = data.hasPrefix("P") && data.count > 1 && data.dropFirst().allSatisfy { $0.isASCII && $0.isNumber }
        let referencia = pagina ? regra.referenciaPagina.replacingOccurrences(of: "{pagina}", with: String(data.dropFirst())) : data
        return "\(titulos[obraId] ?? obraId), \(referencia)"
    }

    /// Every note of the notebook, in the order of the rule. Same as `entries` in the reference.
    static func anotacoes(_ caderno: Caderno, titulos: [String: String], configuracao: Configuracao) -> [Anotacao] {
        let regra = configuracao.porTema
        var itens: [(anotacao: Anotacao, ordem: Int)] = []
        func rotulo(_ tipo: String) -> String { regra.tipos[tipo] ?? tipo }
        for dossie in caderno.dossies {
            itens.append((Anotacao(tipo: "dossie", rotulo: rotulo("dossie"),
                                   origem: regra.origemDossie.replacingOccurrences(of: "{tema}", with: dossie.tema),
                                   texto: dossie.interpretacao?.texto ?? "", obraId: dossie.obraId, data: nil, dossieId: dossie.id), 0))
        }
        for leitura in caderno.leituras {
            let onde = origem(obraId: leitura.obraId, data: leitura.data, titulos: titulos, regra: regra)
            func nova(_ tipo: String, _ texto: String) -> Anotacao {
                Anotacao(tipo: tipo, rotulo: rotulo(tipo), origem: onde, texto: texto, obraId: leitura.obraId, data: leitura.data, dossieId: nil)
            }
            for (indice, destaque) in leitura.destaques.enumerated() { itens.append((nova("destaque", destaque.texto), indice)) }
            if !leitura.reflexao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { itens.append((nova("reflexao", leitura.reflexao), 0)) }
            if !leitura.comentario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { itens.append((nova("comentario", leitura.comentario), 0)) }
        }
        func chave(_ item: (anotacao: Anotacao, ordem: Int)) -> (Int, String, Int, Int) {
            (regra.ordemTipos.firstIndex(of: item.anotacao.tipo) ?? regra.ordemTipos.count,
             DossieEstudoAnalise.dobrar(item.anotacao.origem), ordemData(item.anotacao.data), item.ordem)
        }
        return itens.enumerated().sorted { a, b in
            let (ka, kb) = (chave(a.element), chave(b.element))
            if ka != kb { return ka < kb }
            return a.offset < b.offset
        }.map(\.element.anotacao)
    }

    /// Each word searched must start a word of the note's text or origin (case and accents ignored).
    static func buscar(_ anotacoes: [Anotacao], consulta: String) -> [Anotacao] {
        let procuradas = DossieEstudoAnalise.palavras(consulta).normalizadas
        return anotacoes.filter { anotacao in
            let palavras = DossieEstudoAnalise.palavras(anotacao.texto + " " + anotacao.origem).normalizadas
            return procuradas.allSatisfy { procurada in palavras.contains { $0.hasPrefix(procurada) } }
        }
    }

    static func temas(_ caderno: Caderno, anotacoes: [Anotacao]) -> [Tema] {
        var nomes: [String: String] = [:]
        for dossie in caderno.dossies {
            let tema = dossie.tema.trimmingCharacters(in: .whitespacesAndNewlines)
            if nomes[DossieEstudoAnalise.dobrar(tema)] == nil { nomes[DossieEstudoAnalise.dobrar(tema)] = tema }
        }
        return nomes.sorted { ($0.key, $0.value) < ($1.key, $1.value) }
            .map { Tema(tema: $0.value, quantidade: buscar(anotacoes, consulta: $0.value).count) }
    }

    static func exportar(_ encontradas: [Anotacao], consulta: String, configuracao: Configuracao) -> String {
        let regra = configuracao.porTema
        let titulo = consulta.trimmingCharacters(in: .whitespacesAndNewlines)
        var blocos = [regra.cabecalhoExportacao.replacingOccurrences(of: "{tema}", with: titulo.isEmpty ? regra.rotulo("todas") : titulo)]
        for anotacao in encontradas {
            let texto = anotacao.texto.trimmingCharacters(in: .whitespacesAndNewlines)
            blocos.append("\(anotacao.rotulo) — \(anotacao.origem)" + (texto.isEmpty ? "" : "\n" + texto))
        }
        return blocos.joined(separator: "\n\n") + "\n"
    }
}
