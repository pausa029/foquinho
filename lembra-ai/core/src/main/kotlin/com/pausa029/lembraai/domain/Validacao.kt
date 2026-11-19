package com.pausa029.lembraai.domain

import java.time.LocalDate

/**
 * Confere e corrige um compromisso que veio de fora (cópia restaurada, versão antiga do banco).
 * Nada que chega de um arquivo pode travar o app: valores fora dos limites são corrigidos,
 * e o que não tem conserto (sem nome, data absurda) é descartado.
 */
object Validacao {
    const val MAX_TITULO = 200
    const val MAX_OBS = 1000
    const val MAX_TEL = 40
    const val MAX_END = 300
    const val MAX_COMPROMISSOS = 5000
    private val DATA_MIN = LocalDate.of(2000, 1, 1)
    private val DATA_MAX = LocalDate.of(2200, 12, 31)

    private fun texto(s: String, max: Int) = s.filter { it == '\n' || !it.isISOControl() }.trim().take(max)

    fun sanear(c: Compromisso): Compromisso? {
        val titulo = texto(c.titulo, MAX_TITULO)
        if (titulo.isEmpty() || c.data < DATA_MIN || c.data > DATA_MAX) return null
        val f = c.frequencia
        val r = c.repeticao
        return c.copy(
            titulo = titulo,
            hora = c.hora.coerceIn(0, MINUTOS_DIA),
            diasAntes = c.diasAntes.coerceIn(0, 30),
            janela = c.janela?.takeIf { it.valida },
            frequencia = f.copy(
                intervaloMin = f.intervaloMin.coerceIn(CalculoAvisos.INTERVALO_MINIMO, 12 * 60),
                vezes = f.vezes.coerceIn(1, CalculoAvisos.MAX_VEZES),
                horarios = f.horarios.filter { it in 0..MINUTOS_DIA }.distinct().sorted().take(24),
            ),
            avisosAntes = c.avisosAntes.filter { it in 1..7 * 1440 }.distinct().take(10),
            repeticao = r.copy(
                cadaDias = r.cadaDias.coerceIn(2, 90),
                ate = r.ate?.takeIf { it >= c.data && it <= DATA_MAX },
            ),
            observacao = texto(c.observacao, MAX_OBS + 1),
            telefone = texto(c.telefone, MAX_TEL).filter { it.isDigit() || it in "+()- " },
            endereco = texto(c.endereco, MAX_END),
            feitos = c.feitos.filter { it in DATA_MIN..DATA_MAX }.toSet(),
            codigoId = c.codigoId.filter { it.isLetterOrDigit() || it == '-' }.take(64),
            enviadoPor = texto(c.enviadoPor, 40),
        )
    }
}
