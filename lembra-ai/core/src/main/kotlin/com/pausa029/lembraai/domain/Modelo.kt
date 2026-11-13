package com.pausa029.lembraai.domain

import java.time.DayOfWeek
import java.time.LocalDate

/** Faixa do dia em que o app pode avisar, em minutos desde a meia-noite (inclusive nas duas pontas). */
data class Janela(val inicio: Int = 7 * 60, val fim: Int = 22 * 60) {
    fun contem(minuto: Int) = minuto in inicio..fim
    val valida get() = inicio in 0..MINUTOS_DIA && fim in 0..MINUTOS_DIA && inicio < fim
}

const val MINUTOS_DIA = 24 * 60 - 1

/** A = de quanto em quanto tempo, B = quantas vezes no dia, C = horários escolhidos. */
enum class ModoFrequencia { INTERVALO, VEZES, HORARIOS }

data class Frequencia(
    val modo: ModoFrequencia = ModoFrequencia.INTERVALO,
    val intervaloMin: Int = 60,
    val vezes: Int = 3,
    val horarios: List<Int> = emptyList(),
)

enum class TipoRepeticao { NAO_REPETE, TODO_DIA, TODA_SEMANA, TODO_MES, TODO_ANO, DIAS_DA_SEMANA, A_CADA_X_DIAS }

data class Repeticao(
    val tipo: TipoRepeticao = TipoRepeticao.NAO_REPETE,
    val diasSemana: Set<DayOfWeek> = emptySet(),
    val cadaDias: Int = 2,
    val ate: LocalDate? = null,
) {
    val repete get() = tipo != TipoRepeticao.NAO_REPETE
}

enum class EstiloAviso { TOCAR_E_VIBRAR, SO_VIBRAR, SO_TOCAR }

data class Compromisso(
    val id: Long = 0,
    val titulo: String,
    val data: LocalDate,
    /** Minutos desde a meia-noite. */
    val hora: Int,
    /** Quantos dias antes começam os avisos repetidos (0 = só no dia). */
    val diasAntes: Int = 1,
    /** null = usa o horário de avisos das configurações. */
    val janela: Janela? = null,
    val frequencia: Frequencia = Frequencia(),
    val avisarNaHora: Boolean = true,
    /** Avisos especiais (tela cheia): minutos antes do compromisso. */
    val avisosAntes: List<Int> = listOf(60),
    /** Avisar mesmo quando o aviso especial cai fora do horário de avisos. */
    val avisarForaDaJanela: Boolean = true,
    val estilo: EstiloAviso = EstiloAviso.TOCAR_E_VIBRAR,
    val falar: Boolean = true,
    val repeticao: Repeticao = Repeticao(),
    val observacao: String = "",
    val telefone: String = "",
    val endereco: String = "",
    /** Ocorrências marcadas como "Já fiz". */
    val feitos: Set<LocalDate> = emptySet(),
)

enum class TipoAviso { REPETIDO, ANTES, NA_HORA, BOM_DIA }

data class Aviso(
    val quando: java.time.LocalDateTime,
    val tipo: TipoAviso,
    val compromissoId: Long,
    /** Data da ocorrência do compromisso a que o aviso se refere. */
    val ocorrencia: LocalDate,
    val minutosAntes: Int = 0,
) {
    val especial get() = tipo == TipoAviso.ANTES || tipo == TipoAviso.NA_HORA
}

enum class Situacao { PENDENTE, FEITO, NAO_RESPONDIDO }
