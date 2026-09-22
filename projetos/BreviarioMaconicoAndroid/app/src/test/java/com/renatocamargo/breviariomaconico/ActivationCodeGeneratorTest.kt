package com.renatocamargo.breviariomaconico

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class ActivationCodeGeneratorTest {
    private val date = LocalDate.of(2026, 9, 16)

    @Test
    fun generatedCodeIsAcceptedForTheSameDate() {
        assertTrue(ActivationCodeGenerator.isValid(ActivationCodeGenerator.todayCode(date), date))
    }

    @Test
    fun formattingDifferencesDoNotInvalidateTheCode() {
        val code = ActivationCodeGenerator.todayCode(date).lowercase().replace("-", " ")
        assertTrue(ActivationCodeGenerator.isValid(code, date))
    }

    @Test
    fun expiredOrArbitraryCodeIsRejected() {
        val yesterdayCode = ActivationCodeGenerator.todayCode(date.minusDays(1))
        assertFalse(ActivationCodeGenerator.isValid(yesterdayCode, date))
        assertFalse(ActivationCodeGenerator.isValid("BMXI-0000-0000", date))
    }
}
