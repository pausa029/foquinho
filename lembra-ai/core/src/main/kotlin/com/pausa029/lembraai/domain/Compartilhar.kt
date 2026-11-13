package com.pausa029.lembraai.domain

import java.io.ByteArrayOutputStream
import java.time.DayOfWeek
import java.time.LocalDate
import java.util.Base64
import java.util.zip.Deflater
import java.util.zip.Inflater

/**
 * Compromisso dentro de um link, sem servidor: JSON compacto → Deflate (zlib) → Base64 URL-safe sem "=".
 * Formato: "LA1." + dados. A página /c/ decodifica o mesmo formato em JavaScript (DecompressionStream "deflate").
 *
 * Só leitura de dados: tudo que vem do link é validado e limitado antes de virar compromisso.
 */
object Compartilhar {
    const val VERSAO = 1
    const val PREFIXO = "LA$VERSAO."
    const val LIMITE = 2000
    const val BASE_LINK = "https://foquinho.com.br/lembra-ai/c/#"
    const val ESQUEMA = "lembraai://c#"
    const val BAIXAR_APK = "https://github.com/pausa029/foquinho/releases/download/lembra-ai-ultimo/LembraAi.apk"

    private const val MAX_TITULO = 200
    private const val MAX_OBS = 1000
    private const val MAX_TEL = 40
    private const val MAX_END = 300
    private const val MAX_NOME = 40

    private val REGEX = Regex("""LA(\d{1,3})\.([A-Za-z0-9_-]{8,})""")

    data class Pacote(val compromisso: Compromisso, val id: String, val enviadoPor: String)

    sealed interface Leitura {
        data class Ok(val pacote: Pacote) : Leitura
        data object Quebrado : Leitura
        data object VersaoNova : Leitura
        data object Nenhum : Leitura
    }

    data class Codigo(val codigo: String, val observacaoCortada: Boolean) {
        val link get() = BASE_LINK + codigo
    }

    /** O código (LA1.xxxx) dentro de um texto, se houver. */
    fun extrair(texto: String?): String? = texto?.let { REGEX.find(it)?.value }

    /** Há algo com cara de código do Lembra Aí neste texto? */
    fun temCodigo(texto: String?) = texto != null && REGEX.containsMatchIn(texto)

    fun codificar(c: Compromisso, id: String, enviadoPor: String): Codigo {
        var obs = c.observacao.take(MAX_OBS)
        var cortou = obs.length < c.observacao.length
        var codigo = PREFIXO + empacotar(json(c.copy(observacao = obs), id, enviadoPor))
        while (codigo.length > LIMITE && obs.isNotEmpty()) {
            obs = obs.dropLast(maxOf(10, obs.length / 5)).trimEnd()
            cortou = true
            codigo = PREFIXO + empacotar(json(c.copy(observacao = if (obs.isEmpty()) "" else "$obs…"), id, enviadoPor))
        }
        return Codigo(codigo, cortou)
    }

    /** Procura o código em qualquer texto (link, mensagem inteira do WhatsApp, só o código). */
    fun decodificar(texto: String?): Leitura {
        if (texto.isNullOrBlank()) return Leitura.Nenhum
        val m = REGEX.find(texto) ?: return if (Regex("""LA\d{1,3}\.""").containsMatchIn(texto)) Leitura.Quebrado else Leitura.Nenhum
        val versao = m.groupValues[1].toIntOrNull() ?: return Leitura.Quebrado
        if (versao > VERSAO) return Leitura.VersaoNova
        if (versao < 1) return Leitura.Quebrado
        return try {
            val obj = Json.ler(desempacotar(m.groupValues[2])) as? Map<*, *> ?: return Leitura.Quebrado
            val v = (obj["v"] as? Number)?.toInt() ?: return Leitura.Quebrado
            if (v > VERSAO) return Leitura.VersaoNova
            ler(obj)?.let { Leitura.Ok(it) } ?: Leitura.Quebrado
        } catch (e: Exception) {
            Leitura.Quebrado
        }
    }

