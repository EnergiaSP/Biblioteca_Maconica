package com.renatocamargo.breviariomaconico

import android.content.Context
import android.content.ContextWrapper
import android.content.ContentValues
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.renatocamargo.breviariomaconico.data.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID
import java.io.File
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.net.Uri
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.json.JSONObject

@RunWith(AndroidJUnit4::class)
class DataIntegrityTest {
    /**
     * Searching matches the reading itself, not the work's title, author or subjects, and local
     * readings carry the same bm25 relevance as downloaded packages.
     */
    @Test
    fun librarySearchMatchesReadingTextNotWorkMetadata() {
        val catalog = BibliotecaCatalogRepository.get(ApplicationProvider.getApplicationContext())
        // 21 since the reading of 02/04 ("Stolkin") came from the printed page: its notes cite "sua filosofia".
        for ((term, expected) in listOf("filosofia" to 21, "ética" to 4)) {
            val results = catalog.buscarConteudo(term, obraId = ObraId.BREVIARIO_SECULO_XXI, limite = 500)
            assertEquals(term, expected, results.size)
            assertTrue(term, results.all { it.ranking < 0 })
            assertEquals(term, results.map { it.ranking }.sorted(), results.map { it.ranking })
        }
    }

    @Test
    fun localTextsUseTheSameFtsQueryAsPackages() {
        val texts = mapOf("a" to "A Escada de Jacó e a escada.", "b" to "Leitura e lei.", "c" to "Escada simples")
        assertEquals(setOf("a"), rankLocalTexts("\"escada de jaco\"", texts).keys)
        assertEquals(setOf("a", "c"), rankLocalTexts("escada", texts).keys)
        // bm25 also weighs text length, so frequency is compared on texts of equal length.
        val frequency = rankLocalTexts("escada", mapOf("two" to "escada escada neutro", "one" to "escada neutro neutro"))
        assertTrue("More occurrences rank first", frequency.getValue("two") < frequency.getValue("one"))
        assertEquals(setOf("b"), rankLocalTexts("lei", texts).keys)
    }

