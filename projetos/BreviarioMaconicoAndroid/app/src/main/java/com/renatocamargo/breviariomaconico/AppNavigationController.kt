package com.renatocamargo.breviariomaconico

import androidx.compose.runtime.getValue
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

    fun show(screen: Screen) {
        this.screen = screen
    }

    fun showHome() {
        screen = Screen.Home
    }

    fun showReader(item: BreviarioItem) {
        selectedItem = item
        screen = Screen.Reader
    }

    fun updateSelected(item: BreviarioItem) {
        selectedItem = item
    }
}
