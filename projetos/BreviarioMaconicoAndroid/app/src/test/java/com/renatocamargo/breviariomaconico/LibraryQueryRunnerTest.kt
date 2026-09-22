package com.renatocamargo.breviariomaconico

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class LibraryQueryRunnerTest {
    @Test
    fun databaseFailureBecomesRecoverableResult() = runBlocking {
        val result = libraryQuery { throw IllegalStateException("Corrupt database") }
        assertTrue(result.isFailure)
    }

    @Test
    fun successPreservesCompleteResult() = runBlocking {
        assertEquals(listOf("Texto", "Nota"), libraryQuery { listOf("Texto", "Nota") }.getOrThrow())
    }

    @Test(expected = CancellationException::class)
    fun leavingScreenDoesNotSwallowCancellation() = runBlocking {
        libraryQuery { throw CancellationException("Navigation") }
        Unit
    }
}
