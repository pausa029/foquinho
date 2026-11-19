package com.pausa029.lembraai.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class ValidacaoTest {
    private val base = Compromisso(titulo = "Consulta", data = LocalDate.of(2026, 11, 20), hora = 630)

    @Test fun `valores absurdos de um arquivo sao corrigidos e nao travam o calculo`() {
        val ruim = base.copy(
            hora = 99_999, diasAntes = -5, janela = Janela(900, 100),
            frequencia = Frequencia(ModoFrequencia.INTERVALO, intervaloMin = 0, vezes = 999, horarios = listOf(-1, 5000, 600)),
            avisosAntes = listOf(-10, 0, 60, 99_999_999), titulo = "  Consulta\u0000 ", telefone = "11<script>9999",
        )
        val c = Validacao.sanear(ruim)!!
        assertEquals(MINUTOS_DIA, c.hora)
        assertEquals(0, c.diasAntes)
        assertNull(c.janela)
        assertEquals(15, c.frequencia.intervaloMin)
        assertEquals(20, c.frequencia.vezes)
        assertEquals(listOf(600), c.frequencia.horarios)
        assertEquals(listOf(60), c.avisosAntes)
        assertEquals("Consulta", c.titulo)
        assertEquals("119999", c.telefone)
        assertTrue(CalculoAvisos.daOcorrencia(c, c.data, Janela()).isNotEmpty())
    }

    @Test fun `sem nome ou com data absurda e descartado`() {
        assertNull(Validacao.sanear(base.copy(titulo = "   ")))
        assertNull(Validacao.sanear(base.copy(data = LocalDate.of(1800, 1, 1))))
    }

    @Test fun `codigo gigante colado nao trava`() {
        assertEquals(Compartilhar.Leitura.Quebrado, Compartilhar.decodificar("LA1." + "A".repeat(50_000)))
    }
}
