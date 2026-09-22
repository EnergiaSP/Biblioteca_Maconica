package com.renatocamargo.breviariomaconico

import android.os.Build
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.renatocamargo.breviariomaconico.data.*
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SystemBackupTest {
    @Test fun backupFixture() {
        val phase = InstrumentationRegistry.getArguments().getString("backupFixture")
        assumeTrue("Requires an explicit disposable-emulator backup run", phase == "seed" || phase == "verify")
        require(Build.HARDWARE == "ranchu" || Build.HARDWARE == "goldfish") { "Never reset personal devices for this fixture" }
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val prefs = PreferencesStore(context)
        val item = BreviarioRepository.get(context).porData("01/06")!!
        if (phase == "seed") {
            prefs.saveComment(item, "Comentário integral de teste; ação e reflexão.")
            prefs.saveReflection(item, "Reflexão preservada após restauração.")
            prefs.setRead(item.obraId, item.data, true)
            if (!prefs.isFavorite(item)) prefs.toggleFavorite(item)
            prefs.saveTextEdit(item, "Título de teste", "Parágrafo um.\n\nParágrafo dois 578.", "578 Nota integral.")
            // Synthetic value verifies that secrets are excluded, never a provider credential.
            prefs.settings = prefs.settings.copy(theme = AppThemeMode.Sepia, fontSize = 21f, geminiApiKey = "backup-test-not-a-credential")
            assertEquals("backup-test-not-a-credential", PreferencesStore(context).settings.geminiApiKey)
            assertTrue(context.getSharedPreferences("breviario_prefs", android.content.Context.MODE_PRIVATE)
                .edit().putString("backup_fixture_v1", "seeded").commit())
        } else {
            assertTrue("Encrypted credential payloads must be excluded, not merely unreadable after reinstall",
                context.getSharedPreferences(SecureKeyStore.PREFERENCES_NAME, android.content.Context.MODE_PRIVATE).all.isEmpty())
            assertEquals("seeded", context.getSharedPreferences("breviario_prefs", android.content.Context.MODE_PRIVATE).getString("backup_fixture_v1", null))
            assertEquals("Comentário integral de teste; ação e reflexão.", prefs.comment(item))
            assertEquals("Reflexão preservada após restauração.", prefs.reflection(item))
            assertTrue(prefs.isRead(item))
            assertTrue(prefs.isFavorite(item))
            assertEquals("Parágrafo um.\n\nParágrafo dois 578.", prefs.applyTextEdit(item).texto)
            assertEquals("578 Nota integral.", prefs.applyTextEdit(item).rodape)
            assertEquals(AppThemeMode.Sepia, prefs.settings.theme)
            assertEquals(21f, prefs.settings.fontSize)
            assertTrue("Secret values must not be restored", prefs.settings.geminiApiKey.isEmpty())
        }
    }
}
