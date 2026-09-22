package com.renatocamargo.breviariomaconico

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal suspend fun <T> libraryQuery(block: () -> T): Result<T> = withContext(Dispatchers.IO) {
    try {
        Result.success(block())
    } catch (cancelled: CancellationException) {
        throw cancelled
    } catch (error: Exception) {
        Result.failure(error)
    }
}