    // ---------- mensagem ----------

    fun mensagem(c: Compromisso, link: String): String =
        "📅 Marquei um compromisso para você no Lembra Aí:\n\n" +
            "*${c.titulo}*\n" +
            "${Texto.cap(Texto.dataCompleta(c.data))}, às ${Texto.hora(c.hora)}\n\n" +
            "👉 Toque no link para salvar na sua agenda:\n$link\n\n" +
            "Se o link não abrir, copie esta mensagem inteira e abra o Lembra Aí."

    // ---------- JSON do compromisso ----------

    private fun json(c: Compromisso, id: String, enviadoPor: String): String {
        val f = c.frequencia
        val r = c.repeticao
        val m = linkedMapOf<String, Any?>(
            "v" to VERSAO,
            "id" to id,
            "de" to enviadoPor.take(MAX_NOME),
            "t" to c.titulo.take(MAX_TITULO),
            "d" to c.data.toString(),
            "h" to "%02d:%02d".format(c.hora / 60, c.hora % 60),
            "da" to c.diasAntes,
            "fm" to when (f.modo) { ModoFrequencia.INTERVALO -> "I"; ModoFrequencia.VEZES -> "V"; ModoFrequencia.HORARIOS -> "H" },
            "fi" to f.intervaloMin,
            "fv" to f.vezes,
            "fh" to f.horarios,
            "nh" to c.avisarNaHora,
            "an" to c.avisosAntes,
            "fo" to c.avisarForaDaJanela,
            "e" to when (c.estilo) { EstiloAviso.TOCAR_E_VIBRAR -> "TV"; EstiloAviso.SO_VIBRAR -> "V"; EstiloAviso.SO_TOCAR -> "T" },
            "fa" to c.falar,
            "r" to when (r.tipo) {
                TipoRepeticao.NAO_REPETE -> "N"; TipoRepeticao.TODO_DIA -> "D"; TipoRepeticao.TODA_SEMANA -> "S"
                TipoRepeticao.TODO_MES -> "M"; TipoRepeticao.TODO_ANO -> "A"; TipoRepeticao.DIAS_DA_SEMANA -> "W"
                TipoRepeticao.A_CADA_X_DIAS -> "X"
            },
        )
        c.janela?.let { m["j"] = listOf(it.inicio, it.fim) }
        if (r.diasSemana.isNotEmpty()) m["rw"] = r.diasSemana.map { it.value }.sorted()
        if (r.tipo == TipoRepeticao.A_CADA_X_DIAS) m["rx"] = r.cadaDias
        r.ate?.let { m["ra"] = it.toString() }
        if (c.observacao.isNotBlank()) m["o"] = c.observacao
        if (c.telefone.isNotBlank()) m["tel"] = c.telefone.take(MAX_TEL)
        if (c.endereco.isNotBlank()) m["end"] = c.endereco.take(MAX_END)
        return Json.escrever(m)
    }

    private fun limpo(s: Any?, max: Int): String =
        (s as? String).orEmpty().filter { it == '\n' || !it.isISOControl() }.trim().take(max)

    private fun data(s: Any?): LocalDate? = (s as? String)?.let { runCatching { LocalDate.parse(it) }.getOrNull() }

    private fun inteiro(s: Any?, padrao: Int, faixa: IntRange): Int = ((s as? Number)?.toInt() ?: padrao).coerceIn(faixa)

    private fun lista(s: Any?, faixa: IntRange, max: Int): List<Int> =
        (s as? List<*>).orEmpty().mapNotNull { (it as? Number)?.toInt() }.filter { it in faixa }.distinct().take(max)

