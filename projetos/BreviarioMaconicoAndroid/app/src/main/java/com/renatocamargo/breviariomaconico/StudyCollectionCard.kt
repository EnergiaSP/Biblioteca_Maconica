package com.renatocamargo.breviariomaconico

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.renatocamargo.breviariomaconico.data.BreviarioItem
import com.renatocamargo.breviariomaconico.data.StudyCollection

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun StudyCollectionCard(
    collection: StudyCollection,
    matches: List<BreviarioItem>,
    colors: Palette,
    readingLabel: (BreviarioItem) -> String,
    onRead: (BreviarioItem) -> Unit
) {
    var expanded by rememberSaveable(collection.id) { mutableStateOf(false) }
    PremiumCard(colors) {
        Text(collection.title, color = colors.text, fontSize = 21.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.semantics { heading() })
        Text("${matches.size} ${if (matches.size == 1) "leitura" else "leituras"}", color = colors.secondary)
        Text(collection.subtitle, color = colors.secondary)
        Text(collection.detail, color = colors.secondary)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            collection.topics.forEach { topic ->
                Text(topic, color = colors.text, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.background(colors.accent.copy(alpha = 0.15f), RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 5.dp))
            }
        }
        (if (expanded) matches else matches.take(3)).forEach { item ->
            Text(readingLabel(item), color = colors.secondary,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
                    .testTag("study.reading.${collection.id}")
                    .clickable(role = Role.Button) { onRead(item) }.padding(vertical = 5.dp))
        }
        if (matches.size > 3) {
            TextButton(onClick = { expanded = !expanded },
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
                    .testTag("study.expand.${collection.id}")
                    .semantics {
                        contentDescription = "${if (expanded) "Recolher" else "Expandir"} coleção ${collection.title}"
                        stateDescription = if (expanded) "Expandida" else "Recolhida"
                    }) {
                Text(if (expanded) "Recolher leituras" else "Ver todas as leituras", color = colors.text)
            }
        }
    }
}
