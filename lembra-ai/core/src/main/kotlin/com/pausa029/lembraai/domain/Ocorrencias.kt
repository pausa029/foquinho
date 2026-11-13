package com.pausa029.lembraai.domain

import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.ChronoUnit

/** Datas em que um compromisso acontece, levando em conta a repetição. */
object Ocorrencias {

    fun entre(c: Compromisso, de: LocalDate, ate: LocalDate): List<LocalDate> {
        val r = c.repeticao
        val fim = if (r.repete && r.ate != null && r.ate < ate) r.ate else ate
        if (fim < de || c.data > fim) return emptyList()
        val lista = mutableListOf<LocalDate>()
        when (r.tipo) {
            TipoRepeticao.NAO_REPETE -> if (c.data in de..fim) lista += c.data
            TipoRepeticao.TODO_DIA -> passo(c.data, 1, de, fim, lista)
            TipoRepeticao.TODA_SEMANA -> passo(c.data, 7, de, fim, lista)
            TipoRepeticao.A_CADA_X_DIAS -> passo(c.data, r.cadaDias.coerceIn(1, 365), de, fim, lista)
            TipoRepeticao.DIAS_DA_SEMANA -> {
                val dias = r.diasSemana.ifEmpty { setOf(c.data.dayOfWeek) }
                var d = maxOf(c.data, de)
                while (d <= fim) { if (d.dayOfWeek in dias) lista += d; d = d.plusDays(1) }
            }
            TipoRepeticao.TODO_MES -> {
                var k = 0L
                while (true) {
                    val d = mesmoDiaNoMes(c.data, YearMonth.from(c.data).plusMonths(k))
                    if (d > fim) break
                    if (d >= de) lista += d
                    k++
                }
            }
            TipoRepeticao.TODO_ANO -> {
                var k = 0L
                while (true) {
                    val d = c.data.plusYears(k) // 29/02 vira 28/02 nos anos sem 29
                    if (d > fim) break
                    if (d >= de) lista += d
                    k++
                }
            }
        }
        return lista
    }

    /** Dia 31 em mês de 30 dias vira o último dia do mês. */
    fun mesmoDiaNoMes(original: LocalDate, mes: YearMonth): LocalDate =
        mes.atDay(minOf(original.dayOfMonth, mes.lengthOfMonth()))

    fun acontece(c: Compromisso, dia: LocalDate) = entre(c, dia, dia).isNotEmpty()

    /** Próxima ocorrência a partir de [de] (inclusive), procurando até 2 anos à frente. */
    fun proxima(c: Compromisso, de: LocalDate): LocalDate? = entre(c, de, de.plusYears(2)).firstOrNull()

    private fun passo(inicio: LocalDate, n: Int, de: LocalDate, fim: LocalDate, lista: MutableList<LocalDate>) {
        var d = inicio
        if (de > inicio) {
            val dist = ChronoUnit.DAYS.between(inicio, de)
            d = inicio.plusDays(((dist + n - 1) / n) * n)
        }
        while (d <= fim) { lista += d; d = d.plusDays(n.toLong()) }
    }
}