    private fun ler(o: Map<*, *>): Pacote? {
        val titulo = limpo(o["t"], MAX_TITULO).ifEmpty { return null }
        val dia = data(o["d"]) ?: return null
        val hm = (o["h"] as? String)?.split(':') ?: return null
        val hh = hm.getOrNull(0)?.toIntOrNull()?.takeIf { it in 0..23 } ?: return null
        val mm = hm.getOrNull(1)?.toIntOrNull()?.takeIf { it in 0..59 } ?: return null
        val id = (o["id"] as? String)?.filter { it.isLetterOrDigit() || it == '-' }?.take(64).orEmpty()
        val janela = lista(o["j"], 0..MINUTOS_DIA, 2).takeIf { it.size == 2 }?.let { Janela(it[0], it[1]) }?.takeIf { it.valida }
        val r = when (o["r"]) {
            "D" -> TipoRepeticao.TODO_DIA; "S" -> TipoRepeticao.TODA_SEMANA; "M" -> TipoRepeticao.TODO_MES
            "A" -> TipoRepeticao.TODO_ANO; "W" -> TipoRepeticao.DIAS_DA_SEMANA; "X" -> TipoRepeticao.A_CADA_X_DIAS
            else -> TipoRepeticao.NAO_REPETE
        }
        val c = Compromisso(
            titulo = titulo,
            data = dia,
            hora = hh * 60 + mm,
            diasAntes = inteiro(o["da"], 1, 0..30),
            janela = janela,
            frequencia = Frequencia(
                modo = when (o["fm"]) { "V" -> ModoFrequencia.VEZES; "H" -> ModoFrequencia.HORARIOS; else -> ModoFrequencia.INTERVALO },
                intervaloMin = inteiro(o["fi"], 60, CalculoAvisos.INTERVALO_MINIMO..12 * 60),
                vezes = inteiro(o["fv"], 3, 1..CalculoAvisos.MAX_VEZES),
                horarios = lista(o["fh"], 0..MINUTOS_DIA, 24).sorted(),
            ),
            avisarNaHora = o["nh"] as? Boolean ?: true,
            avisosAntes = lista(o["an"], 1..7 * 1440, 10),
            avisarForaDaJanela = o["fo"] as? Boolean ?: true,
            estilo = when (o["e"]) { "V" -> EstiloAviso.SO_VIBRAR; "T" -> EstiloAviso.SO_TOCAR; else -> EstiloAviso.TOCAR_E_VIBRAR },
            falar = o["fa"] as? Boolean ?: true,
            repeticao = Repeticao(
                tipo = r,
                diasSemana = lista(o["rw"], 1..7, 7).map { DayOfWeek.of(it) }.toSet(),
                cadaDias = inteiro(o["rx"], 2, 2..90),
                ate = data(o["ra"])?.takeIf { it >= dia },
            ),
            observacao = limpo(o["o"], MAX_OBS + 1),
            telefone = limpo(o["tel"], MAX_TEL).filter { it.isDigit() || it in "+()- " },
            endereco = limpo(o["end"], MAX_END),
            codigoId = id,
            enviadoPor = limpo(o["de"], MAX_NOME),
        )
        return Pacote(c, id, c.enviadoPor)
    }

    // ---------- compactação ----------

    private fun empacotar(json: String): String {
        val d = Deflater(Deflater.BEST_COMPRESSION)
        d.setInput(json.toByteArray(Charsets.UTF_8))
        d.finish()
        val out = ByteArrayOutputStream()
        val buf = ByteArray(1024)
        while (!d.finished()) out.write(buf, 0, d.deflate(buf))
        d.end()
        return Base64.getUrlEncoder().withoutPadding().encodeToString(out.toByteArray())
    }

    private fun desempacotar(dados: String): String {
        val bytes = Base64.getUrlDecoder().decode(dados)
        val inf = Inflater()
        inf.setInput(bytes)
        val out = ByteArrayOutputStream()
        val buf = ByteArray(1024)
        while (!inf.finished()) {
            val n = inf.inflate(buf)
            if (n == 0) {
                require(!inf.needsInput() && !inf.needsDictionary()) { "dados incompletos" }
            }
            out.write(buf, 0, n)
            require(out.size() < 64 * 1024) { "grande demais" }
        }
        inf.end()
        return out.toString(Charsets.UTF_8.name())
    }
}

