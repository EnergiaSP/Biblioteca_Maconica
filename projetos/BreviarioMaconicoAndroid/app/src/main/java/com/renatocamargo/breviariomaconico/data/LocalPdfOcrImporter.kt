package com.renatocamargo.breviariomaconico.data

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.RectF
import android.os.Build
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.util.AtomicFile
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.text.Normalizer
import java.util.UUID

data class PdfOcrProgress(val currentPage: Int, val totalPages: Int, val message: String)

data class ImportedPdfWork(
    val id: String,
    val title: String,
    val author: String?,
    val area: BibliotecaArea,
    val pages: Int,
    val databaseFile: String,
    val assuntos: List<String> = emptyList()
)

class LocalPdfOcrImporter(private val context: Context) {
    private data class PageTextBlock(val text: String, val boundingBox: RectF?)
    private val root = File(context.filesDir, "RAGPackages")
    private val manifestFile = File(root, "imported_works.json")

    suspend fun import(
        uri: Uri,
        title: String,
        author: String?,
        area: BibliotecaArea,
        assuntos: List<String> = emptyList(),
        onProgress: (PdfOcrProgress) -> Unit
    ): ImportedPdfWork = withContext(Dispatchers.IO) {
        suspend fun report(progress: PdfOcrProgress) {
            withContext(Dispatchers.Main.immediate) { onProgress(progress) }
        }

        require(title.isNotBlank()) { "Informe o título da obra." }
        val topics = assuntos.map(String::trim).filter(String::isNotEmpty).distinct()
        root.mkdirs()
        val id = newWorkId(title)
        val dbFile = File(root, "imported_$id.sqlite")
        val imageDir = File(root, "imported_${id}_images").apply { mkdirs() }
        val original = File(imageDir, "original.pdf")
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        var committed = false

        try {
            requireNotNull(context.contentResolver.openInputStream(uri)).use { input ->
                original.outputStream().use { output -> input.copyTo(output); output.fd.sync() }
            }
            android.os.ParcelFileDescriptor.open(original, android.os.ParcelFileDescriptor.MODE_READ_ONLY).use { pdfDescriptor ->
                requireNotNull(pdfDescriptor)
                PdfRenderer(pdfDescriptor).use { renderer ->
                    require(renderer.pageCount > 0) { "PDF sem páginas legíveis." }
                    val db = RagSQLite.open(dbFile.absolutePath)
                    try {
                        db.execSQL("BEGIN IMMEDIATE")
                        createSchema(db)
                        insertWork(db, id, title.trim(), author?.trim(), area, topics)
                        for (index in 0 until renderer.pageCount) {
                            currentCoroutineContext().ensureActive()
                            report(PdfOcrProgress(index + 1, renderer.pageCount, "Reconhecendo página ${index + 1}"))
                            renderer.openPage(index).use { page ->
                                require(page.width > 0 && page.height > 0) { "Dimensões de página inválidas." }
                                val scale = minOf(1800.0 / page.width, kotlin.math.sqrt(6_000_000.0 / (page.width.toDouble() * page.height)), 2.5).toFloat()
                                val bitmap = Bitmap.createBitmap(
                                    (page.width * scale).toInt().coerceAtLeast(1),
                                    (page.height * scale).toInt().coerceAtLeast(1),
                                    Bitmap.Config.ARGB_8888
                                )
                                try {
                                bitmap.eraseColor(android.graphics.Color.WHITE)
                                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                val nativeBlocks = nativeTextBlocks(page, bitmap)
                                val textBlocks = if (nativeBlocks.isNotEmpty()) nativeBlocks else {
                                    recognizer.process(InputImage.fromBitmap(bitmap, 0)).await().textBlocks.map {
                                        PageTextBlock(it.text, it.boundingBox?.let(::RectF))
                                    }
                                }
                                val pageNumber = index + 1
                                val boundary = detectFootnoteDivider(bitmap) ?: bitmap.height
                                val mainBlocks = textBlocks.filter { (it.boundingBox?.top ?: 0f) < boundary }
                                val footBlocks = textBlocks.filter { (it.boundingBox?.top ?: 0f) >= boundary }
                                val paragraphs = mainBlocks.map { it.text.trim() }.filter { it.isNotBlank() }
                                val fullText = paragraphs.joinToString("\n\n")
                                val blocks = JSONArray()
                                textBlocks.forEach { block ->
                                    blocks.put(JSONObject().apply {
                                        put("text", block.text)
                                        block.boundingBox?.let { box ->
                                            put("x", box.left.toDouble() / bitmap.width); put("y", box.top.toDouble() / bitmap.height)
                                            put("width", box.width().toDouble() / bitmap.width); put("height", box.height().toDouble() / bitmap.height)
                                        }
                                    })
                                }
                                File(imageDir, "page_${pageNumber}.json").writeText(JSONObject().apply {
                                    put("schemaVersion", 1); put("page", pageNumber); put("originalWidth", page.width); put("originalHeight", page.height)
                                    put("rawText", textBlocks.joinToString("\n") { it.text }); put("blocks", blocks); put("footnoteDividerDetected", boundary < bitmap.height)
                                    put("textSource", if (nativeBlocks.isNotEmpty()) "pdfTextLayer" else "ocr")
                                    put("reviewRequired", true)
                                }.toString())
                                insertPage(db, id, pageNumber, fullText)
                                insertParagraphs(db, id, pageNumber, paragraphs)
                                insertFootnotes(db, id, pageNumber, footBlocks.map { it.text.trim() }.filter { it.isNotBlank() })

                                val imageFile = File(imageDir, "page_${pageNumber}.jpg")
                                FileOutputStream(imageFile).use { output ->
                                    check(bitmap.compress(Bitmap.CompressFormat.JPEG, 82, output)) { "Não foi possível preservar a imagem da página $pageNumber." }
                                    output.fd.sync()
                                }
                                insertImage(db, id, pageNumber, "${imageDir.name}/${imageFile.name}")
                                } finally { bitmap.recycle() }
                            }
                        }
                        db.execSQL("INSERT INTO rag_fts(bloco_id, texto) SELECT id, texto FROM rag_paragrafos")
                        db.execSQL("COMMIT")
                        saveManifest(ImportedPdfWork(id, title.trim(), author?.trim(), area, renderer.pageCount, dbFile.name, topics))
                        committed = true
                        report(PdfOcrProgress(renderer.pageCount, renderer.pageCount, "Importação concluída"))
                        ImportedPdfWork(id, title.trim(), author?.trim(), area, renderer.pageCount, dbFile.name, topics)
                    } catch (error: Throwable) {
                        runCatching { db.execSQL("ROLLBACK") }
                        throw error
                    } finally {
                        db.close()
                    }
                }
            }
        } catch (error: Throwable) {
            if (!committed) {
                dbFile.delete()
                imageDir.deleteRecursively()
            }
            throw error
        } finally {
            recognizer.close()
        }
    }

