package com.pausa029.lembraai.domain

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth
import java.time.temporal.ChronoUnit

/** Datas, horas e durações escritas como gente fala, em português do Brasil. */
object Texto {
    val MESES = listOf("janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro")
    val SEMANA_CURTA = listOf("Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb")

    fun diaSemana(d: DayOfWeek) = when (d) {
        DayOfWeek.MONDAY -> "segunda-feira"
        DayOfWeek.TUESDAY -> "terça-feira"
        DayOfWeek.WEDNESDAY -> "quarta-feira"
        DayOfWeek.THURSDAY -> "quinta-feira"
        DayOfWeek.FRIDAY -> "sexta-feira"
        DayOfWeek.SATURDAY -> "sábado"
        DayOfWeek.SUNDAY -> "domingo"
    }

    fun diaSemanaCurto(d: DayOfWeek) = diaSemana(d).substringBefore('-')

    fun abreviado(d: DayOfWeek) = SEMANA_CURTA[d.value % 7]

    fun cap(s: String) = s.replaceFirstChar { it.uppercaseChar() }

    fun hora(minutos: Int): String {
        val h = minutos / 60
        val m = minutos % 60
        return if (m == 0) "${h}h" else "${h}h" + m.toString().padStart(2, '0')
    }

    fun hora(t: LocalDateTime) = hora(t.hour * 60 + t.minute)

    /** "sexta-feira, 13 de novembro de 2026" */
    fun dataCompleta(d: LocalDate) = "${diaSemana(d.dayOfWeek)}, ${d.dayOfMonth} de ${MESES[d.monthValue - 1]} de ${d.year}"

    /** "sexta-feira, 13 de novembro" */
    fun dataSemAno(d: LocalDate) = "${diaSemana(d.dayOfWeek)}, ${d.dayOfMonth} de ${MESES[d.monthValue - 1]}"

    /** "13 de novembro de 2026" */
    fun dataSemSemana(d: LocalDate) = "${d.dayOfMonth} de ${MESES[d.monthValue - 1]} de ${d.year}"

    /** "NOVEMBRO DE 2026" */
    fun mesAno(m: YearMonth) = "${MESES[m.monthValue - 1].uppercase()} DE ${m.year}"

    fun nomeMes(n: Int) = cap(MESES[n - 1])

    /** hoje / amanhã / depois de amanhã / na sexta-feira, dia 21 */
    fun quando(dia: LocalDate, hoje: LocalDate): String {
        val n = ChronoUnit.DAYS.between(hoje, dia)
        return when (n) {
            0L -> "hoje"
            1L -> "amanhã"
            2L -> "depois de amanhã"
            else -> {
                val prep = if (dia.dayOfWeek == DayOfWeek.SATURDAY || dia.dayOfWeek == DayOfWeek.SUNDAY) "no" else "na"
                if (n in 3..6) "$prep ${diaSemana(dia.dayOfWeek)}" else "$prep ${diaSemana(dia.dayOfWeek)}, dia ${dia.dayOfMonth}"
            }
        }
    }

    /** Para frases do tipo "salvo para ...": hoje / amanhã / sexta-feira, 21 de novembro */
    fun paraQuando(dia: LocalDate, hoje: LocalDate): String {
        val n = ChronoUnit.DAYS.between(hoje, dia)
        return when {
            n == 0L -> "hoje"
            n == 1L -> "amanhã"
            n == 2L -> "depois de amanhã"
            dia.year == hoje.year -> dataSemAno(dia)
            else -> dataCompleta(dia)
        }
    }

    fun plural(n: Long, um: String, varios: String) = "$n ${if (n == 1L) um else varios}"

    fun juntar(itens: List<String>): String = when (itens.size) {
        0 -> ""
        1 -> itens[0]
        else -> itens.dropLast(1).joinToString(", ") + " e " + itens.last()
    }

    /** "1 hora e 20 minutos", "2 dias e 3 horas", "30 minutos" */
    fun duracao(totalMin: Long): String {
        val d = totalMin / 1440
        val h = (totalMin % 1440) / 60
        val m = totalMin % 60
        val partes = mutableListOf<String>()
        if (d > 0) partes += plural(d, "dia", "dias")
        if (h > 0) partes += plural(h, "hora", "horas")
        if (m > 0 && d == 0L) partes += plural(m, "minuto", "minutos")
        return if (partes.isEmpty()) "menos de 1 minuto" else juntar(partes)
    }

    /** "Falta 1 hora e 20 minutos" / "Faltam 30 minutos" */
    fun falta(totalMin: Long): String {
        if (totalMin <= 0) return "É agora"
        val txt = duracao(totalMin)
        val primeiro = txt.substringBefore(' ').toLongOrNull() ?: 0
        return (if (primeiro == 1L) "Falta " else "Faltam ") + txt
    }

    /** "de 1 em 1 hora", "de 30 em 30 minutos", "de 1h30 em 1h30" */
    fun intervalo(min: Int): String = when {
        min % 60 == 0 -> { val h = min / 60; "de $h em $h ${if (h == 1) "hora" else "horas"}" }
        min < 60 -> "de $min em $min minutos"
        else -> { val s = hora(min); "de $s em $s" }
    }

    /** "1 hora antes", "15 minutos antes", "1 dia antes" */
    fun antes(min: Int) = duracao(min.toLong()) + " antes"

    fun vezes(n: Int) = if (n == 1) "1 vez" else "$n vezes"
}
