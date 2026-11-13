package com.pausa029.lembraai.data

import android.content.Context
import com.pausa029.lembraai.alarm.Agendador
import com.pausa029.lembraai.domain.Compromisso
import com.pausa029.lembraai.domain.TipoRepeticao
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

/**
 * Tudo que muda a agenda passa por aqui, e toda mudança recalcula os alarmes
 * (editar cancela os antigos e recalcula; apagar cancela os do compromisso).
 */
object Agenda {
    private fun dao(ctx: Context) = LembraDb.get(ctx).dao()

    fun observar(ctx: Context): Flow<List<Compromisso>> = dao(ctx).observar().map { l -> l.map { it.paraDominio() } }

    suspend fun todos(ctx: Context): List<Compromisso> = dao(ctx).todos().map { it.paraDominio() }

    suspend fun porId(ctx: Context, id: Long): Compromisso? = dao(ctx).porId(id)?.paraDominio()

    suspend fun porCodigo(ctx: Context, codigo: String): Compromisso? =
        if (codigo.isBlank()) null else dao(ctx).porCodigo(codigo)?.paraDominio()

    /** Dá um identificador de envio ao compromisso (o mesmo em todos os envios, para quem recebe poder atualizar). */
    suspend fun garantirCodigo(ctx: Context, c: Compromisso): Compromisso {
        if (c.codigoId.isNotBlank()) return c
        val n = c.copy(codigoId = java.util.UUID.randomUUID().toString())
        dao(ctx).salvar(n.paraEntidade())
        return n
    }

    suspend fun salvar(ctx: Context, c: Compromisso): Long {
        val id = dao(ctx).salvar(c.paraEntidade())
        if (c.id != 0L) dao(ctx).apagarExtrasDe(c.id)
        Agendador.reagendar(ctx)
        return id
    }

    suspend fun apagar(ctx: Context, id: Long) {
        dao(ctx).apagar(id)
        dao(ctx).apagarExtrasDe(id)
        Agendador.reagendar(ctx)
    }

    /** "JÁ FIZ": cancela todos os avisos que faltam desta ocorrência. */
    suspend fun marcarFeito(ctx: Context, id: Long, ocorrencia: LocalDate) {
        val c = porId(ctx, id) ?: return
        dao(ctx).salvar(c.copy(feitos = c.feitos + ocorrencia).paraEntidade())
        dao(ctx).apagarExtrasDaOcorrencia(id, ocorrencia.toEpochDay())
        Agendador.reagendar(ctx)
    }

    suspend fun desmarcarFeito(ctx: Context, id: Long, ocorrencia: LocalDate) {
        val c = porId(ctx, id) ?: return
        dao(ctx).salvar(c.copy(feitos = c.feitos - ocorrencia).paraEntidade())
        Agendador.reagendar(ctx)
    }

    suspend fun avisoExtra(ctx: Context, e: AvisoExtraEntity) {
        dao(ctx).inserirExtra(e)
        Agendador.reagendar(ctx)
    }

    /** "Apagar compromissos antigos": os que já passaram e não repetem mais. */
    suspend fun apagarAntigos(ctx: Context): Int {
        val hoje = LocalDate.now()
        val antigos = todos(ctx).filter { c ->
            if (c.repeticao.tipo == TipoRepeticao.NAO_REPETE) c.data < hoje
            else c.repeticao.ate != null && c.repeticao.ate!! < hoje
        }
        antigos.forEach { dao(ctx).apagar(it.id); dao(ctx).apagarExtrasDe(it.id) }
        Agendador.reagendar(ctx)
        return antigos.size
    }

    // ---------- cópia da agenda ----------

    suspend fun exportar(ctx: Context): String {
        val arr = JSONArray()
        for (e in dao(ctx).todos()) {
            arr.put(JSONObject().apply {
                put("titulo", e.titulo); put("dataEpoch", e.dataEpoch); put("hora", e.hora); put("diasAntes", e.diasAntes)
                put("janelaInicio", e.janelaInicio ?: JSONObject.NULL); put("janelaFim", e.janelaFim ?: JSONObject.NULL)
                put("modo", e.modo); put("intervalo", e.intervalo); put("vezes", e.vezes); put("horarios", e.horarios)
                put("naHora", e.naHora); put("antes", e.antes); put("foraJanelaOk", e.foraJanelaOk)
                put("estilo", e.estilo); put("falar", e.falar); put("repete", e.repete); put("diasSemana", e.diasSemana)
                put("cadaDias", e.cadaDias); put("ateEpoch", e.ateEpoch ?: JSONObject.NULL)
                put("observacao", e.observacao); put("telefone", e.telefone); put("endereco", e.endereco); put("feitos", e.feitos)
                put("codigoId", e.codigoId); put("enviadoPor", e.enviadoPor)
            })
        }
        return JSONObject().put("app", "Lembra Aí").put("versao", 1).put("compromissos", arr).toString(2)
    }

    /** Lê uma cópia. Devolve a quantidade de compromissos ou lança erro se o arquivo não for uma cópia válida. */
    fun lerCopia(texto: String): List<CompromissoEntity> {
        val raiz = JSONObject(texto)
        require(raiz.optString("app") == "Lembra Aí") { "arquivo não é uma cópia do Lembra Aí" }
        val arr = raiz.getJSONArray("compromissos")
        return (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            CompromissoEntity(
                titulo = o.getString("titulo"), dataEpoch = o.getLong("dataEpoch"), hora = o.getInt("hora"),
                diasAntes = o.optInt("diasAntes", 1),
                janelaInicio = if (o.isNull("janelaInicio")) null else o.getInt("janelaInicio"),
                janelaFim = if (o.isNull("janelaFim")) null else o.getInt("janelaFim"),
                modo = o.optString("modo", "INTERVALO"), intervalo = o.optInt("intervalo", 60), vezes = o.optInt("vezes", 3),
                horarios = o.optString("horarios", ""), naHora = o.optBoolean("naHora", true), antes = o.optString("antes", "60"),
                foraJanelaOk = o.optBoolean("foraJanelaOk", true), estilo = o.optString("estilo", "TOCAR_E_VIBRAR"),
                falar = o.optBoolean("falar", true), repete = o.optString("repete", "NAO_REPETE"),
                diasSemana = o.optString("diasSemana", ""), cadaDias = o.optInt("cadaDias", 2),
                ateEpoch = if (o.isNull("ateEpoch")) null else o.getLong("ateEpoch"),
                observacao = o.optString("observacao", ""), telefone = o.optString("telefone", ""),
                endereco = o.optString("endereco", ""), feitos = o.optString("feitos", ""),
                codigoId = o.optString("codigoId", ""), enviadoPor = o.optString("enviadoPor", ""),
            )
        }
    }

    suspend fun restaurar(ctx: Context, l: List<CompromissoEntity>) {
        dao(ctx).trocarTudo(l)
        Agendador.reagendar(ctx)
    }
}