/** JSON mínimo (só o necessário para o link), sem bibliotecas. */
internal object Json {
    fun escrever(v: Any?): String = StringBuilder().also { esc(it, v) }.toString()

    private fun esc(sb: StringBuilder, v: Any?) {
        when (v) {
            null -> sb.append("null")
            is Boolean, is Int, is Long -> sb.append(v.toString())
            is Number -> sb.append(v.toString())
            is String -> {
                sb.append('"')
                for (ch in v) when (ch) {
                    '"' -> sb.append("\\\""); '\\' -> sb.append("\\\\"); '\n' -> sb.append("\\n"); '\r' -> sb.append("\\r"); '\t' -> sb.append("\\t")
                    else -> if (ch < ' ') sb.append("\\u%04x".format(ch.code)) else sb.append(ch)
                }
                sb.append('"')
            }
            is Map<*, *> -> {
                sb.append('{')
                v.entries.forEachIndexed { i, (k, x) -> if (i > 0) sb.append(','); esc(sb, k.toString()); sb.append(':'); esc(sb, x) }
                sb.append('}')
            }
            is Iterable<*> -> {
                sb.append('[')
                v.forEachIndexed { i, x -> if (i > 0) sb.append(','); esc(sb, x) }
                sb.append(']')
            }
            else -> esc(sb, v.toString())
        }
    }

    fun ler(s: String): Any? {
        val p = Leitor(s)
        val v = p.valor(0)
        p.espacos()
        require(p.i == s.length) { "sobrou texto" }
        return v
    }

    private class Leitor(val s: String) {
        var i = 0
        fun espacos() { while (i < s.length && s[i].isWhitespace()) i++ }
        fun valor(nivel: Int): Any? {
            require(nivel < 20) { "fundo demais" }
            espacos()
            require(i < s.length) { "fim inesperado" }
            return when (s[i]) {
                '{' -> objeto(nivel)
                '[' -> lista(nivel)
                '"' -> texto()
                't' -> palavra("true", true)
                'f' -> palavra("false", false)
                'n' -> palavra("null", null)
                else -> numero()
            }
        }
        fun palavra(p: String, v: Any?): Any? { require(s.startsWith(p, i)); i += p.length; return v }
        fun numero(): Number {
            val ini = i
            while (i < s.length && (s[i].isDigit() || s[i] in "+-.eE")) i++
            val t = s.substring(ini, i)
            return t.toLongOrNull() ?: t.toDouble()
        }
        fun texto(): String {
            i++
            val sb = StringBuilder()
            while (true) {
                require(i < s.length) { "texto sem fim" }
                val ch = s[i++]
                when (ch) {
                    '"' -> return sb.toString()
                    '\\' -> {
                        val e = s[i++]
                        when (e) {
                            'n' -> sb.append('\n'); 't' -> sb.append('\t'); 'r' -> sb.append('\r'); 'b' -> sb.append('\b'); 'f' -> sb.append('\u000C')
                            'u' -> { sb.append(s.substring(i, i + 4).toInt(16).toChar()); i += 4 }
                            else -> sb.append(e)
                        }
                    }
                    else -> sb.append(ch)
                }
            }
        }
        fun lista(nivel: Int): List<Any?> {
            i++
            val l = mutableListOf<Any?>()
            espacos()
            if (s[i] == ']') { i++; return l }
            while (true) {
                l += valor(nivel + 1)
                espacos()
                when (s[i++]) { ',' -> continue; ']' -> return l; else -> error("lista") }
            }
        }
        fun objeto(nivel: Int): Map<String, Any?> {
            i++
            val m = linkedMapOf<String, Any?>()
            espacos()
            if (s[i] == '}') { i++; return m }
            while (true) {
                espacos()
                require(s[i] == '"')
                val k = texto()
                espacos()
                require(s[i++] == ':')
                m[k] = valor(nivel + 1)
                espacos()
                when (s[i++]) { ',' -> continue; '}' -> return m; else -> error("objeto") }
            }
        }
    }
}