    private fun nativeTextBlocks(page: PdfRenderer.Page, bitmap: Bitmap): List<PageTextBlock> {
        if (Build.VERSION.SDK_INT < 35) return emptyList()
        val scaleX = bitmap.width.toFloat() / page.width
        val scaleY = bitmap.height.toFloat() / page.height
        fun scaled(rect: RectF) = RectF(rect.left * scaleX, rect.top * scaleY, rect.right * scaleX, rect.bottom * scaleY)
        fun union(rects: List<RectF>): RectF? = rects.firstOrNull()?.let { first ->
            RectF(first).apply { rects.drop(1).forEach { union(it) } }
        }
        val occurrences = mutableMapOf<String, Int>()
        return page.textContents.flatMap { content ->
            val lines = content.text.lineSequence().filter { it.isNotBlank() }.toList()
            val bounds = content.bounds
            if (bounds.isEmpty()) {
                // Some Android PDF engines return native text without its positions.
                // Locate each occurrence in the same PDF, without re-recognizing its characters.
                lines.map { text ->
                    val occurrence = occurrences[text] ?: 0
                    occurrences[text] = occurrence + 1
                    val rects = page.searchText(text).getOrNull(occurrence)?.bounds.orEmpty()
                    PageTextBlock(text, union(rects)?.let(::scaled))
                }
            } else if (lines.size == bounds.size) {
                lines.zip(bounds).map { (text, rect) -> PageTextBlock(text, scaled(rect)) }
            } else if (content.text.isNotBlank()) {
                // Keep unaligned native content intact rather than guessing a text-to-position mapping.
                listOf(PageTextBlock(content.text, union(bounds)?.let(::scaled)))
            } else emptyList()
        }
    }

