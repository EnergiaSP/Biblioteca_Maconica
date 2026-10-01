package com.renatocamargo.breviariomaconico

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.renatocamargo.breviariomaconico.data.StudyNotebook
import com.renatocamargo.breviariomaconico.data.StudyNotebookThemes
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Every note of the notebook in one list, searchable, grouped by the themes of the saved dossiers. Same as iOS `CadernoPorTemaView`. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun NotebookThemesCard(
    colors: Palette,
    refresh: Int,
    titles: () -> Map<String, String>,
    onOpen: (StudyNotebookThemes.Note) -> Unit
) {
    val context = LocalContext.current
    val rule = remember { StudyNotebookThemes.loadRule(context) }
    val loaded by produceState<Pair<List<StudyNotebookThemes.Note>, List<StudyNotebookThemes.Theme>>?>(null, refresh) {
        value = withContext(Dispatchers.IO) {
            val notebook = StudyNotebook.collect(context)
            val notes = StudyNotebookThemes.notes(notebook, titles(), rule)
            notes to StudyNotebookThemes.themes(notebook, notes)
        }
    }
    var query by remember { mutableStateOf("") }
    var limit by remember { mutableIntStateOf(30) }
    val (notes, themes) = loaded ?: (emptyList<StudyNotebookThemes.Note>() to emptyList())
    val found = remember(notes, query) { StudyNotebookThemes.search(notes, query) }

    PremiumCard(colors) {
        Text(rule.label("titulo"), color = colors.text, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(rule.label("descricao"), color = colors.secondary)
        OutlinedTextField(query, { query = it; limit = 30 }, label = { Text(rule.label("buscar")) }, singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("notebook.theme.search"))
        if (themes.isNotEmpty()) {
            Text(rule.label("temas"), color = colors.text, fontWeight = FontWeight.SemiBold)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                themes.forEach { theme ->
                    OutlinedButton(onClick = { query = theme.theme; limit = 30 }, modifier = Modifier.testTag("notebook.theme.${theme.theme}")) {
                        Text("${theme.theme} (${theme.count})", color = colors.text)
                    }
                }
            }
        }
        if (loaded == null) {
            // While the notebook is read, nothing is said about how many notes there are.
            Text("Carregando…", color = colors.secondary, modifier = Modifier.testTag("notebook.theme.loading"))
            return@PremiumCard
        }
        Text(rule.label("quantidade", mapOf("n" to "${found.size}")), color = colors.secondary, fontSize = 13.sp,
            modifier = Modifier.testTag("notebook.theme.count"))
        if (found.isEmpty()) {
            Text(rule.label("vazio"), color = colors.secondary)
        } else {
            TextButton(onClick = { shareText(context, StudyNotebookThemes.export(found, query, rule)) },
                modifier = Modifier.testTag("notebook.theme.export")) { Text(rule.label("exportar")) }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                found.take(limit).forEach { note -> NoteRow(colors, note, rule.label("abrir")) { onOpen(note) } }
            }
            if (found.size > limit) {
                TextButton(onClick = { limit += 30 }, modifier = Modifier.testTag("notebook.theme.more")) { Text("Mostrar mais") }
            }
        }
    }
}

@Composable
private fun NoteRow(colors: Palette, note: StudyNotebookThemes.Note, openLabel: String, onOpen: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(colors.surface, RoundedCornerShape(8.dp))
            .clickable(onClick = onOpen).semantics { onClick(label = openLabel) { onOpen(); true } }
            .padding(10.dp).testTag("notebook.note"),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text("${note.label} — ${note.origin}", color = colors.accent, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
        if (note.text.isNotBlank()) Text(note.text, color = colors.text, maxLines = 8)
    }
}
