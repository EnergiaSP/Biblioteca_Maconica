package com.renatocamargo.breviariomaconico

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.renatocamargo.breviariomaconico.data.Prancha

/** The prancha of a dossier: each author side by side, and the text with ABNT citations and references. Same as iOS `PranchaView`. */
@Composable
internal fun PranchaDialog(colors: Palette, prancha: Prancha.Result, config: Prancha.Config, onClose: () -> Unit) {
    val context = LocalContext.current
    var copied by remember { mutableStateOf(false) }
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        LazyColumn(
            Modifier.fillMaxSize().background(Brush.verticalGradient(colors.background)).padding(18.dp).testTag("prancha"),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(config.label("tituloTela"), color = colors.accent, fontSize = 22.sp, fontWeight = FontWeight.Bold,
                        modifier = Modifier.weight(1f).semantics { heading() })
                    TextButton(onClick = onClose, modifier = Modifier.testTag("prancha.fechar")) { Text("Fechar") }
                }
                Text(config.label("aviso"), color = colors.secondary, modifier = Modifier.testTag("prancha.aviso"))
            }
            if (prancha.comparison.isNotEmpty()) {
                item {
                    Text(config.label("comparacao"), color = colors.text, fontWeight = FontWeight.Bold, fontSize = 18.sp,
                        modifier = Modifier.semantics { heading() })
                    Row(Modifier.horizontalScroll(rememberScrollState()).testTag("prancha.comparacao"), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        prancha.comparison.forEach { author ->
                            Column(Modifier.width(280.dp).background(colors.surface, RoundedCornerShape(8.dp)).padding(12.dp).testTag("prancha.autor"),
                                verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text(author.who, color = colors.accent, fontWeight = FontWeight.SemiBold)
                                Text(author.works.joinToString("; "), color = colors.secondary, fontSize = 13.sp)
                                author.excerpts.forEach { Text(it, color = colors.text, fontSize = 15.sp) }
                            }
                        }
                    }
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(colors = libraryActionColors(colors), modifier = Modifier.testTag("prancha.compartilhar"),
                        onClick = { shareText(context, prancha.text) }) { Text(config.label("compartilhar")) }
                    OutlinedButton(modifier = Modifier.testTag("prancha.copiar"), onClick = { copyText(context, prancha.text); copied = true }) {
                        Text(config.label(if (copied) "copiada" else "copiar"), color = colors.text)
                    }
                }
            }
            item {
                SelectionContainer {
                    Column(Modifier.fillMaxWidth().background(colors.surface, RoundedCornerShape(8.dp)).padding(14.dp).testTag("prancha.texto"),
                        verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(prancha.title, color = colors.accent, fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.semantics { heading() })
                        prancha.sections.forEach { section ->
                            Text(section.title, color = colors.text, fontWeight = FontWeight.Bold, fontSize = 17.sp, modifier = Modifier.semantics { heading() })
                            section.paragraphs.forEach { Text(it, color = colors.text, lineHeight = 22.sp) }
                        }
                        Text(config.label("referenciasIncompletas"), color = colors.secondary, fontSize = 13.sp)
                    }
                }
            }
        }
    }
}
