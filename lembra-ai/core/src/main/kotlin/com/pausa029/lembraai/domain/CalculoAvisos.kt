package com.pausa029.lembraai.domain

import java.time.LocalDate
import java.time.LocalDateTime
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Regras dos lembretes (seção 5 do pedido).
 *
 * - Avisos repetidos: só dentro da janela, desde [Compromisso.diasAntes] dias antes até o dia do compromisso.
 * - No dia do compromisso, os repetidos param no primeiro aviso especial do dia (ou na hora do compromisso).
 * - Repetido a menos de 15 minutos de um aviso especial não dispara.
 * - Avisos especiais ("antes" e "na hora") disparam se caírem na janela ou se [Compromisso.avisarForaDaJanela].
 */
object CalculoAvisos {
    const val DISTANCIA_MINIMA = 15
    const val INTERVALO_MINIMO = 15
    const val MAX_VEZES = 20
    const val DIAS_HORIZONTE = 60

    fun janelaDe(c: Compromisso, padrao: Janela) = c.janela ?: padrao

    /** Horários (minutos do dia) dos avisos repetidos de um dia comum. */
    fun horariosDoDia(f: Frequencia, j: Janela): List<Int> {
        if (!j.valida) return emptyList()
        return when (f.modo) {
            ModoFrequencia.INTERVALO -> {
                val passo = maxOf(INTERVALO_MINIMO, f.intervaloMin)
                generateSequence(j.inicio) { it + passo }.takeWhile { it <= j.fim }.toList()
            }
            ModoFrequencia.VEZES -> {
                val n = f.vezes.coerceIn(1, MAX_VEZES)
                if (n == 1) listOf(j.inicio)
                else (0 until n).map { i -> j.inicio + (i * (j.fim - j.inicio) / (n - 1).toDouble()).roundToInt() }.distinct()
            }
            ModoFrequencia.HORARIOS -> f.horarios.filter { j.contem(it) }.distinct().sorted()
        }
    }

    fun especiais(c: Compromisso, ocorrencia: LocalDate, padrao: Janela): List<Aviso> {
        val j = janelaDe(c, padrao)
        val momento = ocorrencia.atTime(c.hora / 60, c.hora % 60)
        val lista = mutableListOf<Aviso>()
        c.avisosAntes.filter { it > 0 }.distinct().sortedDescending().forEach { m ->
            lista += Aviso(momento.minusMinutes(m.toLong()), TipoAviso.ANTES, c.id, ocorrencia, m)
        }
        if (c.avisarNaHora) lista += Aviso(momento, TipoAviso.NA_HORA, c.id, ocorrencia, 0)
        return lista.filter { c.avisarForaDaJanela || j.contem(minutoDoDia(it.quando)) }
    }

    /** Todos os avisos de uma ocorrência, em ordem. */
    fun daOcorrencia(c: Compromisso, ocorrencia: LocalDate, padrao: Janela): List<Aviso> {
        val j = janelaDe(c, padrao)
        val momento = ocorrencia.atTime(c.hora / 60, c.hora % 60)
        val esp = especiais(c, ocorrencia, padrao)
        val corte = esp.filter { it.quando.toLocalDate() == ocorrencia && it.quando <= momento }
            .minOfOrNull { it.quando } ?: momento
        val horarios = horariosDoDia(c.frequencia, j)
        val repetidos = mutableListOf<Aviso>()
        for (k in c.diasAntes.coerceIn(0, 30) downTo 0) {
            val dia = ocorrencia.minusDays(k.toLong())
            for (h in horarios) {
                val t = dia.atTime(h / 60, h % 60)
                if (t >= corte) continue
                if (esp.any { abs(java.time.Duration.between(it.quando, t).toMinutes()) < DISTANCIA_MINIMA }) continue
                repetidos += Aviso(t, TipoAviso.REPETIDO, c.id, ocorrencia)
            }
        }
        return (repetidos + esp).sortedWith(compareBy({ it.quando }, { it.tipo.ordinal }))
    }

