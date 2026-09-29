package com.renatocamargo.breviariomaconico

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.renatocamargo.breviariomaconico.data.BibliotecaBuscaResultado
import com.renatocamargo.breviariomaconico.data.ActiveReview
import com.renatocamargo.breviariomaconico.data.DossierAnalysis

/** AI-free dossier analysis kept with the dossier; every line is extracted from the sources and cites one. */
internal data class DossierStudy(
    val display: DossierAnalysis.Display,
    val relatedTerms: List<String>,
    val analyzedSources: Int,
    /** With occurrence counts, for the drawn map. */
    val related: List<DossierAnalysis.RelatedTerm> = emptyList(),
    /** Review cards made from the analysis, stored when the dossier is saved (revisao_ativa_v1.json). */
    val cards: List<ActiveReview.Card> = emptyList()
)

/** The topic is studied as an expression ("Escada de Jacó"), accepting spelling variants ("Jacob"). */
internal fun dossierQuery(topic: String): String {
    val clean = topic.trim()
    return if ('"' in clean || ' ' !in clean) clean else "\"$clean\""
}

/** Sources of the dossier analysis and of the AI prompt ([F1] is the first result shown). */
internal fun dossierSources(results: List<BibliotecaBuscaResultado>): List<DossierAnalysis.Source> = results.map {
    DossierAnalysis.Source("${it.obraId}:${it.pagina}:${it.blocoId ?: it.data}", it.obraId, it.tituloObra, it.area.raw,
        it.pagina, it.data, it.trecho, it.rodape)
}

/** [today] dates the review plan; a reopened saved dossier passes the day it was saved. */
internal fun analyzeDossier(
    topic: String,
    results: List<BibliotecaBuscaResultado>,
    config: DossierAnalysis.Config,
    today: java.time.LocalDate = java.time.LocalDate.now(),
    reviewConfig: ActiveReview.Config? = null
): DossierStudy {
    val sources = dossierSources(results)
    val analysis = DossierAnalysis.analyze(topic.trim(), sources, config, today)
    val cards = reviewConfig?.let {
        ActiveReview.generate(topic.trim(), analysis.definitions, analysis.questions, analysis.relatedTerms.map { term -> term.form }, sources, it)
    }.orEmpty()
    return DossierStudy(DossierAnalysis.display(topic.trim(), analysis, sources, config), analysis.relatedTerms.map { it.form }, sources.size,
        analysis.relatedTerms, cards)
}

/** Sections shown only when the dossier has its analysis, in the same order as on iOS. */
internal fun dossierAnalysisSections(display: DossierAnalysis.Display): List<Pair<String, List<String>>> = listOf(
    "Definição" to display.definitions.ifEmpty { listOf("Nenhum dicionário do acervo define o tema.") },
    "Resumo com fontes" to display.summary.ifEmpty { listOf("Nenhuma frase das fontes trata diretamente do tema.") },
    "Pontos a comparar" to display.divergences,
    "Métricas" to display.metrics,
    "Obras centrais" to display.centralWorks,
    "Capítulos dedicados ao tema" to display.dedicatedChapters
).filter { it.second.isNotEmpty() }

@Composable
internal fun DossierAnalysisSections(colors: Palette, display: DossierAnalysis.Display) {
    Column(Modifier.testTag("dossier.summary"), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        for ((title, lines) in dossierAnalysisSections(display)) {
            PremiumCard(colors) {
                Text(title, color = colors.text, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                SelectionContainer {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        lines.forEach { Text("• $it", color = colors.secondary) }
                    }
                }
            }
        }
    }
}
