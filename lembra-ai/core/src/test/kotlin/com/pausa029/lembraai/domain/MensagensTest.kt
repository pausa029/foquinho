package com.pausa029.lembraai.domain

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.YearMonth

class MensagensTest {
    private val hoje = LocalDate.of(2026, 11, 13) // sexta-feira
    private val janela = Janela()

    @Test fun datas() {
        assertEquals("sexta-feira, 13 de novembro de 2026", Texto.dataCompleta(hoje))
        assertEquals("NOVEMBRO DE 2026", Texto.mesAno(YearMonth.of(2026, 11)))
        assertEquals("10h30", Texto.hora(630))
        assertEquals("7h", Texto.hora(420))
        assertEquals("amanhã", Texto.quando(hoje.plusDays(1), hoje))
        assertEquals("na segunda-feira", Texto.quando(LocalDate.of(2026, 11, 16), hoje))
        assertEquals("no domingo, dia 22", Texto.quando(LocalDate.of(2026, 11, 22), hoje))
    }

    @Test fun duracoes() {
        assertEquals("Falta 1 hora", Texto.falta(60))
        assertEquals("Faltam 30 minutos", Texto.falta(30))
        assertEquals("Falta 1 hora e 20 minutos", Texto.falta(80))
        assertEquals("Faltam 2 dias e 3 horas", Texto.falta(2 * 1440 + 180))
        assertEquals("de 1 em 1 hora", Texto.intervalo(60))
        assertEquals("de 30 em 30 minutos", Texto.intervalo(30))
        assertEquals("de 1h30 em 1h30", Texto.intervalo(90))
    }

    @Test fun lembretes() {
        val c = Mensagens.Item("Consulta com o doutor João", hoje.plusDays(1), 630)
        assertEquals("Lembrete: amanhã você tem Consulta com o doutor João às 10h30.", Mensagens.lembrete(listOf(c), hoje))
        assertEquals("Lembrete: hoje você tem Consulta com o doutor João às 10h30.", Mensagens.lembrete(listOf(c.copy(dia = hoje)), hoje))
        assertEquals("Atenção! Falta 1 hora para Consulta com o doutor João (10h30).", Mensagens.antes("Consulta com o doutor João", 630, 60))
        val dois = Mensagens.lembrete(listOf(c.copy(dia = hoje), Mensagens.Item("Banco", hoje.plusDays(1), 900)), hoje)
        assertEquals("Lembrete: hoje você tem Consulta com o doutor João às 10h30. Amanhã você tem Banco às 15h.", dois)
    }

    @Test fun resumoAoSalvar() {
        val c = Compromisso(titulo = "Consulta com o doutor João", data = LocalDate.of(2026, 11, 20), hora = 630)
        assertEquals(
            "Consulta com o doutor João, sexta-feira, 20 de novembro de 2026, às 10h30. Vou te avisar desde quinta, de 1 em 1 hora, das 7h às 22h, e também 1 hora antes e na hora.",
            Mensagens.resumo(c, janela),
        )
        assertEquals("Pronto! Compromisso salvo para amanhã às 9h30.", Mensagens.salvo(c.copy(data = hoje.plusDays(1), hora = 570), hoje))
        assertEquals("Vou começar a avisar na quinta-feira, 19 de novembro.", Mensagens.comecoDosAvisos(c))
        val semanal = c.copy(repeticao = Repeticao(TipoRepeticao.TODA_SEMANA, ate = LocalDate.of(2026, 12, 18)))
        assertEquals("Repete toda semana, até 18 de dezembro de 2026.", Mensagens.repeticao(semanal))
    }

    @Test fun ouvirEcompartilhar() {
        val a = Compromisso(id = 1, titulo = "Consulta", data = hoje, hora = 630, observacao = "Levar os exames")
        val b = Compromisso(id = 2, titulo = "Banco", data = hoje, hora = 900)
        assertEquals(
            "Hoje, sexta-feira, 13 de novembro. Você tem 2 compromissos. Às 10h30, Consulta. Às 15h, Banco.",
            Mensagens.ouvirDia(hoje, CalculoAvisos.doDia(listOf(b, a), hoje), hoje),
        )
        val txt = Mensagens.agendaDaSemana(listOf(a, b), hoje)
        assertEquals(
            "Minha agenda dos próximos 7 dias (Lembra Aí):\n\nSexta-feira, 13 de novembro:\n• 10h30 — Consulta (Levar os exames)\n• 15h — Banco",
            txt,
        )
    }
}
