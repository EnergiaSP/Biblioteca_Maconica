package com.renatocamargo.breviariomaconico.data

import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

object GeminiService {
    private val modelos = listOf(
        "gemini-2.5-flash-lite",
        "gemini-2.5-flash"
    )

    fun gerarTexto(prompt: String, chaveApi: String): String {
        val chave = chaveApi.trim()
        require(chave.isNotEmpty()) { "Informe a chave Gemini nas configurações." }

        var ultimoErro: Exception? = null
        for (modelo in modelos) {
            try {
                return gerarComModelo(modelo, prompt, chave)
            } catch (erro: Exception) {
                ultimoErro = erro
                val mensagem = erro.message.orEmpty().lowercase()
                if ("chave" in mensagem || "inválida" in mensagem || "permissão" in mensagem || "limite gratuito" in mensagem || "interrompeu" in mensagem) {
                    throw erro
                }
            }
        }

        throw ultimoErro ?: IllegalStateException("Não foi possível gerar a análise.")
    }

    private fun gerarComModelo(modelo: String, prompt: String, chaveApi: String): String {
        val url = URL("https://generativelanguage.googleapis.com/v1beta/models/$modelo:generateContent")
        val conexao = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 20_000
            readTimeout = 60_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
            setRequestProperty("x-goog-api-key", chaveApi)
        }

        try {
        val payload = JSONObject()
            .put(
                "contents",
                JSONArray().put(
                    JSONObject().put(
                        "parts",
                        JSONArray().put(JSONObject().put("text", prompt))
                    )
                )
            )
            .put(
                "generationConfig",
                JSONObject()
                    .put("temperature", 0.1)
            )

        OutputStreamWriter(conexao.outputStream, Charsets.UTF_8).use { writer ->
            writer.write(payload.toString())
        }

        val status = conexao.responseCode
        val resposta = if (status in 200..299) {
            conexao.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } else {
            conexao.errorStream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        }

        if (status == 401 || status == 403 || (status == 400 && resposta.contains("API key not valid", ignoreCase = true))) {
            throw IllegalStateException("Chave Gemini inválida ou sem permissão.")
        }
        if (status == 429) {
            throw IllegalStateException("Limite gratuito atingido. Tente novamente mais tarde.")
        }
        if (status !in 200..299) {
            throw IllegalStateException("Falha ao gerar análise pelo Gemini.")
        }

        return extrairRespostaCompleta(resposta)
        } finally { conexao.disconnect() }
    }

    internal fun extrairRespostaCompleta(response: String): String {
        val candidate = JSONObject(response).optJSONArray("candidates")?.optJSONObject(0)
            ?: throw IllegalStateException("A IA não retornou conteúdo útil.")
        check(candidate.optString("finishReason") == "STOP") {
            "A IA interrompeu a resposta. Nenhuma análise parcial foi salva. Tente novamente."
        }
        val parts = candidate.optJSONObject("content")?.optJSONArray("parts")
        val texto = (0 until (parts?.length() ?: 0)).mapNotNull { index ->
            parts?.optJSONObject(index)?.takeUnless { it.optBoolean("thought", false) }?.optString("text")?.takeIf { it.isNotBlank() }
        }.joinToString("\n").trim()
        if (texto.isBlank()) {
            throw IllegalStateException("A IA não retornou conteúdo útil.")
        }

        return texto
    }

    internal fun validarCitacoes(text: String, sourceCount: Int) {
        val ids = Regex("\\[F([0-9]+)\\]").findAll(text).map { it.groupValues[1].toIntOrNull() ?: 0 }.toList()
        require(sourceCount > 0 && ids.isNotEmpty() && ids.all { it in 1..sourceCount }) {
            "A resposta não possui referências documentais válidas. Nenhuma análise foi salva."
        }
    }
}
