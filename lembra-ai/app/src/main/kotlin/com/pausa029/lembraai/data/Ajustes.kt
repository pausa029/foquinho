package com.pausa029.lembraai.data

import android.content.Context
import android.content.SharedPreferences
import com.pausa029.lembraai.domain.EstiloAviso
import com.pausa029.lembraai.domain.Frequencia
import com.pausa029.lembraai.domain.Janela
import com.pausa029.lembraai.domain.ModoFrequencia
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** Configurações do app e padrões para novos compromissos. */
data class Preferencias(
    val boasVindasFeita: Boolean = false,
    val janela: Janela = Janela(),
    val diasAntes: Int = 1,
    val frequencia: Frequencia = Frequencia(ModoFrequencia.INTERVALO, 60, 3, listOf(7 * 60, 12 * 60, 18 * 60)),
    val avisarNaHora: Boolean = true,
    val avisosAntes: List<Int> = listOf(60),
    val estilo: EstiloAviso = EstiloAviso.TOCAR_E_VIBRAR,
    val falar: Boolean = true,
    /** 0 = Normal, 1 = Grande, 2 = Muito grande */
    val letra: Int = 1,
    /** 0 = alarme do celular, 1 = sino, 2 = bipe forte, 3 = toque do celular */
    val som: Int = 0,
    /** 1 a 10 */
    val volume: Int = 10,
    val bomDia: Boolean = true,
) {
    val escalaLetra get() = when (letra) { 0 -> 1.0f; 2 -> 1.3f; else -> 1.15f }
}

object Ajustes {
    private val estado = MutableStateFlow<Preferencias?>(null)

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.applicationContext.createDeviceProtectedStorageContext().getSharedPreferences("ajustes", Context.MODE_PRIVATE)

    fun fluxo(ctx: Context): StateFlow<Preferencias> {
        if (estado.value == null) estado.value = ler(ctx)
        @Suppress("UNCHECKED_CAST")
        return estado as StateFlow<Preferencias>
    }

    fun atual(ctx: Context): Preferencias = estado.value ?: ler(ctx).also { estado.value = it }

    private fun lista(s: String?): List<Int>? = s?.split(',')?.mapNotNull { it.trim().toIntOrNull() }

    private fun ler(ctx: Context): Preferencias {
        val p = prefs(ctx)
        val d = Preferencias()
        return Preferencias(
            boasVindasFeita = p.getBoolean("boasVindas", false),
            janela = Janela(p.getInt("janelaInicio", d.janela.inicio), p.getInt("janelaFim", d.janela.fim)),
            diasAntes = p.getInt("diasAntes", d.diasAntes),
            frequencia = Frequencia(
                modo = runCatching { ModoFrequencia.valueOf(p.getString("modo", null) ?: "") }.getOrDefault(d.frequencia.modo),
                intervaloMin = p.getInt("intervalo", d.frequencia.intervaloMin),
                vezes = p.getInt("vezes", d.frequencia.vezes),
                horarios = lista(p.getString("horarios", null)) ?: d.frequencia.horarios,
            ),
            avisarNaHora = p.getBoolean("naHora", d.avisarNaHora),
            avisosAntes = lista(p.getString("antes", null)) ?: d.avisosAntes,
            estilo = runCatching { EstiloAviso.valueOf(p.getString("estilo", null) ?: "") }.getOrDefault(d.estilo),
            falar = p.getBoolean("falar", d.falar),
            letra = p.getInt("letra", d.letra),
            som = p.getInt("som", d.som),
            volume = p.getInt("volume", d.volume),
            bomDia = p.getBoolean("bomDia", d.bomDia),
        )
    }

    fun salvar(ctx: Context, n: Preferencias) {
        prefs(ctx).edit()
            .putBoolean("boasVindas", n.boasVindasFeita)
            .putInt("janelaInicio", n.janela.inicio)
            .putInt("janelaFim", n.janela.fim)
            .putInt("diasAntes", n.diasAntes)
            .putString("modo", n.frequencia.modo.name)
            .putInt("intervalo", n.frequencia.intervaloMin)
            .putInt("vezes", n.frequencia.vezes)
            .putString("horarios", n.frequencia.horarios.joinToString(","))
            .putBoolean("naHora", n.avisarNaHora)
            .putString("antes", n.avisosAntes.joinToString(","))
            .putString("estilo", n.estilo.name)
            .putBoolean("falar", n.falar)
            .putInt("letra", n.letra)
            .putInt("som", n.som)
            .putInt("volume", n.volume)
            .putBoolean("bomDia", n.bomDia)
            .apply()
        estado.value = n
    }

    // ---- controle interno dos disparos ----

    fun ultimoDisparo(ctx: Context): Long = prefs(ctx).getLong("ultimoDisparo", 0L)

    fun marcarDisparo(ctx: Context, millis: Long) {
        prefs(ctx).edit().putLong("ultimoDisparo", millis).apply()
    }
}
