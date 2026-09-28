package com.renatocamargo.breviariomaconico

import com.renatocamargo.breviariomaconico.data.BreviarioItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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

    @Test
    fun backReturnsToTheScreenThatOpenedTheReading() {
        val navigation = AppNavigationController(Screen.Home, item)
        navigation.show(Screen.Dossier)
        navigation.showReader(item)
        assertTrue(navigation.back())
        assertEquals(Screen.Dossier, navigation.screen)
        assertTrue(navigation.back())
        assertEquals(Screen.Home, navigation.screen)
        assertFalse(navigation.back())
        assertFalse(navigation.canGoBack)
    }

    @Test
    fun revisitingAScreenDoesNotGrowTheHistory() {
        val navigation = AppNavigationController(Screen.Home, item)
        navigation.show(Screen.Dossier)
        navigation.showReader(item)
        navigation.show(Screen.Dossier)
        navigation.showReader(item)
        navigation.show(Screen.Dossier)
        assertTrue(navigation.back())
        assertEquals(Screen.Home, navigation.screen)
    }

    @Test
    fun backFromAScreenOpenedDirectlyGoesHome() {
        val navigation = AppNavigationController(Screen.Reader, item)
        assertTrue(navigation.canGoBack)
        assertTrue(navigation.back())
        assertEquals(Screen.Home, navigation.screen)
    }
}