    /** Avisos depois de [agora], nos próximos [dias] dias, de todos os compromissos (sem os já feitos). */
    fun proximos(
        compromissos: Collection<Compromisso>,
        padrao: Janela,
        bomDia: Boolean,
        agora: LocalDateTime,
        dias: Int = DIAS_HORIZONTE,
    ): List<Aviso> {
        val hoje = agora.toLocalDate()
        val limite = agora.plusDays(dias.toLong())
        val lista = mutableListOf<Aviso>()
        for (c in compromissos) {
            val ate = hoje.plusDays((dias + c.diasAntes.coerceIn(0, 30) + 1).toLong())
            for (oc in Ocorrencias.entre(c, hoje, ate)) {
                if (oc in c.feitos) continue
                daOcorrencia(c, oc, padrao).filterTo(lista) { it.quando > agora && it.quando <= limite }
            }
        }
        if (bomDia && padrao.valida) {
            var d = hoje
            while (!d.isAfter(limite.toLocalDate())) {
                val t = d.atTime(padrao.inicio / 60, padrao.inicio % 60)
                if (t > agora && t <= limite && compromissos.any { c -> d !in c.feitos && Ocorrencias.acontece(c, d) }) {
                    lista += Aviso(t, TipoAviso.BOM_DIA, -1, d)
                }
                d = d.plusDays(1)
            }
        }
        return lista.sortedWith(compareBy({ it.quando }, { it.tipo.ordinal }, { it.compromissoId }))
    }

    /** Junta os avisos que caem no mesmo minuto (vários compromissos no mesmo horário viram um aviso só). */
    fun agrupar(avisos: List<Aviso>): List<List<Aviso>> =
        avisos.groupBy { it.quando.withSecond(0).withNano(0) }.toSortedMap().values.toList()

    fun situacao(c: Compromisso, ocorrencia: LocalDate, agora: LocalDateTime): Situacao = when {
        ocorrencia in c.feitos -> Situacao.FEITO
        ocorrencia.atTime(c.hora / 60, c.hora % 60) < agora -> Situacao.NAO_RESPONDIDO
        else -> Situacao.PENDENTE
    }

    /** Compromissos de um dia, em ordem de horário. */
    fun doDia(compromissos: Collection<Compromisso>, dia: LocalDate): List<Compromisso> =
        compromissos.filter { Ocorrencias.acontece(it, dia) }.sortedWith(compareBy({ it.hora }, { it.titulo }))

    /** Quantos compromissos há em cada dia de um mês. */
    fun contagemDoMes(compromissos: Collection<Compromisso>, mes: java.time.YearMonth): Map<LocalDate, Int> {
        val mapa = mutableMapOf<LocalDate, Int>()
        for (c in compromissos) for (d in Ocorrencias.entre(c, mes.atDay(1), mes.atEndOfMonth())) mapa[d] = (mapa[d] ?: 0) + 1
        return mapa
    }

    /** O próximo compromisso de hoje que ainda não passou e não foi feito. */
    fun proximoDeHoje(compromissos: Collection<Compromisso>, agora: LocalDateTime): Compromisso? {
        val hoje = agora.toLocalDate()
        return doDia(compromissos, hoje).firstOrNull { hoje !in it.feitos && hoje.atTime(it.hora / 60, it.hora % 60) >= agora.withSecond(0).withNano(0) }
    }

    /** Algum aviso especial cairia fora da janela? (para perguntar ao salvar) */
    fun temEspecialForaDaJanela(c: Compromisso, padrao: Janela): Boolean {
        val j = janelaDe(c, padrao)
        return especiais(c.copy(avisarForaDaJanela = true), c.data, padrao).any { !j.contem(minutoDoDia(it.quando)) }
    }

    fun minutoDoDia(t: LocalDateTime) = t.hour * 60 + t.minute
}