    fun remove(workId: String) = synchronized(manifestLock) {
        val works = loadImported(context)
        val selected = works.firstOrNull { it.id == workId } ?: return
        val remaining = works.filterNot { it.id == workId }
        val array = JSONArray()
        remaining.forEach { work ->
            array.put(JSONObject().apply {
                put("id", work.id); put("title", work.title); put("author", work.author)
                put("area", work.area.raw); put("pages", work.pages); put("databaseFile", work.databaseFile)
            })
        }
        writeManifest(array)
        File(root, selected.databaseFile).delete()
        File(root, "imported_${workId}_images").deleteRecursively()
        Unit
    }

    private fun createSchema(db: RagSQLite) {
        db.execSQL("CREATE TABLE rag_obras(id TEXT PRIMARY KEY, titulo TEXT NOT NULL, autor TEXT, area TEXT NOT NULL, assuntos_json TEXT NOT NULL)")
        db.execSQL("CREATE TABLE rag_paginas(id INTEGER PRIMARY KEY AUTOINCREMENT, obra_id TEXT NOT NULL, numero_original INTEGER NOT NULL, titulo TEXT, texto_integral TEXT NOT NULL)")
        db.execSQL("CREATE TABLE rag_paragrafos(id INTEGER PRIMARY KEY AUTOINCREMENT, obra_id TEXT NOT NULL, pagina INTEGER NOT NULL, texto TEXT NOT NULL)")
        db.execSQL("CREATE TABLE rag_notas(id INTEGER PRIMARY KEY AUTOINCREMENT, obra_id TEXT NOT NULL, pagina INTEGER NOT NULL, numero TEXT, texto TEXT NOT NULL)")
        db.execSQL("CREATE TABLE rag_imagens(id INTEGER PRIMARY KEY AUTOINCREMENT, obra_id TEXT NOT NULL, pagina INTEGER NOT NULL, caminho_relativo TEXT NOT NULL)")
        db.execSQL("CREATE VIRTUAL TABLE rag_fts USING fts5(bloco_id UNINDEXED, texto, tokenize='unicode61 remove_diacritics 2')")
        db.execSQL("CREATE INDEX idx_paginas_obra ON rag_paginas(obra_id, numero_original)")
        db.execSQL("CREATE INDEX idx_paragrafos_obra ON rag_paragrafos(obra_id, pagina)")
    }

    private fun insertWork(db: RagSQLite, id: String, title: String, author: String?, area: BibliotecaArea, topics: List<String>) {
        db.insert("rag_obras", ContentValues().apply {
            put("assuntos_json", JSONArray(topics).toString())
            put("id", id); put("titulo", title); put("autor", author); put("area", area.raw)
        })
    }

    private fun insertPage(db: RagSQLite, workId: String, page: Int, text: String) {
        db.insert("rag_paginas", ContentValues().apply {
            put("obra_id", workId); put("numero_original", page); put("titulo", "Página $page"); put("texto_integral", text)
        })
    }

    private fun insertParagraphs(db: RagSQLite, workId: String, page: Int, paragraphs: List<String>) {
        paragraphs.forEach { text -> db.insert("rag_paragrafos", ContentValues().apply {
            put("obra_id", workId); put("pagina", page); put("texto", text)
        }) }
    }

