package com.renatocamargo.breviariomaconico

import com.renatocamargo.breviariomaconico.data.BreviarioItem
import org.junit.Assert.assertEquals
import org.junit.Test

class AppNavigationControllerTest {
    private val item = BreviarioItem(1, "01/01", "Título", "", "Texto", "", 1, "obra")

    @Test
    fun navigationReturnsHomeFromAnyScreen() {
        val navigation = AppNavigationController(Screen.Dossier, item)
        navigation.showHome()
        assertEquals(Screen.Home, navigation.screen)
    }

    @Test
    fun openingReaderSelectsItemAndDestination() {
        val other = item.copy(id = 2, data = "02/01")
        val navigation = AppNavigationController(Screen.Home, item)
        navigation.showReader(other)
        assertEquals(Screen.Reader, navigation.screen)
        assertEquals(other, navigation.selectedItem)
    }
}
