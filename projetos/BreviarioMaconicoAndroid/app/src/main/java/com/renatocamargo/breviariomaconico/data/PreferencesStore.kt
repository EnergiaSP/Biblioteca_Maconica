package com.renatocamargo.breviariomaconico.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class PreferencesStore(context: Context) {
    private val prefs = context.getSharedPreferences("breviario_prefs", Context.MODE_PRIVATE)
    private val secureKeyStore = SecureKeyStore(context)

    init {
        val legacyKey = prefs.getString("geminiApiKey", "").orEmpty()
        if (legacyKey.isNotBlank() && secureKeyStore.loadGeminiKey().isBlank()) {
            secureKeyStore.saveGeminiKey(legacyKey)
        }
        if (prefs.contains("geminiApiKey")) {
            prefs.edit().remove("geminiApiKey").apply()
        }
    }

    var activated: Boolean
        get() = prefs.getBoolean("activated", false)
        set(value) = prefs.edit().putBoolean("activated", value).apply()

    var settings: ReaderSettings
        get() = ReaderSettings(
            theme = runCatching {
                AppThemeMode.valueOf(prefs.getString("theme", AppThemeMode.Dark.name) ?: AppThemeMode.Dark.name)
            }.getOrDefault(AppThemeMode.Dark),
            fontSize = prefs.getFloat("fontSize", 18f),
            lineSpacing = prefs.getFloat("lineSpacing", 8f),
            voiceGender = prefs.getString("voiceGender", "Feminina") ?: "Feminina",
            voiceSpeed = prefs.getFloat("voiceSpeed", 0.9f),
            distractionFreeMode = prefs.getBoolean("distractionFreeMode", false),
            premiumPdfName = prefs.getString("premiumPdfName", "") ?: "",
            libraryContinuousMode = prefs.getBoolean("libraryContinuousMode", true),
            aiEnabled = prefs.getBoolean("aiEnabled", false),
            geminiApiKey = secureKeyStore.loadGeminiKey(),
            dailyNotificationEnabled = prefs.getBoolean("dailyNotificationEnabled", false),
            notificationHour = prefs.getInt("notificationHour", 8),
            notificationMinute = prefs.getInt("notificationMinute", 0),
            notificationWorkIds = prefs.getStringSet(
                "notificationWorkIds",
                setOf(ObraId.BREVIARIO_SECULO_XXI)
            ) ?: setOf(ObraId.BREVIARIO_SECULO_XXI)
        )
        set(value) {
            prefs.edit()
                .putString("theme", value.theme.name)
                .putFloat("fontSize", value.fontSize)
                .putFloat("lineSpacing", value.lineSpacing)
                .putString("voiceGender", value.voiceGender)
                .putFloat("voiceSpeed", value.voiceSpeed)
                .putBoolean("distractionFreeMode", value.distractionFreeMode)
                .putString("premiumPdfName", value.premiumPdfName)
                .putBoolean("libraryContinuousMode", value.libraryContinuousMode)
                .putBoolean("aiEnabled", value.aiEnabled)
                .putBoolean("dailyNotificationEnabled", value.dailyNotificationEnabled)
                .putInt("notificationHour", value.notificationHour)
                .putInt("notificationMinute", value.notificationMinute)
                .putStringSet("notificationWorkIds", value.notificationWorkIds)
                .apply()
            secureKeyStore.saveGeminiKey(value.geminiApiKey)
        }

    fun favorites(): Set<String> = prefs.getStringSet("favorites", emptySet()) ?: emptySet()
    fun readDates(): Set<String> = prefs.getStringSet("readDates", emptySet()) ?: emptySet()

    fun isFavorite(item: BreviarioItem): Boolean =
        favorites().contains(item.chavePersistencia) || legacyDate(item)?.let { it in favorites() } == true

    fun isRead(item: BreviarioItem): Boolean =
        readDates().contains(item.chavePersistencia) || legacyDate(item)?.let { it in readDates() } == true

    fun favoriteItems(items: List<BreviarioItem>): List<BreviarioItem> =
        items.filter { isFavorite(it) }

    fun readItems(items: List<BreviarioItem>): List<BreviarioItem> =
        items.filter { isRead(it) }

    fun unreadItems(items: List<BreviarioItem>): List<BreviarioItem> =
        items.filterNot { isRead(it) }

    fun commentedItems(items: List<BreviarioItem>): List<BreviarioItem> =
        items.filter { comment(it).isNotBlank() }

    fun toggleFavorite(item: BreviarioItem) = toggleSet("favorites", item.chavePersistencia, legacyDate(item))
    fun toggleRead(item: BreviarioItem) = toggleSet("readDates", item.chavePersistencia, legacyDate(item))

    private fun legacyDate(item: BreviarioItem): String? =
        item.data.takeIf { item.obraId == ObraId.BREVIARIO_SECULO_XXI }

    private fun savedText(prefix: String, item: BreviarioItem): String? =
        prefs.getString("${prefix}_${item.chavePersistencia}", null)
            ?: legacyDate(item)?.let { prefs.getString("${prefix}_$it", null) }

    fun setRead(obraId: String, date: String, read: Boolean) {
        val key = "${obraId}_$date"
        val values = readDates().toMutableSet()
        if (read) values.add(key) else {
            values.remove(key)
            if (obraId == ObraId.BREVIARIO_SECULO_XXI) values.remove(date)
        }
        prefs.edit().putStringSet("readDates", values).apply()
    }

    fun comment(item: BreviarioItem): String =
        savedText("comment", item).orEmpty()

    fun saveComment(item: BreviarioItem, value: String) {
        prefs.edit().putString("comment_${item.chavePersistencia}", value).apply()
    }

    fun reflection(item: BreviarioItem): String =
        savedText("reflection", item).orEmpty()

    fun saveReflection(item: BreviarioItem, value: String) {
        val key = "reflection_${item.chavePersistencia}"
        val timestampKey = "reflectionUpdated_${item.chavePersistencia}"
        prefs.edit()
            .putString(key, value)
            .putLong(timestampKey, System.currentTimeMillis())
            .apply()
    }

    fun reflectionHistory(items: List<BreviarioItem>, workTitles: Map<String, String> = emptyMap()): List<PersonalReflection> =
        items.mapNotNull { item ->
            val text = reflection(item).trim()
            if (text.isBlank()) return@mapNotNull null
            PersonalReflection(
                persistenceKey = item.chavePersistencia,
                workTitle = workTitles[item.obraId] ?: if (item.obraId == ObraId.BREVIARIO_SECULO_XXI)
                    "Breviário Maçônico - Kennyo Ismail" else item.titulo,
                date = item.data,
                text = text,
                updatedAt = prefs.getLong("reflectionUpdated_${item.chavePersistencia}", 0L)
            )
        }.sortedByDescending { it.updatedAt }

    fun textEdit(item: BreviarioItem): BreviarioTextEdit? {
        val raw = savedText("textEdit", item) ?: return null
        val obj = runCatching { JSONObject(raw) }.getOrNull() ?: return null
        return BreviarioTextEdit(
            title = obj.optString("title", item.titulo),
            text = obj.optString("text", item.texto),
            footnote = obj.optString("footnote", item.rodape)
        )
    }

    fun applyTextEdit(item: BreviarioItem): BreviarioItem {
        val edit = textEdit(item) ?: return item
        return item.copy(
            titulo = edit.title.ifBlank { item.titulo },
            texto = edit.text.ifBlank { item.texto },
            rodape = edit.footnote
        )
    }

    fun saveTextEdit(item: BreviarioItem, title: String, text: String, footnote: String) {
        val obj = JSONObject()
            .put("title", title.trim())
            .put("text", text.trim())
            .put("footnote", footnote.trim())
        prefs.edit().putString("textEdit_${item.chavePersistencia}", obj.toString()).apply()
    }

    fun removeTextEdit(item: BreviarioItem) {
        prefs.edit()
            .remove("textEdit_${item.chavePersistencia}")
            .also { editor -> legacyDate(item)?.let { editor.remove("textEdit_$it") } }
            .apply()
    }

    fun highlights(item: BreviarioItem): List<TextHighlight> {
        val raw = savedText("highlights", item) ?: "[]"
        val array = runCatching { JSONArray(raw) }.getOrDefault(JSONArray())
        return List(array.length()) { index ->
            val obj = array.getJSONObject(index)
            TextHighlight(
                id = obj.optString("id"),
                text = obj.optString("text"),
                createdAt = obj.optLong("createdAt")
            )
        }.filter { it.text.isNotBlank() }.sortedByDescending { it.createdAt }
    }

    fun addHighlight(item: BreviarioItem, text: String) {
        val clean = text.trim()
        if (clean.isBlank()) return
        val updated = listOf(
            TextHighlight(
                id = UUID.randomUUID().toString(),
                text = clean,
                createdAt = System.currentTimeMillis()
            )
        ) + highlights(item)
        saveHighlights(item, updated)
    }

    fun removeHighlight(item: BreviarioItem, id: String) {
        saveHighlights(item, highlights(item).filterNot { it.id == id })
    }

    fun datesWithComments(): Set<String> =
        prefs.all.keys.filter { it.startsWith("comment_") && prefs.getString(it, "").orEmpty().isNotBlank() }
            .map { it.removePrefix("comment_") }
            .toSet()

    fun officialSources(): List<OfficialSource> {
        val array = runCatching {
            JSONArray(prefs.getString("officialSources", "[]") ?: "[]")
        }.getOrDefault(JSONArray())
        return List(array.length()) { index ->
            val obj = array.optJSONObject(index) ?: JSONObject()
            OfficialSource(
                id = obj.optString("id"),
                title = obj.optString("title"),
                origin = obj.optString("origin"),
                url = obj.optString("url"),
                notes = obj.optString("notes")
            )
        }
    }

    fun saveOfficialSource(title: String, origin: String, url: String, notes: String) {
        val items = officialSources().toMutableList()
        items.add(
            OfficialSource(
                id = UUID.randomUUID().toString(),
                title = title.trim(),
                origin = origin.trim(),
                url = url.trim(),
                notes = notes.trim()
            )
        )
        saveOfficialSources(items)
    }

    fun removeOfficialSource(id: String) {
        saveOfficialSources(officialSources().filterNot { it.id == id })
    }

    fun workRequests(): List<WorkRequest> {
        val array = runCatching {
            JSONArray(prefs.getString("workRequests", "[]") ?: "[]")
        }.getOrDefault(JSONArray())
        return List(array.length()) { index ->
            val obj = array.optJSONObject(index) ?: JSONObject()
            WorkRequest(
                id = obj.optString("id"),
                area = obj.optString("area"),
                title = obj.optString("title"),
                author = obj.optString("author"),
                notes = obj.optString("notes")
            )
        }
    }

    fun saveWorkRequest(area: String, title: String, author: String, notes: String) {
        val items = workRequests().toMutableList()
        items.add(
            WorkRequest(
                id = UUID.randomUUID().toString(),
                area = area,
                title = title.trim(),
                author = author.trim(),
                notes = notes.trim()
            )
        )
        val array = JSONArray()
        items.forEach { item ->
            array.put(
                JSONObject()
                    .put("id", item.id)
                    .put("area", item.area)
                    .put("title", item.title)
                    .put("author", item.author)
                    .put("notes", item.notes)
            )
        }
        prefs.edit().putString("workRequests", array.toString()).apply()
    }

    private fun dailyRecents(): List<DailyRecent> {
        val array = runCatching { JSONArray(prefs.getString("dailyRecentsV1", "[]")) }.getOrDefault(JSONArray())
        return List(array.length()) { array.optJSONObject(it) }.mapNotNull { value ->
            value?.let { DailyRecent(it.optString("workId"), it.optString("date")) }
        }
    }

    fun recentDailyItems(items: List<BreviarioItem>): List<BreviarioItem> {
        val byReference = items.associateBy { it.obraId to it.data }
        return recentByWork(dailyRecents(), 3, { it.workId }, { it.date })
            .mapNotNull { byReference[it.workId to it.date] }
    }

    fun markDailyRecent(item: BreviarioItem) {
        val entries = recentByWork(listOf(DailyRecent(item.obraId, item.data)) + dailyRecents(),
            5, { it.workId }, { it.date })
        val array = JSONArray()
        entries.forEach { array.put(JSONObject().put("workId", it.workId).put("date", it.date)) }
        prefs.edit().putString("dailyRecentsV1", array.toString()).apply()
    }

    fun libraryRecents(): List<LibraryRecent> {
        val array = runCatching {
            JSONArray(prefs.getString("libraryRecents", "[]") ?: "[]")
        }.getOrDefault(JSONArray())
        return List(array.length()) { index ->
            val obj = array.optJSONObject(index) ?: JSONObject()
            LibraryRecent(
                obraId = obj.optString("obraId"),
                title = obj.optString("title"),
                area = obj.optString("area"),
                page = obj.optInt("page"),
                timestamp = obj.optLong("timestamp")
            )
        }.sortedByDescending { it.timestamp }
    }

    fun markLibraryRecent(obraId: String, title: String, area: String, page: Int) {
        val updated = listOf(
            LibraryRecent(
                obraId = obraId,
                title = title,
                area = area,
                page = page,
                timestamp = System.currentTimeMillis()
            )
        ) + libraryRecents()
        val array = JSONArray()
        recentByWork(updated, 5, { it.obraId }, { it.page.toString() }).forEach { item ->
            array.put(
                JSONObject()
                    .put("obraId", item.obraId)
                    .put("title", item.title)
                    .put("area", item.area)
                    .put("page", item.page)
                    .put("timestamp", item.timestamp)
            )
        }
        prefs.edit().putString("libraryRecents", array.toString()).apply()
    }

    private fun toggleSet(key: String, value: String, legacyValue: String? = null) {
        val set = (prefs.getStringSet(key, emptySet()) ?: emptySet()).toMutableSet()
        val legacyPresent = legacyValue != null && set.contains(legacyValue)
        val newPresent = set.contains(value)
        if (newPresent || legacyPresent) {
            set.remove(value)
            legacyValue?.let { set.remove(it) }
        } else {
            set.add(value)
        }
        prefs.edit().putStringSet(key, set).apply()
    }

    private fun saveOfficialSources(items: List<OfficialSource>) {
        val array = JSONArray()
        items.forEach { item ->
            array.put(
                JSONObject()
                    .put("id", item.id)
                    .put("title", item.title)
                    .put("origin", item.origin)
                    .put("url", item.url)
                    .put("notes", item.notes)
            )
        }
        prefs.edit().putString("officialSources", array.toString()).apply()
    }

    private fun saveHighlights(item: BreviarioItem, highlights: List<TextHighlight>) {
        val array = JSONArray()
        highlights.forEach { highlight ->
            array.put(
                JSONObject()
                    .put("id", highlight.id)
                    .put("text", highlight.text)
                    .put("createdAt", highlight.createdAt)
            )
        }
        prefs.edit().putString("highlights_${item.chavePersistencia}", array.toString()).apply()
    }
}
