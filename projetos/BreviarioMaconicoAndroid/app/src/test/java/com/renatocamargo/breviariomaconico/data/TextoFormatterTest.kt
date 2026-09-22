package com.renatocamargo.breviariomaconico.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TextoFormatterTest {
    @Test
    fun quotedPhraseKeepsOrderWhileWordsCanCross() {
        assertEquals("\"grande loja\" AND \"história\"", TextoFormatter.consultaFTSSegura("\"Grande Loja\" história"))
        assertTrue(TextoFormatter.corresponde("grande loja", "A loja é grande"))
        org.junit.Assert.assertFalse(TextoFormatter.corresponde("\"grande loja\"", "A loja é grande"))
        assertTrue(TextoFormatter.corresponde("maçonaria", "Estudo da MACONARIA."))
    }

    @Test
    fun superscriptDoesNotChangeDatesYearsOrUnknownNumbers() {
        val text = "Em 01/06/2026, texto 578 e outro579. Total 1234; 12/578 não é chamada."
        assertEquals("Em 01/06/2026, texto ⁵⁷⁸ e outro⁵⁷⁹. Total 1234; 12/578 não é chamada.",
            TextoFormatter.sobrescrito(text, "578 Primeira nota.\n579 Segunda nota."))
    }

    @Test
    fun weekStartsOnSundayAndCrossesYear() {
        assertEquals(setOf("28/12", "29/12", "30/12", "31/12", "01/01", "02/01", "03/01"),
            TextoFormatter.datasSemana(java.time.LocalDate.of(2026, 1, 1)))
    }

    @Test
    fun adjacentReadingNeverCrossesWorksWithOverlappingIds() {
        val a = BreviarioItem(1, "01/01", "A", "", "", "", 1, "a")
        val b = a.copy(obraId = "b")
        val next = a.copy(id = 2, data = "02/01")
        assertEquals(next, adjacentReading(listOf(a, b, next), a, 1))
        assertEquals(b, adjacentReading(listOf(a, b, next), b, 1))
    }

    @Test
    fun ftsTreatsOperatorsAndHyphensAsLiteralSearchText() {
        assertEquals("\"grão\" AND \"mestre\"", TextoFormatter.consultaFTSSegura("Grão-mestre"))
        assertEquals("\"or\"", TextoFormatter.consultaFTSSegura("OR"))
        assertEquals("\"\"\"\"", TextoFormatter.consultaFTSSegura("\""))
        assertEquals("\"!!!\"", TextoFormatter.consultaFTSSegura("!!!"))
    }

    @Test
    fun invalidDatesAndPageReferencesArePreserved() {
        listOf("00/06", "01/13", "01/00", "32/01", "01/06/2026", "P185").forEach {
            assertEquals(it, TextoFormatter.dataPorExtenso(it))
        }
    }

    @Test
    fun preservesParagraphBreaksAndNormalizesWrappedLines() {
        val input = "Primeira linha\ncontinuação do parágrafo.\n\nSegundo parágrafo."
        assertEquals(
            "Primeira linha continuação do parágrafo.\n\nSegundo parágrafo.",
            TextoFormatter.textoComParagrafos(input)
        )
    }

    @Test
    fun formatsPortugueseDate() {
        assertEquals("01 de junho", TextoFormatter.dataPorExtenso("01/06"))
    }

    @Test
    fun shareIncludesCompleteFootnotesAndComment() {
        val item = BreviarioItem(
            id = 1,
            obraId = "obra",
            data = "01/06",
            titulo = "Título",
            texto = "Texto completo.",
            rodape = "578 Nota completa.",
            autor = "Autor",
            pagina = 1
        )
        val shared = TextoFormatter.textoCompartilhavel(item, "Comentário completo.")
        assertTrue(shared.contains("Texto completo."))
        assertTrue(shared.contains("578 Nota completa."))
        assertTrue(shared.contains("Comentário completo."))
    }

    @Test
    fun footnotesAreKeptOnSequentialLines() {
        assertEquals(
            "578 Primeira nota.\n579 Segunda nota.",
            TextoFormatter.rodapeEmLinhas("578 Primeira nota. 579 Segunda nota.")
        )
    }

    @Test
    fun persistenceKeySeparatesWorksWithSameDate() {
        val first = BreviarioItem(1, "01/06", "A", "", "Texto", "", 1, "obra_a")
        val second = BreviarioItem(1, "01/06", "B", "", "Texto", "", 1, "obra_b")
        assertTrue(first.chavePersistencia != second.chavePersistencia)
    }

    @Test
    fun normalizationSupportsAccentInsensitiveSearch() {
        assertEquals("maconaria e simbolos", normalized("Maçonaria e Símbolos"))
    }
}
