package com.renatocamargo.breviariomaconico

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.renatocamargo.breviariomaconico.data.BreviarioItem

internal class AppNavigationController(
    initialScreen: Screen = Screen.Home,
    initialItem: BreviarioItem
) {
    var screen by mutableStateOf(initialScreen)
        private set

    var selectedItem by mutableStateOf(initialItem)
        private set

    /** Screens the user came from, so Back returns to the Dossiê, Coleções or Busca that opened a reading. */
    private val history = mutableStateListOf<Screen>()

    val canGoBack: Boolean
        get() = history.isNotEmpty() || screen != Screen.Home

    fun show(screen: Screen) {
        if (screen == this.screen) return
        // Revisiting a screen already in the history drops the loop instead of growing the stack.
        val existing = history.lastIndexOf(screen)
        if (existing >= 0) {
            while (history.size > existing) history.removeAt(history.lastIndex)
        } else {
            history.add(this.screen)
        }
        this.screen = screen
    }

    fun showHome() {
        history.clear()
        screen = Screen.Home
    }

    fun showReader(item: BreviarioItem) {
        selectedItem = item
        show(Screen.Reader)
    }

    fun updateSelected(item: BreviarioItem) {
        selectedItem = item
    }

    /** Returns false when there is nowhere left to go, letting the system close the app. */
    fun back(): Boolean {
        if (history.isNotEmpty()) {
            screen = history.removeAt(history.lastIndex)
            return true
        }
        if (screen != Screen.Home) {
            screen = Screen.Home
            return true
        }
        return false
    }
}
