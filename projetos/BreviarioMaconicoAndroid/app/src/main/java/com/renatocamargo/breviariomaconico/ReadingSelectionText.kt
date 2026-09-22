package com.renatocamargo.breviariomaconico

import android.graphics.Typeface
import android.text.SpannableString
import android.text.Spanned
import android.text.style.BackgroundColorSpan
import android.text.style.RelativeSizeSpan
import android.text.style.SuperscriptSpan
import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import android.widget.TextView
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.viewinterop.AndroidView
import com.renatocamargo.breviariomaconico.data.ReaderSettings
import com.renatocamargo.breviariomaconico.data.TextHighlight
import com.renatocamargo.breviariomaconico.data.TextoFormatter

@Composable
internal fun ReadingSelectionText(text: String, footnotes: String, highlights: List<TextHighlight>, settings: ReaderSettings,
    colors: Palette, onHighlight: (String) -> Unit) {
    val save = rememberUpdatedState(onHighlight)
    val styled = remember(text, footnotes, highlights, colors.accent) {
        SpannableString(text).apply {
            TextoFormatter.referencias(text, footnotes).forEach {
                setSpan(SuperscriptSpan(), it.first, it.last + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                setSpan(RelativeSizeSpan(0.7f), it.first, it.last + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            highlights.filter { it.text.isNotBlank() }.forEach { highlight ->
                var offset = text.indexOf(highlight.text)
                while (offset >= 0) {
                    setSpan(BackgroundColorSpan(colors.accent.copy(alpha = 0.3f).toArgb()), offset,
                        offset + highlight.text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    offset = text.indexOf(highlight.text, offset + highlight.text.length)
                }
            }
        }
    }
    AndroidView(modifier = Modifier.fillMaxWidth(), factory = { context ->
        TextView(context).apply {
            setTextIsSelectable(true)
            setPadding(0, 0, 0, 0)
            typeface = Typeface.SERIF
            justificationMode = android.graphics.text.LineBreaker.JUSTIFICATION_MODE_INTER_WORD
            customSelectionActionModeCallback = object : ActionMode.Callback {
                override fun onCreateActionMode(mode: ActionMode, menu: Menu): Boolean {
                    menu.add(0, 4667, 0, "Destacar")
                    return true
                }
                override fun onPrepareActionMode(mode: ActionMode, menu: Menu) = false
                override fun onDestroyActionMode(mode: ActionMode) = Unit
                override fun onActionItemClicked(mode: ActionMode, item: MenuItem): Boolean {
                    if (item.itemId != 4667) return false
                    val start = minOf(selectionStart, selectionEnd).coerceAtLeast(0)
                    val end = maxOf(selectionStart, selectionEnd).coerceAtMost(this@apply.text.length)
                    if (end > start) save.value(this@apply.text.substring(start, end))
                    mode.finish()
                    return true
                }
            }
        }
    }, update = { view ->
        view.setTextColor(colors.text.toArgb())
        view.textSize = settings.fontSize
        view.setLineSpacing(settings.lineSpacing * view.resources.displayMetrics.scaledDensity, 1f)
        if (view.tag !== styled) {
            view.text = styled
            view.tag = styled
        }
    })
}
