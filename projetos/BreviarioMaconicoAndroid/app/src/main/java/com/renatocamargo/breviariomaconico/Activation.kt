package com.renatocamargo.breviariomaconico

import java.security.MessageDigest
import java.time.LocalDate

object ActivationCodeGenerator {
    private const val APPLE_REVIEW_CODE = "BMXI-APPLE-2026"
    private const val ADMIN_PASSWORD_HASH = "c55a6c39f3e28eea11af61edc4085dd031a3a81213c84497384459deb576efbb"

    fun todayCode(date: LocalDate = LocalDate.now()): String {
        val day = date.dayOfMonth
        val month = date.monthValue
        val year = date.year
        val seed = (day * 9_283) + (month * 6_151) + (year * 313) + 7_349
        val mixed = seed xor ((day + 17) * (month + 29) * 97)
        val digits = kotlin.math.abs(mixed) % 10_000
        return "BMXI-%02d%02d-%04d".format(day, month, digits)
    }

    fun isValid(code: String, date: LocalDate = LocalDate.now()): Boolean {
        val normalized = normalize(code)
        return normalized == normalize(todayCode(date)) || normalized == normalize(APPLE_REVIEW_CODE)
    }

    fun adminPasswordValid(password: String): Boolean = sha256(password.trim().uppercase()) == ADMIN_PASSWORD_HASH

    private fun normalize(code: String): String = code.uppercase().filter { it.isLetterOrDigit() }

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
}