    /** The AI-free dossier must reproduce the golden cases of Tools/dossie_referencia.py exactly. */
    @Test
    fun dossierAnalysisMatchesReferenceCases() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val config = DossierAnalysis.loadConfig(context)
        val root = JSONObject(context.assets.open("casos_dossie_v1.json").bufferedReader().use { it.readText() })
        val cases = root.getJSONArray("casos")
        assertTrue(cases.length() > 0)
        val headings = root.getJSONArray("titulos")
        assertTrue(headings.length() > 0)
        for (index in 0 until headings.length()) {
            val case = headings.getJSONObject(index)
            val (heading, body) = DossierAnalysis.splitHeading(DossierAnalysis.clean(case.getString("texto")))
            val expected = case.getJSONArray("esperado")
            assertEquals(case.getString("id"), listOf(expected.getString(0), expected.getString(1)), listOf(heading, body))
        }
        fun canonical(value: Any?): Any? = when (value) {
            is JSONObject -> value.keys().asSequence().associateWith { canonical(value.get(it)) }.toSortedMap()
            is org.json.JSONArray -> List(value.length()) { canonical(value.get(it)) }
            is Number -> value.toLong()
            else -> value
        }
        for (index in 0 until cases.length()) {
            val case = cases.getJSONObject(index)
            val rows = case.getJSONArray("fontes")
            val sources = List(rows.length()) { row -> rows.getJSONObject(row).let {
                DossierAnalysis.Source(it.getString("id"), it.getString("obraId"), it.getString("tituloObra"), it.getString("area"),
                    it.getInt("pagina"), it.optString("data").ifEmpty { null }, it.optString("texto"), it.optString("rodape"))
            } }
            val analysis = DossierAnalysis.analyze(case.getString("termo"), sources, config, java.time.LocalDate.parse(case.getString("hoje")))
            val result = analysis.toJson().put("exibicao", DossierAnalysis.display(case.getString("termo"), analysis, sources, config).toJson())
            val expected = case.getJSONObject("esperado")
            assertEquals(case.getString("id"), expected.keys().asSequence().toSet(), result.keys().asSequence().toSet())
            for (key in expected.keys()) {
                assertEquals("${case.getString("id")}.$key", canonical(expected.get(key)), canonical(result.get(key)))
            }
        }
    }

    /** Collections built from the two integrated breviaries, compared with iOS by rule id. */
    @Test
    fun localBreviaryCollectionsAreRecordedForParity() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val repo = BreviarioRepository.get(context)
        val rules = StudyRules.load(context)
        val selection = localStudySelection(repo.itens, repo.indice, rules)
        assertEquals(rules.collections.size + rules.paths.size, selection.size)
        assertTrue(selection.values.all { it.isNotEmpty() })
        val json = JSONObject()
        selection.forEach { (id, items) -> json.put(id, org.json.JSONArray(items.map { it.item.chavePersistencia })) }
        File(context.filesDir, "estudos-locais-android.json").writeText(json.toString(2))
    }

    /** The index engine must rank pages exactly like the shared in-memory rule, in both index layouts. */
    @Test
    fun indexStudyScoringMatchesSharedRule() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val blocks = listOf(
            1 to "A Escada de Jacó tem degraus: a escada de Jacó e a Grande Loja.",
            2 to "Leitura do espírito; nenhuma palavra inteira aqui.",
            3 to "Uma ética da virtude.",
            3 to "Segundo bloco da mesma página com virtude e ética.",
            4 to "Texto neutro.",
            5 to "Grande   loja, grande loja e lei."
        )
        val note = "Nota sobre a Escada de Jacó e a lei."
        val ruleTexts = listOf(listOf("escada de jaco", "degraus", "grande loja"), listOf("etica", "virtude"), listOf("lei", "rito", "grande loja"))
        val rules = ruleTexts.map { words -> StudyRules.studyKeywords(words.map(StudyRules::studyNormalized)) }
        val limits = listOf(3, 3, 3)
        val items = (1..5).map { page ->
            BreviarioItem("estudo-pagina-$page".hashCode(), "P$page", "Página $page", "",
                blocks.filter { it.first == page }.joinToString("\n") { it.second }, if (page == 4) "578 $note" else "", page, "estudo")
        }
        val texts = items.associate { it.chavePersistencia to listOf(it.titulo, it.texto, it.rodape).joinToString(" ") }
        for (catalogLayout in listOf(true, false)) {
            val file = File(context.cacheDir, "estudo-${System.nanoTime()}.sqlite")
            try {
                val scores = RagSQLite.open(file.path).use { db ->
                    db.execSQL("CREATE TABLE rag_paragrafos(id TEXT PRIMARY KEY, obra_id TEXT, pagina INTEGER, texto TEXT)")
                    db.execSQL("CREATE TABLE rag_notas(obra_id TEXT, pagina INTEGER, numero TEXT, texto TEXT)")
                    db.execSQL(if (catalogLayout) "CREATE VIRTUAL TABLE rag_fts USING fts5(bloco_id UNINDEXED, obra_id UNINDEXED, titulo_obra, area UNINDEXED, pagina UNINDEXED, texto, tokenize = 'unicode61 remove_diacritics 2')"
                        else "CREATE VIRTUAL TABLE rag_fts USING fts5(bloco_id UNINDEXED, texto, tokenize = 'unicode61 remove_diacritics 2')")
                    blocks.forEachIndexed { index, (page, text) ->
                        db.execSQL("INSERT INTO rag_paragrafos VALUES (?, 'estudo', ?, ?)", arrayOf("b$index", page, text))
                        if (catalogLayout) db.execSQL("INSERT INTO rag_fts VALUES (?, 'estudo', 'Estudo', 'bibliotecaMaconica', ?, ?)", arrayOf("b$index", page, text))
                        else db.execSQL("INSERT INTO rag_fts VALUES (?, ?)", arrayOf("b$index", text))
                    }
                    db.execSQL("INSERT INTO rag_notas VALUES ('estudo', 4, '578', ?)", arrayOf(note))
                    StudyIndex.score(db, setOf("estudo"), rules, limits)
                }
                ruleTexts.forEachIndexed { index, words ->
                    val memory = StudyRules.select(items, words, texts, limits[index])
                    assertEquals("layout $catalogLayout, rule $index", memory.map { it.pagina }, scores[index].map { it.ref.pagina })
                }
                assertEquals(listOf(1, 5, 4), scores[0].map { it.ref.pagina })
                assertEquals(3, scores[0].first().topics)
                assertEquals(4, scores[0].first().occurrences)
                assertEquals(listOf(5, 1, 4), scores[2].map { it.ref.pagina })
            } finally {
                file.delete()
            }
        }
    }

    /** Phase 1 scores study themes straight from the FTS index; the bundled SQLite must provide fts5vocab. */
    @Test
    fun bundledSQLiteSupportsIndexOnlyTermCounts() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val file = File(context.cacheDir, "fts5vocab-${System.nanoTime()}.sqlite")
        try {
            RagSQLite.open(file.path).use { db ->
                db.execSQL("CREATE VIRTUAL TABLE rag_fts USING fts5(bloco_id UNINDEXED, texto, tokenize = 'unicode61 remove_diacritics 2')")
                db.execSQL("INSERT INTO rag_fts VALUES ('a', 'A Escada de Jacó e a escada do templo.')")
                db.execSQL("INSERT INTO rag_fts VALUES ('b', 'Leitura sem o termo.')")
                db.execSQL("CREATE VIRTUAL TABLE temp.vocab USING fts5vocab(main, rag_fts, 'instance')")
                val rows = mutableListOf<List<Int>>()
                db.rawQuery("SELECT doc, count(DISTINCT term), count(*) FROM temp.vocab WHERE term IN ('escada', 'jaco', 'lei') GROUP BY doc", emptyArray()).use {
                    while (it.moveToNext()) rows.add(listOf(it.getInt(0), it.getInt(1), it.getInt(2)))
                }
                // Whole words, accents folded: "lei" does not count inside "Leitura".
                assertEquals(listOf(listOf(1, 2, 3)), rows)
            }
        } finally {
            file.delete()
        }
    }

    @Test
    fun metadataFiltersFollowSharedCasesAndPrecedePagination() {
        val fixture = JSONObject(context.assets.open("casos_comuns_v1.json").bufferedReader().use { it.readText() })
            .getJSONArray("metadataFilters")
        for (index in 0 until fixture.length()) {
            val item = fixture.getJSONObject(index)
            val topics = item.getJSONArray("topics")
            val work = BibliotecaObraCatalogo(item.getString("id"), "Obra",
                if (item.isNull("workAuthor")) null else item.getString("workAuthor"), 60,
                List(topics.length()) { topics.getString(it) })
            assertEquals(item.getString("id"), item.getBoolean("matches"),
                LibraryMetadataFilter(item.getString("author"), item.getString("subject")).matches(work))
        }
        val root = File(context.cacheDir, "metadata-search-${UUID.randomUUID()}")
        val isolated = object : ContextWrapper(context) {
            override fun getFilesDir() = root
            override fun getApplicationContext(): Context = this
        }
        try {
            val folder = File(root, "RAGPackages").apply { mkdirs() }
            File(folder, "imported_works.json").writeText("""[
                {"id":"a-excluded","title":"A","author":"Outro autor","assuntos":["História"],"area":"bibliotecaMaconica","pages":60,"databaseFile":"filters.sqlite"},
                {"id":"z-included","title":"Z","author":"José da Silva","assuntos":["Ética"],"area":"bibliotecaMaconica","pages":60,"databaseFile":"filters.sqlite"}
            ]""")
            RagSQLite.open(File(folder, "filters.sqlite").path).use { db ->
                db.execSQL("CREATE TABLE rag_obras(id TEXT PRIMARY KEY, titulo TEXT, area TEXT)")
                db.execSQL("CREATE TABLE rag_paragrafos(id TEXT, obra_id TEXT, pagina INTEGER, texto TEXT)")
                db.execSQL("CREATE TABLE rag_notas(obra_id TEXT, pagina INTEGER, numero TEXT, texto TEXT)")
                db.execSQL("CREATE VIRTUAL TABLE rag_fts USING fts5(bloco_id UNINDEXED, obra_id UNINDEXED, texto)")
                for (work in listOf("a-excluded", "z-included")) {
                    db.execSQL("INSERT INTO rag_obras VALUES (?, ?, 'bibliotecaMaconica')", arrayOf(work, work))
                    for (page in 1..60) {
                        db.execSQL("INSERT INTO rag_paragrafos VALUES (?, ?, ?, 'Vocabulário documental')", arrayOf(page.toString(), work, page))
                        db.execSQL("INSERT INTO rag_fts VALUES (?, ?, 'Vocabulário documental')", arrayOf(page.toString(), work))
                        db.execSQL("INSERT INTO rag_notas VALUES (?, ?, '578', 'Termonota documental')", arrayOf(work, page))
                    }
                }
            }
            val catalog = BibliotecaCatalogRepository(isolated)
            val filter = LibraryMetadataFilter("Jose", "etica")
            for (query in listOf("vocabulário", "termonota")) {
                val all = catalog.buscarConteudo(query, limite = 100, filtro = filter)
                assertEquals(60, all.size)
                assertTrue(all.all { it.obraId == "z-included" })
                val pages = listOf(0, 25, 50).flatMap { catalog.buscarConteudo(query, limite = 25, offset = it, filtro = filter) }
                assertEquals(all.map { it.id }, pages.map { it.id })
                assertTrue(catalog.buscarConteudo(query, obraId = "a-excluded", filtro = filter).isEmpty())
                assertTrue(catalog.buscarConteudo(query, area = BibliotecaArea.Judiciario, filtro = filter).isEmpty())
            }
            assertEquals("Autor: Jose • Assunto: etica", filter.descricao)
            val embedded = catalog.buscarConteudo("virtude", obraId = ObraId.BREVIARIO_SECULO_XXI,
                filtro = LibraryMetadataFilter("Kennyo", "Ética"))
            assertFalse(embedded.isEmpty())
            assertTrue(catalog.buscarConteudo("virtude", obraId = ObraId.BREVIARIO_SECULO_XXI, filtro = filter).isEmpty())
        } finally { root.deleteRecursively() }
    }

    @Test
    fun highlightsStayWithTheirOriginalWorkAndPage() {
        val prefs = PreferencesStore(context)
        val first = original.copy(obraId = "highlight-audit", data = "P1")
        val second = first.copy(data = "P2")
        val other = second.copy(obraId = "other-highlight-audit")
        prefs.addHighlight(first, "Marcador da primeira página")
        prefs.addHighlight(second, "Trecho com acentuação e símbolo: □.")
        assertEquals(listOf("Marcador da primeira página"), prefs.highlights(first).map { it.text })
        assertEquals(listOf("Trecho com acentuação e símbolo: □."), prefs.highlights(second).map { it.text })
        assertTrue(prefs.highlights(other).isEmpty())
        prefs.removeHighlight(second, prefs.highlights(second).single().id)
        assertTrue(prefs.highlights(second).isEmpty())
        assertEquals(1, prefs.highlights(first).size)
    }

    @Test
    fun progressObserverCanQueueAnotherEditWithoutLosingIt() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val prefs = context.getSharedPreferences("reading_progress_sync_v1", Context.MODE_PRIVATE)
        val before = listOf("latest", "pending").associateWith { prefs.getString(it, null) }
        val work = "reentry-${java.util.UUID.randomUUID()}"
        val event = com.renatocamargo.breviariomaconico.progress.ProgressVersion(work, "01/06", true, 100, "incoming")
        val observed = java.util.concurrent.CountDownLatch(1)
        try {
            com.renatocamargo.breviariomaconico.progress.ProgressTransport.receive(context, event) {
                com.renatocamargo.breviariomaconico.progress.ProgressTransport.send(context, work, "02/06", true)
                observed.countDown()
            }
            assertTrue(observed.await(5, java.util.concurrent.TimeUnit.SECONDS))
            val latest = org.json.JSONArray(prefs.getString("latest", "[]"))
            val dates = (0 until latest.length()).map { latest.getJSONObject(it) }
                .filter { it.getString("obraId") == work }.map { it.getString("data") }.toSet()
            assertEquals(setOf("01/06", "02/06"), dates)
        } finally {
            prefs.edit().apply {
                before.forEach { (key, value) -> if (value == null) remove(key) else putString(key, value) }
            }.commit()
        }
    }

    @Test
    fun importedWorkIdentifiersKeepRepeatedTitlesIndependentAndBounded() {
        val ids = (1..100).map { LocalPdfOcrImporter.newWorkId("História maçônica ".repeat(100)) }
        assertEquals(100, ids.toSet().size)
        assertTrue(ids.all { it.toByteArray().size < 220 && !it.contains('/') })
        assertTrue(LocalPdfOcrImporter.newWorkId("🗂️").isNotBlank())
    }

    @Test
    fun globalRemissiveIndexRespectsAreaWorkAndOriginalReferences() {
        val catalog = BibliotecaCatalogRepository(context)
        val expected = BreviarioRepository.get(context).indice
        val all = catalog.indiceRemissivoGlobal()
        // Entry ids restart in each integrated breviary, so entries are identified by work and id.
        assertEquals(expected.map { it.obraId to it.id }.toSet(), all.map { it.entrada.obraId to it.entrada.id }.toSet())
        assertEquals(all, catalog.indiceRemissivoGlobal(BibliotecaArea.Breviarios))
        for (work in listOf(ObraId.BREVIARIO_SECULO_XXI, ObraId.BREVIARIO_RIZZARDO)) {
            val byWork = catalog.indiceRemissivoGlobal(obraId = work)
            assertTrue(work, byWork.isNotEmpty())
            assertEquals(all.filter { it.entrada.obraId == work }, byWork)
        }
        assertTrue(catalog.indiceRemissivoGlobal(BibliotecaArea.Dicionarios).isEmpty())
        assertTrue(catalog.indiceRemissivoGlobal(obraId = "missing").isEmpty())
        assertTrue(all.all { reference ->
            expected.first { it.obraId == reference.entrada.obraId && it.id == reference.entrada.id } == reference.entrada
        })
    }

    @Test
    fun dossierExportsEveryFullSourceNoteAndOptionalAnalysis() {
        val fixture = context.assets.open("casos_comuns_v1.json").bufferedReader().use {
            org.json.JSONObject(it.readText()).getJSONObject("dossier")
        }
        val topic = fixture.getString("topic")
        val sources = (1..fixture.getInt("sourceCount")).map { index ->
            BibliotecaBuscaResultado("audit", "Obra de teste", BibliotecaArea.Biblioteca, index,
                "Texto documental integral. ".repeat(40) + "FIMFONTE${index}FIM", rodape = "578 NOTAFONTE${index}FIM")
        }
        val review = fixture.getJSONArray("review")
        val plan = buildDossierStudyPlan(topic, sources)
        assertEquals(List(review.length()) { review.getString(it) }, plan.spacedReview)
        val json = org.json.JSONObject(mapOf("roadmap" to plan.roadmap, "questions" to plan.questions,
            "conceptMap" to plan.conceptMap, "spacedReview" to plan.spacedReview, "crossReferences" to plan.crossReferences,
            "relatedTerms" to plan.relatedTerms, "limits" to plan.limits))
        File(context.filesDir, "paridade-dossie-plano-android.json").writeText(json.toString())
        val filteredScope = "Toda a biblioteca • " + LibraryMetadataFilter("José", "Ética").descricao
        val text = textoDossie(topic, sources, escopo = filteredScope)
        assertTrue(text.contains("Autor: José"))
        assertTrue(text.contains("Assunto: Ética"))
        val prompt = promptAnaliseDossie(context, topic, sources)
        for (index in 1..sources.size) for (content in listOf(text, prompt)) {
            assertTrue(content.contains("[F$index]"))
            assertTrue(content.contains("FIMFONTE${index}FIM"))
            assertTrue(content.contains("NOTAFONTE${index}FIM"))
        }
        assertFalse(text.contains("Análise por IA"))
        val withAnalysis = textoDossie(topic, sources, "ANALISEINTEGRALFIM [F30]")
        assertTrue(withAnalysis.contains("ANALISEINTEGRALFIM"))
        createDossierPdf(File(context.filesDir, "paridade-dossie-android.pdf"), topic, sources, "ANALISEINTEGRALFIM [F30]", scope = filteredScope)
    }

    /** The AI prompt, the answer filter and the displayed text match Tools/ia_referencia.py exactly. */
    @Test
    fun assistedInterpretationMatchesReferenceCases() {
        val config = AssistedInterpretation.loadConfig(context)
        val study = DossierAnalysis.loadConfig(context)
        val root = JSONObject(context.assets.open("casos_ia_v1.json").bufferedReader().use { it.readText() })
        fun sources(array: org.json.JSONArray) = List(array.length()) { index ->
            val item = array.getJSONObject(index)
            DossierAnalysis.Source(item.getString("id"), item.getString("obraId"), item.getString("tituloObra"), item.getString("area"),
                item.getInt("pagina"), item.optString("data").takeIf { item.has("data") && it.isNotEmpty() }, item.optString("texto"), item.optString("rodape"))
        }
        val prompts = root.getJSONArray("prompts")
        for (index in 0 until prompts.length()) {
            val case = prompts.getJSONObject(index)
            val official = case.optJSONArray("fontesOficiais")?.let { array ->
                List(array.length()) { array.getJSONObject(it).let { o ->
                    AssistedInterpretation.OfficialSource(o.getString("titulo"), o.getString("origem"), o.getString("url"), o.getString("observacao"))
                } }
            }.orEmpty()
            assertEquals(case.getString("id"), case.getString("esperado"),
                AssistedInterpretation.prompt(case.getString("termo"), sources(case.getJSONArray("fontes")), official, config, study))
        }
        val sets = root.getJSONObject("fontes")
        val answers = root.getJSONArray("respostas")
        for (index in 0 until answers.length()) {
            val case = answers.getJSONObject(index)
            val id = case.getString("id")
            val list = sources(sets.getJSONArray(case.getString("fontes")))
            val expected = case.getJSONObject("esperado")
            val result = AssistedInterpretation.filter(case.getString("resposta"), list, config)
            assertEquals(id, expected.getString("texto"), result.text)
            assertEquals(id, expected.getInt("frasesMantidas"), result.kept)
            assertEquals(id, expected.getInt("frasesRemovidas"), result.removed)
            val cited = expected.getJSONArray("fontesCitadas")
            assertEquals(id, List(cited.length()) { cited.getInt(it) }, result.citedSources)
            assertEquals(id, expected.getString("exibicao"), AssistedInterpretation.display(result, list, config, study))
        }
    }

    /** Saved dossiers date their reviews from the day they were saved, with the same rule as iOS. */
    @Test
    fun savedDossierReviewsFollowSharedSchedule() {
        val steps = DossierAnalysis.loadConfig(context).review
        assertEquals(listOf(0, 1, 3, 7, 21), steps.map { it.days })
        val saved = SavedDossier("t", "Escada de Jacó", "bibliotecaMaconica", null, "", "", "2026-09-20", listOf(0))
        val today = java.time.LocalDate.parse("2026-09-23")
        val reviews = saved.reviews(steps, today)
        assertEquals(listOf("2026-09-20", "2026-09-21", "2026-09-23", "2026-09-27", "2026-10-11"), reviews.map { it.date.toString() })
        assertEquals(
            listOf(SavedDossier.Status.FEITA, SavedDossier.Status.ATRASADA, SavedDossier.Status.HOJE, SavedDossier.Status.PROXIMA, SavedDossier.Status.PROXIMA),
            reviews.map { it.status }
        )
        assertEquals(1, saved.nextReview(steps, today)?.days)
        assertEquals(3, saved.toggled(1).nextReview(steps, today)?.days)
        assertEquals(listOf(0), saved.toggled(1).toggled(1).revisoesConcluidas)
        assertEquals(saved.chave, SavedDossier.chave("  escada de JACÓ ", "bibliotecaMaconica", null, "", ""))
        assertEquals(DossierAnalysis.ReminderTime(9, 0), DossierAnalysis.loadConfig(context).reviewReminder)

        val store = SavedDossierStore(context)
        val before = store.all()
        try {
            store.save(saved)
            store.save(saved.copy(id = "u", revisoesConcluidas = listOf(0, 1)))
            assertEquals("Same study is replaced, not duplicated", listOf("u"), store.all().filter { it.chave == saved.chave }.map { it.id })
            assertEquals(listOf(0, 1), store.find("u")?.revisoesConcluidas)
            store.remove("u")
            assertNull(store.findByKey(saved.chave))
        } finally {
            store.all().forEach { store.remove(it.id) }
            before.forEach { store.save(it) }
        }
    }

    /** A package installed from an earlier catalog is offered as an update, as on iOS. */
    @Test
    fun installedPackageFromEarlierCatalogIsOutdated() {
        val catalog = BibliotecaCatalogRepository(context)
        // Works on a device without the collection: a stand-in file is created for the check.
        val pacote = BibliotecaArea.values().flatMap { catalog.estados(it) }
            .let { estados -> (estados.firstOrNull { it.instalado } ?: estados.first { it.pacote.sha256 != null }).pacote }
        val local = catalog.localFile(pacote)
        val criado = !local.exists()
        if (criado) { local.parentFile?.mkdirs(); local.writeText("pacote de teste") }
        val versao = File(context.filesDir, "RAGPackages/${pacote.arquivo}.sha256")
        val anterior = versao.takeIf { it.exists() }?.readBytes()
        try {
            versao.delete()
            assertTrue("No recorded version counts as outdated", catalog.desatualizado(pacote))
            versao.writeText("0000")
            assertTrue(catalog.desatualizado(pacote))
            versao.writeText(pacote.sha256!!.uppercase())
            assertFalse(catalog.desatualizado(pacote))
            assertFalse(catalog.estados(pacote.area).first { it.pacote.id == pacote.id }.desatualizado)
        } finally {
            if (anterior != null) versao.writeBytes(anterior) else versao.delete()
            if (criado) local.delete()
        }
    }

    /** Words split by the import/OCR (Tools/corrigir_palavras_quebradas.py) stay joined, as on iOS. */
    @Test
    fun breviaryReadingsHaveNoWordsSplitByOcr() {
        val broken = listOf("difi cilmente", "signifi cando", "constran gimentos", "coraça- o", "na- o", "Maço naria", "exis tência", "tornando- se", "Grão- Mestre")
        val repository = BreviarioRepository.get(context)
        val texts = repository.itens.map { listOf(it.titulo, it.texto, it.rodape).joinToString("\n") }
        broken.forEach { piece -> assertFalse(piece, texts.any { it.contains(piece) }) }
        assertTrue(repository.porObraEData(ObraId.BREVIARIO_RIZZARDO, "25/02")!!.texto.contains("pois dificilmente se pode"))
    }

    @Test
    fun dailyWorkHasCompletePageIndexAndAccentInsensitiveFilter() {
        val catalog = BibliotecaCatalogRepository.get(context)
        val pages = catalog.indicePaginas(ObraId.BREVIARIO_SECULO_XXI, 500)
        val expected = BreviarioRepository.get(context).itens.filter { it.obraId == ObraId.BREVIARIO_SECULO_XXI }
        assertEquals(expected.size, pages.size)
        assertEquals(expected.map { it.data }.toSet(), pages.map { it.data }.toSet())
        assertTrue(catalog.indicePaginas(ObraId.BREVIARIO_SECULO_XXI, 500, "junho").all { it.data!!.endsWith("/06") })
        assertTrue(catalog.indicePaginas(ObraId.BREVIARIO_SECULO_XXI, 500, "01/06").any { it.data == "01/06" })
    }

    @Test
    fun liveGeminiGroundingAndMissingEvidence() {
        val args = androidx.test.platform.app.InstrumentationRegistry.getArguments()
        org.junit.Assume.assumeTrue("Live Gemini needs an explicitly configured test key and opt-in", args.getString("liveGemini") == "true")
        val key = PreferencesStore(context).settings.geminiApiKey
        org.junit.Assume.assumeTrue("No Gemini test key in the app's secure storage", key.isNotBlank())
        val sources = "[F1] Documento sintético de teste: a sala de estudos tem sete cadeiras. [F2] Documento sintético de teste: a sala possui duas mesas."
        val response = GeminiService.gerarTexto("Use exclusivamente estas fontes: $sources. Quantas cadeiras e mesas existem? Responda uma frase com números em algarismos e cite [F1] e [F2].", key)
        assertTrue(response.contains("7") && response.contains("2"))
        assertTrue(response.contains("[F1]") && response.contains("[F2]"))
        val refusal = GeminiService.gerarTexto("Use exclusivamente estas fontes: $sources. Em que ano a sala foi construída? Caso a fonte não informe o ano, retorne somente DOCUMENTO_INSUFICIENTE. Não invente informações.", key)
        assertEquals("DOCUMENTO_INSUFICIENTE", refusal.trim())
    }

    @Test
    fun notificationIsActuallyPostedWithReadingAction() {
        val instrumentation = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            instrumentation.uiAutomation.grantRuntimePermission(context.packageName, android.Manifest.permission.POST_NOTIFICATIONS)
        }
        val manager = context.getSystemService(android.app.NotificationManager::class.java)
        try {
            NotificationReceiver().onReceive(context, android.content.Intent())
            val deadline = android.os.SystemClock.elapsedRealtime() + 5_000
            while (manager.activeNotifications.none { it.notification.channelId == "breviario_daily" } && android.os.SystemClock.elapsedRealtime() < deadline) {
                Thread.sleep(100)
            }
            val posted = manager.activeNotifications.filter { it.notification.channelId == "breviario_daily" }
            assertFalse("The OS must contain the posted notification, not just a scheduled alarm", posted.isEmpty())
            posted.forEach {
                assertNotNull(it.notification.contentIntent)
                assertTrue(it.notification.actions.orEmpty().any { action -> action.title.toString() == "Abrir leitura" && action.actionIntent != null })
                assertTrue(it.notification.extras.getCharSequence(android.app.Notification.EXTRA_BIG_TEXT).toString().isNotBlank())
            }
        } finally {
            manager.activeNotifications.filter { it.notification.channelId == "breviario_daily" }.forEach { manager.cancel(it.id) }
        }
    }
    /** Pending reviews of a saved dossier are scheduled; the posted reminder opens the saved dossier. */
    @Test
    fun savedDossierRemindersAreScheduledAndPosted() {
        val instrumentation = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            instrumentation.uiAutomation.grantRuntimePermission(context.packageName, android.Manifest.permission.POST_NOTIFICATIONS)
        }
        val config = DossierAnalysis.loadConfig(context)
        val store = SavedDossierStore(context)
        val saved = SavedDossier(UUID.randomUUID().toString(), "Lembrete de teste", null, null, "", "",
            java.time.LocalDate.now().toString(), listOf(0, 1))
        val manager = context.getSystemService(android.app.NotificationManager::class.java)
        try {
            store.save(saved)
            DossierReminders.schedule(context, saved, config)
            assertFalse("Review of today at 09:00 may be past; completed ones are never scheduled", DossierReminders.isScheduled(context, saved, 1))
            assertTrue(DossierReminders.isScheduled(context, saved, 3))
            assertTrue(DossierReminders.isScheduled(context, saved, 21))

            DossierReviewReceiver().onReceive(context, android.content.Intent().setData(
                DossierReminders.uri(saved.id).buildUpon().appendQueryParameter("dias", "3").build()).putExtra("tarefa", "Tarefa 3"))
            val deadline = android.os.SystemClock.elapsedRealtime() + 5_000
            while (manager.activeNotifications.none { it.notification.channelId == "dossie_revisao" } && android.os.SystemClock.elapsedRealtime() < deadline) {
                Thread.sleep(100)
            }
            val posted = manager.activeNotifications.single { it.notification.channelId == "dossie_revisao" }
            assertEquals("Revisão do dossiê: Lembrete de teste", posted.notification.extras.getCharSequence(android.app.Notification.EXTRA_TITLE).toString())
            assertTrue(posted.notification.actions.orEmpty().any { it.title.toString() == "Abrir dossiê" && it.actionIntent != null })

            // A completed review no longer notifies, even if its alarm fires.
            manager.cancel(posted.id)
            store.save(saved.toggled(3))
            DossierReviewReceiver().onReceive(context, android.content.Intent().setData(
                DossierReminders.uri(saved.id).buildUpon().appendQueryParameter("dias", "3").build()))
            Thread.sleep(300)
            assertTrue(manager.activeNotifications.none { it.notification.channelId == "dossie_revisao" })

            DossierReminders.cancel(context, saved, config)
            assertFalse(DossierReminders.isScheduled(context, saved, 21))
        } finally {
            DossierReminders.cancel(context, saved, config)
            store.remove(saved.id)
            manager.activeNotifications.filter { it.notification.channelId == "dossie_revisao" }.forEach { manager.cancel(it.id) }
        }
    }

    @Test
    fun sharedGoldenCasesMatchSearchAndFootnotes() {
        val cases = org.json.JSONObject(context.assets.open("casos_comuns_v1.json").bufferedReader().use { it.readText() })
        assertEquals(1, cases.getInt("schemaVersion"))
        val searches = cases.getJSONArray("search")
        for (index in 0 until searches.length()) {
            val case = searches.getJSONObject(index)
            assertEquals(case.getString("id"), case.getBoolean("matches"), TextoFormatter.corresponde(case.getString("query"), case.getString("text")))
        }
        val notes = cases.getJSONArray("superscript")
        for (index in 0 until notes.length()) {
            val case = notes.getJSONObject(index)
            assertEquals(case.getString("id"), case.getString("expected"), TextoFormatter.sobrescrito(case.getString("text"), case.getString("notes")))
        }
        val studies = cases.getJSONArray("study")
        for (index in 0 until studies.length()) {
            val case = studies.getJSONObject(index)
            val words = case.getJSONArray("keywords")
            assertEquals(case.getString("id"), case.getBoolean("matches"), StudyRules.matches(case.getString("text"), List(words.length()) { words.getString(it) }))
        }
    }

    @Test
    fun geminiRejectsPartialResponsesAndKeepsAllPublicParts() {
        val full = """{"candidates":[{"finishReason":"STOP","content":{"parts":[{"text":"Interno","thought":true},{"text":"Primeira parte [F1]."},{"text":"Segunda parte [F2]."}]}}]}"""
        assertEquals("Primeira parte [F1].\nSegunda parte [F2].", GeminiService.extrairRespostaCompleta(full))
        for (reason in listOf("MAX_TOKENS", "SAFETY", "RECITATION", "OTHER")) {
            assertTrue(runCatching { GeminiService.extrairRespostaCompleta(full.replace("STOP", reason)) }.isFailure)
        }
    }

    @Test
    fun studySelectionKeepsWorksWithSameDateSeparate() {
        val a = original.copy(obraId = "a", texto = "ética")
        val b = original.copy(obraId = "b", texto = "história")
        val texts = mapOf(a.chavePersistencia to a.texto, b.chavePersistencia to b.texto)
        assertEquals(listOf("a"), StudyRules.select(listOf(b, a), listOf("etica"), texts, 24).map { it.obraId })
        assertEquals(listOf("a"), StudyRules.select(listOf(b, a), listOf("etica", "historia"), texts, 1).map { it.obraId })
    }

    @Test
    fun sharedStudySelectionIsIndependentOfBatchSizeAndOrder() {
        val fixture = org.json.JSONObject(context.assets.open("casos_comuns_v1.json").bufferedReader().use { it.readText() }).getJSONObject("studySelection")
        val rows = fixture.getJSONArray("items")
        val items = List(rows.length()) { index -> rows.getJSONObject(index).let {
            BreviarioItem(it.getInt("page"), it.getString("date"), it.getString("title"), "", it.getString("body"), it.getString("notes"), it.getInt("page"), it.getString("work"))
        } }
        val texts = items.mapIndexed { index, item -> item.chavePersistencia to listOf(item.titulo, item.texto, item.rodape, rows.getJSONObject(index).getString("index")).joinToString(" ") }.toMap()
        val words = fixture.getJSONArray("keywords").let { array -> List(array.length()) { array.getString(it) } }
        val expected = fixture.getJSONArray("expected").let { array -> List(array.length()) { array.getString(it) } }
        val limit = fixture.getInt("limit")
        for (order in listOf(items, items.reversed())) for (size in listOf(1, 2, 3, 8)) {
            var selected = emptyList<BreviarioItem>()
            for (batch in order.chunked(size)) {
                selected = StudyRules.incorporate(selected, batch + batch, words, texts, limit)
                assertTrue(selected.size <= limit)
            }
            assertEquals(expected, selected.map { it.chavePersistencia })
            assertEquals(selected, StudyRules.incorporateNormalized(emptyList(), items,
                words.map { StudyRules.studyNormalized(it) },
                texts.mapValues { StudyRules.studyNormalized(it.value) }, limit).map { it.item })
            assertEquals("578 Estudo da ÉTICA.", selected.first { it.chavePersistencia == "a_P2" }.rodape)
        }
        assertTrue(StudyRules.select(items, words, texts, 0).isEmpty())
    }

    @Test
    fun studyPageBatchesKeepNotesScopeAndCancellation() {
        RagSQLite.open(":memory:").use { db ->
            db.execSQL("CREATE TABLE rag_obras(id TEXT PRIMARY KEY, autor TEXT)")
            db.execSQL("CREATE TABLE rag_paginas(obra_id TEXT, numero_original INTEGER, titulo TEXT, texto_integral TEXT)")
            db.execSQL("CREATE TABLE rag_notas(obra_id TEXT, pagina INTEGER, numero TEXT, texto TEXT)")
            for (work in listOf("a", "b")) {
                db.execSQL("INSERT INTO rag_obras VALUES (?, ?)", arrayOf(work, "Autor"))
                for (page in 1..5) {
                    db.execSQL("INSERT INTO rag_paginas VALUES (?, ?, ?, ?)", arrayOf(work, page, "Titulo", "Integral $work $page"))
                    db.execSQL("INSERT INTO rag_notas VALUES (?, ?, ?, ?)", arrayOf(work, page, "578", "Nota $work $page"))
                }
            }
            val batches = mutableListOf<List<BreviarioItem>>()
            percorrerItensEstudo(db, "a", tamanhoLote = 2) { batches.add(it); true }
            assertEquals(listOf(2, 2, 1), batches.map { it.size })
            assertEquals((1..5).toList(), batches.flatten().map { it.pagina })
            batches.flatten().forEach { assertEquals("a", it.obraId); assertEquals("578 Nota a ${it.pagina}", it.rodape); assertEquals("Integral a ${it.pagina}", it.texto) }
            var calls = 0
            percorrerItensEstudo(db, "a", tamanhoLote = 1) { calls++; false }
            assertEquals(1, calls)
            percorrerItensEstudo(db, "a", cancelled = { true }) { error("Cancelled job must not deliver a batch") }
        }
    }

    @Test
    fun searchPaginationKeepsRepeatedBlocksBeyondOldLimit() {
        val root = File(context.cacheDir, "paged-search-${UUID.randomUUID()}")
        val isolated = object : ContextWrapper(context) {
            override fun getFilesDir() = root
            override fun getApplicationContext(): Context = this
        }
        try {
            val folder = File(root, "RAGPackages").apply { mkdirs() }
            File(folder, "imported_works.json").writeText("""[{"id":"scope_a","title":"Scope A","area":"bibliotecaMaconica","pages":1,"databaseFile":"test.sqlite"}]""")
            RagSQLite.open(File(folder, "test.sqlite").path).use { db ->
                db.execSQL("CREATE TABLE rag_obras(id TEXT PRIMARY KEY, titulo TEXT, area TEXT)")
                db.execSQL("CREATE TABLE rag_paragrafos(id INTEGER PRIMARY KEY, obra_id TEXT, pagina INTEGER, texto TEXT)")
                db.execSQL("CREATE TABLE rag_notas(obra_id TEXT, pagina INTEGER, numero TEXT, texto TEXT)")
                db.execSQL("INSERT INTO rag_notas VALUES ('scope_a', 1, '578', 'Nota da obra A')")
                db.execSQL("INSERT INTO rag_notas VALUES ('scope_b', 1, '578', 'Nota de outra obra')")
                db.execSQL("CREATE VIRTUAL TABLE rag_fts USING fts5(bloco_id UNINDEXED, texto)")
                db.execSQL("INSERT INTO rag_obras VALUES ('scope_a', 'Scope A', 'bibliotecaMaconica')")
                for (id in 1..137) {
                    db.execSQL("INSERT INTO rag_paragrafos VALUES (?, 'scope_a', 1, 'Simbolismo documental')", arrayOf(id))
                    db.execSQL("INSERT INTO rag_fts VALUES (?, 'Simbolismo documental')", arrayOf(id))
                }
            }
            val catalog = BibliotecaCatalogRepository(isolated)
            val all = catalog.buscarConteudo("simbolismo", obraId = "scope_a", limite = 200)
            val pages = listOf(0, 50, 100).flatMap { catalog.buscarConteudo("simbolismo", obraId = "scope_a", limite = 50, offset = it) }
            assertEquals(137, all.size)
            assertTrue(all.all { it.rodape == "578 Nota da obra A" })
            assertEquals(all.map { it.id }, pages.map { it.id })
            assertEquals(137, pages.map { it.id }.toSet().size)
            assertTrue(catalog.buscarConteudo("simbolismo", obraId = "missing").isEmpty())
            RagSQLite.open(File(folder, "test.sqlite").path).use { it.execSQL("DROP TABLE rag_fts") }
            assertTrue(runCatching { catalog.buscarConteudo("simbolismo", obraId = "scope_a") }.isFailure)
        } finally { root.deleteRecursively() }
    }

    @Test
    fun notesOnlySearchUsesCommonCasesAndInvalidatesCacheWithoutChangingOriginal() {
        val root = File(context.cacheDir, "notes-search-${UUID.randomUUID()}").apply { mkdirs() }
        val file = File(root, "source.sqlite")
        val index = com.renatocamargo.breviariomaconico.data.NotesSearchIndex
        try {
            RagSQLite.open(file.path).use { db ->
                db.execSQL("CREATE TABLE rag_obras(id TEXT PRIMARY KEY, titulo TEXT, area TEXT)")
                db.execSQL("CREATE TABLE rag_notas(obra_id TEXT, pagina INTEGER, numero TEXT, texto TEXT)")
                db.execSQL("INSERT INTO rag_obras VALUES ('notes', 'Notas', 'dicionariosMaconicos')")
                val cases = JSONObject(context.assets.open("casos_comuns_v1.json").bufferedReader().use { it.readText() }).getJSONArray("search")
                for (i in 0 until cases.length()) {
                    val item = cases.getJSONObject(i)
                    db.execSQL("DELETE FROM rag_notas")
                    db.execSQL("INSERT INTO rag_notas VALUES ('notes', 9, '578', ?)", arrayOf(item.getString("text")))
                    file.setLastModified(System.currentTimeMillis() + i * 1000)
                    val hits = index.search(file, root, TextoFormatter.consultaFTSSegura(item.getString("query")), null, "notes", 50)
                    assertEquals(item.getString("id"), if (item.getBoolean("matches")) 1 else 0, hits.size)
                    hits.firstOrNull()?.let { hit ->
                        assertEquals(9, hit.pagina)
                        assertTrue(hit.blocoId!!.startsWith("nota:"))
                        assertEquals("578 " + item.getString("text"), hit.trecho)
                    }
                }
                db.execSQL("DELETE FROM rag_notas")
                for (page in 1..137) db.execSQL("INSERT INTO rag_notas VALUES ('notes', ?, '578', 'Vocabulário exclusivo')", arrayOf(page))
            }
            val original = file.readBytes()
            val query = TextoFormatter.consultaFTSSegura("vocabulário")
            assertEquals(137, index.search(file, root, query, BibliotecaArea.Dicionarios, null, 200).size)
            assertTrue(index.search(file, root, query, BibliotecaArea.Biblioteca, null, 200).isEmpty())
            assertTrue(index.search(file, root, query, null, "other", 200).isEmpty())
            assertTrue(index.search(file, root, query, null, null, 200, setOf("notes")).isEmpty())
            assertTrue(runCatching { index.search(file, root, query, null, null, 200, cancelled = { true }) }.exceptionOrNull() is kotlinx.coroutines.CancellationException)
            assertArrayEquals(original, file.readBytes())
        } finally { root.deleteRecursively() }
    }

    @Test
    fun exportFixtureKeepsLongTextNotesAndSeparateCommentPages() {
        val fixture = File(context.filesDir, "paridade-exportacao-android.pdf")
        val item = original.copy(titulo = "Verificação visual de parágrafos, notas e paginação", texto =
            (1..45).joinToString("\n\n") { "Parágrafo $it. Estudo da maçonaria e formação para uma leitura integral. Chamada 578; data 01/06/2026; quantidade 1234. ".repeat(3) } + " FIMLEITURA",
            rodape = "578 NOTAINTEGRAL\n579 SEGUNDANOTAINTEGRAL")
        createPdf(fixture, listOf(item), mapOf(item.chavePersistencia to "COMENTARIOINTEGRAL\n\nComentário pessoal 578 preservado em nova página."), "Pessoa de teste")
        android.os.ParcelFileDescriptor.open(fixture, android.os.ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            android.graphics.pdf.PdfRenderer(descriptor).use { pdf ->
                assertTrue(pdf.pageCount > 3)
                for (index in 0 until pdf.pageCount) pdf.openPage(index).use { page ->
                    assertEquals(595, page.width)
                    assertEquals(842, page.height)
                }
            }
        }
    }

    @Test
    fun sharedStudyDefinitionsMatchIOSContract() {
        val rules = StudyRules.load(context)
        assertEquals(1, rules.version)
        assertEquals(9, rules.collections.size)
        assertEquals(7, rules.paths.size)
        assertEquals(24, rules.collectionLimit)
        assertEquals(18, rules.pathLimit)
        val source = context.assets.open("regras_estudo_v1.json").bufferedReader().use { org.json.JSONObject(it.readText()) }
        val collections = source.getJSONArray("colecoes")
        rules.collections.forEachIndexed { index, collection ->
            val original = collections.getJSONObject(index)
            assertEquals(original.getString("subtitulo"), collection.subtitle)
            assertEquals(original.getString("detalhe"), collection.detail)
            val topics = original.getJSONArray("topicos")
            assertEquals(List(topics.length()) { topics.getString(it) }, collection.topics)
        }
        val paths = source.getJSONArray("trilhas")
        rules.paths.forEachIndexed { index, path ->
            val original = paths.getJSONObject(index)
            assertEquals(original.getString("subtitulo"), path.subtitle)
            assertEquals(original.getString("instrucao"), path.instruction)
            assertEquals(original.getString("objetivo"), path.objective)
            assertEquals(original.getString("duracaoSugerida"), path.suggestedDuration)
            val stages = original.getJSONArray("etapas")
            assertEquals(List(stages.length()) { stages.getString(it) }, path.stages)
        }
    }

    @Test
    @androidx.test.filters.SdkSuppress(minSdkVersion = 35)
    fun pdfCoverUsesActualLegacyCommentAndCorrectPlural() {
        val file = File(context.cacheDir, "cover-comments-${UUID.randomUUID()}.pdf")
        try {
            val first = original.copy(texto = "Leitura de teste", rodape = "")
            val second = first.copy(data = "02/06")
            for (items in listOf(listOf(first), listOf(first, second))) {
                createPdf(file, items, mapOf(first.data to "COMENTARIOLEGADOINTEGRAL"))
                android.os.ParcelFileDescriptor.open(file, android.os.ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                    android.graphics.pdf.PdfRenderer(descriptor).use { pdf ->
                        pdf.openPage(0).use { cover ->
                            val label = if (items.size == 1) "com comentário salvo" else "com comentários salvos"
                            assertFalse(label, cover.searchText(label).isEmpty())
                        }
                        var commentsFound = 0
                        for (index in 1 until pdf.pageCount) pdf.openPage(index).use { page ->
                            commentsFound += page.searchText("COMENTARIOLEGADOINTEGRAL").size
                        }
                        assertEquals(1, commentsFound)
                    }
                }
            }
        } finally { file.delete() }
    }

    @Test
    @androidx.test.filters.SdkSuppress(minSdkVersion = 35)
    fun longPDFTitleAndSequentialNotesRemainSearchable() {
        val file = File(context.cacheDir, "long-title-${UUID.randomUUID()}.pdf")
        try {
            val title = "Título extenso para verificar a paginação integral. ".repeat(35) + " FIMTITULO"
            val notes = (1..80).joinToString("\n") { "$it Nota documental completa $it." } + " FIMNOTAS"
            val item = original.copy(titulo = title, texto = "LEITURAPRESERVADA", rodape = notes)
            createPdf(file, listOf(item), mapOf(item.chavePersistencia to "COMENTARIOPRESERVADO"))
            android.os.ParcelFileDescriptor.open(file, android.os.ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                android.graphics.pdf.PdfRenderer(descriptor).use { pdf ->
                    val positions = mutableMapOf<String, Int>()
                    for (index in 0 until pdf.pageCount) pdf.openPage(index).use { page ->
                        for (marker in listOf("FIMTITULO", "LEITURAPRESERVADA", "FIMNOTAS", "COMENTARIOPRESERVADO")) {
                            if (page.searchText(marker).isNotEmpty()) {
                                assertNull("Duplicated marker $marker", positions.put(marker, index))
                            }
                        }
                    }
                    assertEquals(4, positions.size)
                    assertTrue(positions.getValue("COMENTARIOPRESERVADO") > positions.getValue("FIMNOTAS"))
                }
            }
        } finally { file.delete() }
    }

    @Test
    fun corruptPDFDoesNotPublishPartialWork() = runBlocking {
        val file = File(context.cacheDir, "corrupt-${UUID.randomUUID()}.pdf")
        val before = LocalPdfOcrImporter.loadImported(context).map { it.id }.toSet()
        try {
            file.writeText("Not a PDF")
            assertTrue(runCatching { LocalPdfOcrImporter(context).import(Uri.fromFile(file), "Invalid", null, BibliotecaArea.Biblioteca) {} }.isFailure)
            assertEquals(before, LocalPdfOcrImporter.loadImported(context).map { it.id }.toSet())
        } finally { file.delete() }
        Unit
    }
    private val prefix = "audit_${UUID.randomUUID()}_"
    private val context = object : ContextWrapper(ApplicationProvider.getApplicationContext<Context>()) {
        override fun getSharedPreferences(name: String, mode: Int) =
            super.getSharedPreferences(prefix + name, mode)
    }
    private val raw get() = context.getSharedPreferences("breviario_prefs", Context.MODE_PRIVATE)
    private val original = BreviarioItem(1, "01/06", "Título", "Autor", "Texto", "Nota", 1)
    private val other = original.copy(obraId = "outra_obra")

    @After
    fun cleanup() {
        context.deleteSharedPreferences(prefix + "breviario_prefs")
        context.deleteSharedPreferences(prefix + "secure_secrets")
    }

    @Test
    fun legacyDataBelongsOnlyToOriginalWork() {
        raw.edit().putString("comment_01/06", "Comentário original")
            .putString("reflection_01/06", "Reflexão original")
            .putString("textEdit_01/06", "{\"text\":\"Edição original\"}")
            .putString("highlights_01/06", "[{\"id\":\"1\",\"text\":\"Destaque original\"}]")
            .putStringSet("favorites", setOf("01/06"))
            .putStringSet("readDates", setOf("01/06")).commit()
        val prefs = PreferencesStore(context)
        assertEquals("Comentário original", prefs.comment(original))
        assertTrue(prefs.isRead(original))
        assertTrue(prefs.isFavorite(original))
        assertEquals("", prefs.comment(other))
        assertEquals("", prefs.reflection(other))
        assertNull(prefs.textEdit(other))
        assertTrue(prefs.highlights(other).isEmpty())
        assertFalse(prefs.isRead(other))
        assertFalse(prefs.isFavorite(other))
        prefs.removeTextEdit(other)
        prefs.toggleRead(other)
        prefs.toggleFavorite(other)
        assertNotNull(prefs.textEdit(original))
        assertTrue(prefs.isRead(original))
        assertTrue(prefs.isFavorite(original))
    }

    @Test
    fun recentHistoryKeepsThreeVisitsPerWorkWithoutChangingProgress() {
        raw.edit().putStringSet("favorites", setOf("01/06"))
            .putStringSet("readDates", setOf("01/06"))
            .putString("libraryRecents", """[{"obraId":"legacy","title":"Legacy","area":"Biblioteca","page":7,"timestamp":1}]""").commit()
        val prefs = PreferencesStore(context)
        val readings = (1..6).flatMap { day ->
            listOf(original.copy(data = "%02d/06".format(day)), other.copy(data = "%02d/06".format(day)))
        }
        readings.forEach(prefs::markDailyRecent)
        prefs.markDailyRecent(readings.first())
        for (page in 1..6) {
            prefs.markLibraryRecent("a", "A", "Biblioteca", page)
            prefs.markLibraryRecent("b", "B", "Biblioteca", page)
        }
        prefs.markLibraryRecent("a", "A", "Biblioteca", 2)
        val restored = PreferencesStore(context)
        val recent = restored.recentDailyItems(readings)
        assertEquals(listOf("01/06", "06/06", "05/06"), recent.filter { it.obraId == original.obraId }.map { it.data })
        assertEquals(listOf("06/06", "05/06", "04/06"), recent.filter { it.obraId == other.obraId }.map { it.data })
        assertEquals(listOf(2, 6, 5, 4, 3), restored.libraryRecents().filter { it.obraId == "a" }.map { it.page })
        assertEquals(5, restored.libraryRecents().count { it.obraId == "b" })
        assertEquals(7, restored.libraryRecents().single { it.obraId == "legacy" }.page)
        assertTrue(restored.isRead(original))
        assertTrue(restored.isFavorite(original))
    }

    @Test
    fun persistedChangesSurviveRepositoryRecreation() {
        val prefs = PreferencesStore(context)
        prefs.saveComment(other, "Comentário integral")
        prefs.saveReflection(other, "Reflexão integral")
        prefs.saveTextEdit(other, "Título editado", "Texto editado", "578 Nota")
        prefs.toggleFavorite(other)
        val restored = PreferencesStore(context)
        assertEquals("Comentário integral", restored.comment(other))
        assertEquals("Reflexão integral", restored.reflection(other))
        assertEquals("578 Nota", restored.applyTextEdit(other).rodape)
        assertTrue(restored.isFavorite(other))
        assertEquals("", restored.comment(original))
    }

    @Test
    fun sqliteEngineSearchesFts5WithUserPunctuation() {
        RagSQLite.open(":memory:").use { db ->
            db.execSQL("CREATE VIRTUAL TABLE rag_fts USING fts5(texto)")
            db.execSQL("INSERT INTO rag_fts(texto) VALUES (?)", arrayOf("Grão mestre e símbolos da maçonaria"))
            listOf("grão-mestre", "símbolos", "OR", "NEAR()", "!!!", "\"").forEach { query ->
                db.rawQuery("SELECT texto FROM rag_fts WHERE rag_fts MATCH ?", arrayOf(TextoFormatter.consultaFTSSegura(query))).use { cursor ->
                    if (query == "grão-mestre" || query == "símbolos") assertTrue(cursor.moveToNext())
                    else assertFalse(cursor.moveToNext())
                }
            }
        }
    }

    @Test
    fun bundledDatabasePersistsUnicodeNotesAndReadOnlyMode() {
        val file = File(context.cacheDir, "audit-${UUID.randomUUID()}.sqlite")
        try {
            RagSQLite.open(file.path).use { db ->
                db.execSQL("CREATE TABLE notes (id INTEGER PRIMARY KEY, text TEXT NOT NULL, page INTEGER)")
                db.insert("notes", ContentValues().apply {
                    put("id", 578)
                    put("text", "Maçonaria, símbolo e nota integral")
                    putNull("page")
                })
            }
            RagSQLite.open(file.path, readOnly = true).use { db ->
                db.rawQuery("SELECT id, text FROM notes", emptyArray()).use { row ->
                    assertTrue(row.moveToNext())
                    assertEquals(578, row.getInt(0))
                    assertEquals("Maçonaria, símbolo e nota integral", row.getString(1))
                    assertFalse(row.moveToNext())
                }
                assertTrue(runCatching { db.execSQL("DELETE FROM notes") }.isFailure)
            }
        } finally { file.delete() }
    }

    @Test
    fun incompleteDownloadDoesNotReplaceInstalledWork() {
        val repo = BibliotecaCatalogRepository.get(context)
        val source = File(context.cacheDir, "audit-download-${UUID.randomUUID()}")
        val packageInfo = BibliotecaPacoteCatalogo(
            "audit", BibliotecaArea.Biblioteca, "Auditoria", "audit-${UUID.randomUUID()}.sqlite",
            source.toURI().toURL().toString(), 9999, null, 1, emptyList()
        )
        val destination = repo.localFile(packageInfo)
        destination.parentFile?.mkdirs()
        try {
            source.writeText("Incompleto")
            destination.writeText("Obra existente")
            assertTrue(runCatching { repo.instalar(packageInfo) }.isFailure)
            assertEquals("Obra existente", destination.readText())
            repo.instalar(packageInfo.copy(tamanhoBytes = source.length()))
            assertEquals("Incompleto", destination.readText())
        } finally {
            source.delete()
            destination.delete()
        }
    }

    @Test
    @androidx.test.filters.SdkSuppress(minSdkVersion = 35)
    fun landscapeMultiColumnImportKeepsPagesIllustrationsAndOriginal() = runBlocking {
        val pdf = File(context.cacheDir, "landscape-${UUID.randomUUID()}.pdf")
        val importer = LocalPdfOcrImporter(context)
        var importedId: String? = null
        try {
            val document = PdfDocument()
            try {
                for (number in 1..3) {
                    val page = document.startPage(PdfDocument.PageInfo.Builder(1200, 800, number).create())
                    page.canvas.drawColor(Color.WHITE)
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK; textSize = 30f }
                    page.canvas.drawText("LEFT COLUMN $number", 50f, 100f, paint)
                    page.canvas.drawText("RIGHT COLUMN $number", 650f, 100f, paint)
                    paint.color = Color.RED
                    page.canvas.drawRect(100f, 250f, 450f, 450f, paint)
                    paint.color = Color.BLUE
                    page.canvas.drawRect(700f, 250f, 1050f, 450f, paint)
                    paint.color = Color.BLACK
                    paint.strokeWidth = 3f
                    page.canvas.drawLine(50f, 650f, 1000f, 650f, paint)
                    page.canvas.drawText("578 Footnote preserved for study.", 50f, 710f, paint)
                    document.finishPage(page)
                }
                pdf.outputStream().use { document.writeTo(it) }
            } finally { document.close() }
            val imported = withTimeout(180_000) {
                importer.import(Uri.fromFile(pdf), "Audit landscape", "Test", BibliotecaArea.Biblioteca,
                    assuntos = listOf(" Ética ", "Filosofia", "Ética")) {}
            }
            importedId = imported.id
            val restored = LocalPdfOcrImporter.loadImported(context).single { it.id == imported.id }
            assertEquals(listOf("Ética", "Filosofia"), restored.assuntos)
            val hits = BibliotecaCatalogRepository.get(context).buscarConteudo("column", obraId = imported.id,
                filtro = LibraryMetadataFilter("Test", "etica"))
            assertFalse(hits.isEmpty())
            val pages = BibliotecaCatalogRepository.get(context).paginasDaObra(imported.id)
            assertEquals(3, pages.size)
            pages.forEachIndexed { index, page ->
                assertTrue(page.texto, page.texto.contains("LEFT COLUMN ${index + 1}"))
                assertTrue(page.texto, page.texto.contains("RIGHT COLUMN ${index + 1}"))
                assertTrue(page.rodape, page.rodape.contains("578"))
                val bitmap = android.graphics.BitmapFactory.decodeFile(page.imagens.single())!!
                try {
                    assertTrue(bitmap.width > bitmap.height)
                    val red = bitmap.getPixel(bitmap.width / 4, bitmap.height * 7 / 16)
                    val blue = bitmap.getPixel(bitmap.width * 3 / 4, bitmap.height * 7 / 16)
                    assertTrue(Color.red(red) > 240 && Color.blue(red) < 15)
                    assertTrue(Color.blue(blue) > 240 && Color.red(blue) < 15)
                } finally { bitmap.recycle() }
                assertArrayEquals(pdf.readBytes(), File(File(page.imagens.single()).parentFile, "original.pdf").readBytes())
                val geometry = org.json.JSONObject(File(File(page.imagens.single()).parentFile, "page_${index + 1}.json").readText())
                assertEquals("pdfTextLayer", geometry.getString("textSource"))
            }
        } finally { importedId?.let { importer.remove(it) }; pdf.delete() }
        Unit
    }

    @Test
    fun localPdfImportCreatesReadableSearchableWorkAndPageImage() = runBlocking {
        val pdf = File(context.cacheDir, "audit-${UUID.randomUUID()}.pdf")
        val importer = LocalPdfOcrImporter(context)
        var importedId: String? = null
        try {
            val document = PdfDocument()
            try {
                val page = document.startPage(PdfDocument.PageInfo.Builder(800, 1000, 1).create())
                val bitmap = android.graphics.Bitmap.createBitmap(800, 1000, android.graphics.Bitmap.Config.ARGB_8888)
                try {
                val canvas = android.graphics.Canvas(bitmap)
                canvas.drawColor(Color.WHITE)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK; textSize = 30f }
                canvas.drawText("MASONRY STUDY", 70f, 110f, paint)
                canvas.drawText("Integral reading for a library audit.", 70f, 180f, paint)
                paint.strokeWidth = 3f
                canvas.drawLine(70f, 820f, 600f, 820f, paint)
                paint.textSize = 24f
                canvas.drawText("578 Footnote preserved for study.", 70f, 875f, paint)
                page.canvas.drawBitmap(bitmap, 0f, 0f, null)
                } finally { bitmap.recycle() }
                document.finishPage(page)
                pdf.outputStream().use { document.writeTo(it) }
            } finally {
                document.close()
            }
            val imported = withTimeout(120_000) {
                importer.import(Uri.fromFile(pdf), "Audit OCR", "Test", BibliotecaArea.Biblioteca) {}
            }
            importedId = imported.id
            val repo = BibliotecaCatalogRepository.get(context)
            val pages = repo.paginasDaObra(imported.id)
            assertEquals(1, pages.size)
            assertTrue(pages.single().texto.contains("STUDY", ignoreCase = true))
            assertTrue(pages.single().rodape.contains("578"))
            assertTrue(pages.single().imagens.isNotEmpty())
            val imageFolder = File(pages.single().imagens.first()).parentFile!!
            assertArrayEquals(pdf.readBytes(), File(imageFolder, "original.pdf").readBytes())
            val geometry = org.json.JSONObject(File(imageFolder, "page_1.json").readText())
            assertEquals(1, geometry.getInt("schemaVersion"))
            assertEquals("ocr", geometry.getString("textSource"))
            assertTrue(geometry.getJSONArray("blocks").length() > 0)
            assertTrue(repo.buscarConteudo("study", obraId = imported.id).isNotEmpty())
            // The same PDF again, under another title, is refused: no second copy of the work.
            val before = LocalPdfOcrImporter.loadImported(context).map { it.id }
            val again = runCatching { importer.import(Uri.fromFile(pdf), "Audit OCR again", null, BibliotecaArea.Biblioteca) {} }
            assertEquals("Este PDF já foi importado como “Audit OCR”.", (again.exceptionOrNull() as? DuplicatePdfException)?.message)
            assertEquals(before, LocalPdfOcrImporter.loadImported(context).map { it.id })
        } finally {
            importedId?.let { importer.remove(it) }
            pdf.delete()
        }
        Unit
    }
}
