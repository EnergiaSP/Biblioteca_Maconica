package com.renatocamargo.breviariomaconico.data

import android.content.ContentValues
import androidx.sqlite.SQLiteConnection
import androidx.sqlite.SQLiteStatement
import androidx.sqlite.driver.bundled.BundledSQLiteDriver
import androidx.sqlite.driver.bundled.SQLITE_OPEN_CREATE
import androidx.sqlite.driver.bundled.SQLITE_OPEN_FULLMUTEX
import androidx.sqlite.driver.bundled.SQLITE_OPEN_READONLY
import androidx.sqlite.driver.bundled.SQLITE_OPEN_READWRITE
import java.io.Closeable

// Use the same FTS5 engine on every supported Android version, not the OS SQLite.
internal class RagSQLite private constructor(private val connection: SQLiteConnection) : Closeable {
    fun execSQL(sql: String, args: Array<out Any?> = emptyArray()) {
        statement(sql, args).use { it.step() }
    }

    fun rawQuery(sql: String, args: Array<out Any?>): Rows = Rows(statement(sql, args))

    fun insert(table: String, values: ContentValues) {
        val columns = values.keySet().toList()
        fun identifier(value: String): String {
            require(value.matches(Regex("[A-Za-z_][A-Za-z0-9_]*")))
            return "\"$value\""
        }
        val sql = "INSERT INTO ${identifier(table)} (${columns.joinToString { identifier(it) }}) " +
            "VALUES (${columns.joinToString { "?" }})"
        execSQL(sql, columns.map { values[it] }.toTypedArray())
    }

    private fun statement(sql: String, args: Array<out Any?>): SQLiteStatement {
        val statement = connection.prepare(sql)
        try {
            args.forEachIndexed { index, value ->
                val position = index + 1
                when (value) {
                    null -> statement.bindNull(position)
                    is String -> statement.bindText(position, value)
                    is ByteArray -> statement.bindBlob(position, value)
                    is Float -> statement.bindDouble(position, value.toDouble())
                    is Double -> statement.bindDouble(position, value)
                    is Number -> statement.bindLong(position, value.toLong())
                    is Boolean -> statement.bindLong(position, if (value) 1 else 0)
                    else -> error("Tipo de parametro SQLite nao suportado")
                }
            }
            return statement
        } catch (error: Throwable) {
            statement.close()
            throw error
        }
    }

    override fun close() = connection.close()

    class Rows internal constructor(private val statement: SQLiteStatement) : Closeable {
        fun moveToNext(): Boolean = statement.step()
        fun getInt(column: Int): Int = statement.getLong(column).toInt()
        fun getDouble(column: Int): Double = statement.getDouble(column)
        fun getString(column: Int): String = if (statement.isNull(column)) "" else statement.getText(column)
        override fun close() = statement.close()
    }

    companion object {
        fun open(path: String, readOnly: Boolean = false): RagSQLite {
            val flags = if (readOnly) SQLITE_OPEN_READONLY else SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE
            return RagSQLite(BundledSQLiteDriver().open(path, flags or SQLITE_OPEN_FULLMUTEX))
        }
    }
}