    private fun insertFootnotes(db: RagSQLite, workId: String, page: Int, notes: List<String>) {
        notes.forEach { raw ->
            val match = Regex("^([0-9]{1,4})[.)\\s-]+(.*)$", RegexOption.DOT_MATCHES_ALL).find(raw)
            db.insert("rag_notas", ContentValues().apply {
                put("obra_id", workId); put("pagina", page)
                put("numero", match?.groupValues?.get(1) ?: "")
                put("texto", match?.groupValues?.get(2)?.trim() ?: raw)
            })
        }
    }

    private fun insertImage(db: RagSQLite, workId: String, page: Int, relativePath: String) {
        db.insert("rag_imagens", ContentValues().apply {
            put("obra_id", workId); put("pagina", page); put("caminho_relativo", relativePath)
        })
    }

    private fun detectFootnoteDivider(bitmap: Bitmap): Int? {
        val width = bitmap.width
        val startY = (bitmap.height * 0.45).toInt()
        val endY = (bitmap.height * 0.94).toInt()
        val minimumDarkRun = (width * 0.42).toInt()
        val row = IntArray(width)
        var best: Int? = null

        for (y in startY until endY) {
            bitmap.getPixels(row, 0, width, 0, y, width, 1)
            var run = 0
            var longest = 0
            for (pixel in row) {
                val red = android.graphics.Color.red(pixel)
                val green = android.graphics.Color.green(pixel)
                val blue = android.graphics.Color.blue(pixel)
                if (red + green + blue < 210) {
                    run++
                    if (run > longest) longest = run
                } else {
                    run = 0
                }
            }
            if (longest >= minimumDarkRun) best = y
        }
        return best
    }

    private fun saveManifest(work: ImportedPdfWork) = synchronized(manifestLock) {
        val atomic = AtomicFile(manifestFile)
        val array = if (manifestFile.exists() || File(manifestFile.path + ".bak").exists()) JSONArray(String(atomic.readFully(), Charsets.UTF_8)) else JSONArray()
        array.put(JSONObject().apply {
            put("id", work.id); put("title", work.title); put("author", work.author)
            put("area", work.area.raw); put("pages", work.pages); put("databaseFile", work.databaseFile)
            put("assuntos", JSONArray(work.assuntos))
        })
        writeManifest(array)
    }

    private fun writeManifest(array: JSONArray) {
        val atomic = AtomicFile(manifestFile)
        val output = atomic.startWrite()
        try {
            output.write(array.toString(2).toByteArray(Charsets.UTF_8))
            atomic.finishWrite(output)
        } catch (error: Throwable) {
            atomic.failWrite(output)
            throw error
        }
    }

    companion object {
        private val manifestLock = Any()

        fun loadImported(context: Context): List<ImportedPdfWork> = synchronized(manifestLock) {
            val file = File(context.filesDir, "RAGPackages/imported_works.json")
            if (!file.exists() && !File(file.path + ".bak").exists()) return emptyList()
            return runCatching {
                val array = JSONArray(String(AtomicFile(file).readFully(), Charsets.UTF_8))
                List(array.length()) { index ->
                    val item = array.getJSONObject(index)
                    ImportedPdfWork(
                        item.getString("id"), item.getString("title"), item.optString("author").ifBlank { null },
                        BibliotecaArea.from(item.getString("area")), item.getInt("pages"), item.getString("databaseFile"),
                        item.optJSONArray("assuntos")?.let { topics -> List(topics.length()) { topics.getString(it) } }.orEmpty()
                    )
                }
            }.getOrDefault(emptyList())
        }

        internal fun newWorkId(title: String): String = slug(title).take(80).ifBlank { "importada" } + "_" + UUID.randomUUID()

        private fun slug(value: String): String = Normalizer.normalize(value, Normalizer.Form.NFD)
            .replace(Regex("\\p{M}+"), "").lowercase().replace(Regex("[^a-z0-9]+"), "_").trim('_')
    }
}
