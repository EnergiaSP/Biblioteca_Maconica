package com.renatocamargo.breviariomaconico

import com.renatocamargo.breviariomaconico.data.BibliotecaBuscaResultado
import java.util.Locale

internal data class DossierStudyPlan(
    val roadmap: List<String>,
    val questions: List<String>,
    val conceptMap: List<String>,
    val spacedReview: List<String>,
    val crossReferences: List<String>,
    val relatedTerms: List<String>,
    val limits: List<String>
)

internal fun buildDossierStudyPlan(
    topic: String,
    results: List<BibliotecaBuscaResultado>
): DossierStudyPlan {
    val cleanTopic = topic.trim().ifBlank { "tema pesquisado" }
    val works = results.map { it.tituloObra }.distinct().sorted()
    val areas = results.map { it.area.titulo }.distinct().sorted()
    val forbidden = setOf(com.renatocamargo.breviariomaconico.data.normalized(cleanTopic),
        "para", "com", "uma", "das", "dos", "que", "por", "como", "mais", "seu", "sua",
        "este", "esta", "esse", "essa", "pela", "pelo", "ser", "sao", "são", "aos", "nas",
        "nos", "ao", "as", "os", "de", "da", "do", "em", "no", "na", "um")
    val terms = results.asSequence().flatMap { it.trecho.split(Regex("[^\\p{L}\\p{N}]+")) }
        .filter { it.length >= 4 && com.renatocamargo.breviariomaconico.data.normalized(it) !in forbidden }
        .map { it.lowercase(Locale.forLanguageTag("pt-BR")) }.groupingBy { it }.eachCount()
        .entries.sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key })
        .take(12).map { it.key }
    val crossReferences = if (results.isEmpty()) listOf(
        "Sem ocorrências suficientes para cruzamento entre obras.",
        "Importe novas obras ou refine o termo para ampliar o estudo comparado."
    ) else results.groupBy { it.area.titulo }.toSortedMap(java.text.Collator.getInstance(Locale.forLanguageTag("pt-BR")))
        .map { (area, hits) -> "$area: ${hits.size} ocorrência(s) em ${hits.map { it.tituloObra }.distinct().sorted().take(4).joinToString(", ")}" } +
        "Conferir concordâncias, diferenças de contexto e limites antes de transformar em trabalho escrito."

    return DossierStudyPlan(
        roadmap = if (results.isEmpty()) listOf(
            "Refinar o termo pesquisado com uma palavra mais específica.",
            "Selecionar uma área ou obra antes de repetir a busca.",
            "Registrar quais termos próximos devem entrar no índice de estudo."
        ) else listOf(
            "Ler primeiro as ocorrências do termo $cleanTopic nas obras com maior recorrência.",
            "Separar trechos literais, comentários pessoais e dúvidas em blocos diferentes.",
            "Comparar o mesmo termo entre breviários, dicionários, obras jurídicas e livros.",
            "Marcar os trechos centrais como favoritos para revisão espaçada.",
            "Escrever uma síntese final citando a obra e a referência de cada trecho."
        ),
        questions = listOf(
            "Como o termo $cleanTopic aparece nas diferentes obras consultadas?",
            "Há diferença entre sentido simbólico, histórico, jurídico e prático?",
            "Quais trechos devem ser citados em um trabalho ou instrução?",
            if (results.size > 1) "Quais obras concordam entre si e quais exigem leitura complementar?"
            else "Qual obra complementar deve ser importada para ampliar a análise?"
        ),
        conceptMap = buildList {
            add("$cleanTopic → obras consultadas: ${if (works.isEmpty()) "nenhuma ocorrência encontrada" else works.take(4).joinToString(", ")}")
            add("$cleanTopic → áreas envolvidas: ${if (areas.isEmpty()) "refinar busca" else areas.joinToString(", ")}")
            if (terms.isNotEmpty()) add("$cleanTopic → termos relacionados: ${terms.take(8).joinToString(", ")}")
            add("$cleanTopic → síntese pessoal: registrar entendimento com referência à obra e à página/leitura.")
        },
        spacedReview = listOf(
            "Hoje: ler as principais referências de $cleanTopic e destacar trechos centrais.",
            "Em 1 dia: reler os destaques e escrever uma síntese de cinco linhas.",
            "Em 3 dias: responder às perguntas de fixação sem consultar o texto.",
            "Em 7 dias: comparar o tema com outro termo relacionado do índice.",
            "Em 21 dias: revisar a síntese e transformar em estudo, prancha ou anotação final."
        ),
        crossReferences = crossReferences,
        relatedTerms = terms,
        limits = if (results.isEmpty()) listOf(
            "Nenhuma referência textual foi encontrada no acervo local para sustentar conclusão.",
            "A análise deve informar ausência de base e sugerir nova importação ou fonte oficial."
        ) else buildList {
            add("Conclusões devem citar somente os ${results.size} trecho(s) localizado(s) no acervo.")
            add("Não usar fontes externas sem cadastro prévio como fonte oficial.")
            if (results.map { it.obraId }.distinct().size == 1) add("Há somente uma obra envolvida; tratar a leitura como referência localizada, não como consenso amplo.")
            if (areas.size == 1) add("Há somente uma área envolvida; estudo cruzado depende de importação ou busca em outras áreas.")
        }
    )
}
