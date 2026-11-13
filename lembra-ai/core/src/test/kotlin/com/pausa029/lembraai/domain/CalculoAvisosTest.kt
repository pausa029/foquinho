package com.pausa029.lembraai.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth

class CalculoAvisosTest {
    private val janela = Janela(7 * 60, 22 * 60)
    private val sexta = LocalDate.of(2026, 11, 20)
    private val quinta = sexta.minusDays(1)

    private fun h(hh: Int, mm: Int = 0) = hh * 60 + mm
    private fun horas(l: List<Aviso>, dia: LocalDate) = l.filter { it.quando.toLocalDate() == dia }.map { Texto.hora(it.quando) }

    private fun consulta(
        data: LocalDate = sexta, hora: Int = h(10, 30), diasAntes: Int = 1,
        freq: Frequencia = Frequencia(), id: Long = 1, titulo: String = "Consulta",
    ) = Compromisso(id = id, titulo = titulo, data = data, hora = hora, diasAntes = diasAntes, frequencia = freq)

    @Test fun `exemplo obrigatorio - sexta 10h30, 1 dia antes, de 1 em 1 hora`() {
        val avisos = CalculoAvisos.daOcorrencia(consulta(), sexta, janela)
        assertEquals((7..22).map { "${it}h" }, horas(avisos, quinta))
        assertEquals(16, avisos.count { it.quando.toLocalDate() == quinta })
        assertEquals(listOf("7h", "8h", "9h", "9h30", "10h30"), horas(avisos, sexta))
        val especiais = avisos.filter { it.especial }
        assertEquals(listOf(TipoAviso.ANTES, TipoAviso.NA_HORA), especiais.map { it.tipo })
        assertEquals(LocalDateTime.of(2026, 11, 20, 9, 30), especiais[0].quando)
        assertEquals(60, especiais[0].minutosAntes)
        assertEquals(
            "Quinta: 7h, 8h, 9h … 22h (16 avisos). Sexta: 7h, 8h, 9h, 9h30, 10h30.",
            Mensagens.previa(consulta(), janela),
        )
    }

    @Test fun `repetidos respeitam a janela 7h-22h`() {
        val avisos = CalculoAvisos.daOcorrencia(consulta(diasAntes = 3, freq = Frequencia(intervaloMin = 45)), sexta, janela)
        avisos.filter { it.tipo == TipoAviso.REPETIDO }.forEach {
            val m = CalculoAvisos.minutoDoDia(it.quando)
            assertTrue("fora da janela: ${it.quando}", m in h(7)..h(22))
        }
    }

    @Test fun `repetido a menos de 15 min de um especial nao dispara`() {
        val c = consulta(hora = h(10, 10), diasAntes = 0) // 1 hora antes = 9h10; 9h fica a 10 min
        assertEquals(listOf("7h", "8h", "9h10", "10h10"), horas(CalculoAvisos.daOcorrencia(c, sexta, janela), sexta))
    }

    @Test fun `compromisso fora da janela - 6h e 23h`() {
        val cedo = consulta(hora = h(6), diasAntes = 1)
        val a = CalculoAvisos.daOcorrencia(cedo, sexta, janela)
        assertEquals(listOf("5h", "6h"), horas(a, sexta)) // especiais, avisando mesmo assim (padrão SIM)
        assertTrue(a.filter { it.tipo == TipoAviso.REPETIDO }.all { it.quando.toLocalDate() == quinta })
        assertTrue(CalculoAvisos.temEspecialForaDaJanela(cedo, janela))

        val semForaJanela = cedo.copy(avisarForaDaJanela = false)
        assertEquals(emptyList<String>(), horas(CalculoAvisos.daOcorrencia(semForaJanela, sexta, janela), sexta))

        val tarde = consulta(hora = h(23), diasAntes = 0)
        assertEquals((7..22).map { "${it}h" } + "23h", horas(CalculoAvisos.daOcorrencia(tarde, sexta, janela), sexta))
        assertFalse(CalculoAvisos.temEspecialForaDaJanela(consulta(), janela))
    }

    @Test fun `comecar no mesmo dia com compromisso as 8h - so 7h e 8h`() {
        val a = CalculoAvisos.daOcorrencia(consulta(hora = h(8), diasAntes = 0), sexta, janela)
        assertEquals(listOf("7h", "8h"), horas(a, sexta))
        assertEquals(2, a.size)
    }

    @Test fun `modo A - intervalo personalizado de 1h30`() {
        val l = CalculoAvisos.horariosDoDia(Frequencia(ModoFrequencia.INTERVALO, intervaloMin = 90), janela)
        assertEquals(listOf("7h", "8h30", "10h", "11h30", "13h", "14h30", "16h", "17h30", "19h", "20h30", "22h"), l.map { Texto.hora(it) })
        // mínimo de 15 minutos
        assertEquals(h(7, 15), CalculoAvisos.horariosDoDia(Frequencia(intervaloMin = 5), janela)[1])
    }

    @Test fun `modo B - quantidade de vezes espalhada na janela`() {
        assertEquals(listOf("7h", "14h30", "22h"), CalculoAvisos.horariosDoDia(Frequencia(ModoFrequencia.VEZES, vezes = 3), janela).map { Texto.hora(it) })
        assertEquals(listOf("7h"), CalculoAvisos.horariosDoDia(Frequencia(ModoFrequencia.VEZES, vezes = 1), janela).map { Texto.hora(it) })
        assertEquals(20, CalculoAvisos.horariosDoDia(Frequencia(ModoFrequencia.VEZES, vezes = 50), janela).size)
    }

    @Test fun `modo C - horarios escolhidos, sem passar da hora do compromisso`() {
        val f = Frequencia(ModoFrequencia.HORARIOS, horarios = listOf(h(18), h(7), h(12), h(23)))
        assertEquals(listOf(h(7), h(12), h(18)), CalculoAvisos.horariosDoDia(f, janela)) // 23h fora da janela
        val c = consulta(hora = h(15), freq = f).copy(avisosAntes = emptyList())
        val a = CalculoAvisos.daOcorrencia(c, sexta, janela)
        assertEquals(listOf("7h", "12h", "18h"), horas(a, quinta))
        assertEquals(listOf("7h", "12h", "15h"), horas(a, sexta))
    }

    @Test fun `janela diferente por compromisso`() {
        val c = consulta(hora = h(16), diasAntes = 0, freq = Frequencia(intervaloMin = 120)).copy(janela = Janela(h(9), h(13)))
        assertEquals(listOf("9h", "11h", "13h", "15h", "16h"), horas(CalculoAvisos.daOcorrencia(c, sexta, janela), sexta))
    }

    @Test fun `no dia do compromisso nenhum repetido passa do horario dele`() {
        val c = consulta(hora = h(12), diasAntes = 0).copy(avisosAntes = emptyList(), avisarNaHora = false)
        assertEquals(listOf("7h", "8h", "9h", "10h", "11h"), horas(CalculoAvisos.daOcorrencia(c, sexta, janela), sexta))
    }

    @Test fun `repeticao semanal`() {
        val c = consulta().copy(repeticao = Repeticao(TipoRepeticao.TODA_SEMANA))
        assertEquals(
            listOf(sexta, sexta.plusDays(7), sexta.plusDays(14)),
            Ocorrencias.entre(c, sexta.minusDays(3), sexta.plusDays(15)),
        )
        val dias = consulta(data = LocalDate.of(2026, 11, 16)).copy(
            repeticao = Repeticao(TipoRepeticao.DIAS_DA_SEMANA, diasSemana = setOf(DayOfWeek.MONDAY, DayOfWeek.WEDNESDAY)),
        )
        assertEquals(
            listOf(16, 18, 23, 25).map { LocalDate.of(2026, 11, it) },
            Ocorrencias.entre(dias, LocalDate.of(2026, 11, 1), LocalDate.of(2026, 11, 26)),
        )
        assertEquals("Repete às segundas e às quartas, para sempre.", Mensagens.repeticao(dias))
    }

    @Test fun `repeticao mensal - dia 31 vira ultimo dia do mes`() {
        val c = consulta(data = LocalDate.of(2026, 10, 31)).copy(repeticao = Repeticao(TipoRepeticao.TODO_MES))
        assertEquals(
            listOf(LocalDate.of(2026, 10, 31), LocalDate.of(2026, 11, 30), LocalDate.of(2026, 12, 31), LocalDate.of(2027, 1, 31), LocalDate.of(2027, 2, 28)),
            Ocorrencias.entre(c, LocalDate.of(2026, 10, 1), LocalDate.of(2027, 3, 1)),
        )
    }

    @Test fun `repeticao com data final e a cada X dias`() {
        val c = consulta().copy(repeticao = Repeticao(TipoRepeticao.A_CADA_X_DIAS, cadaDias = 3, ate = sexta.plusDays(7)))
        assertEquals(listOf(sexta.plusDays(3), sexta.plusDays(6)), Ocorrencias.entre(c, sexta.plusDays(1), sexta.plusDays(30)))
        val ano = consulta(data = LocalDate.of(2028, 2, 29)).copy(repeticao = Repeticao(TipoRepeticao.TODO_ANO))
        assertEquals(listOf(LocalDate.of(2029, 2, 28)), Ocorrencias.entre(ano, LocalDate.of(2029, 1, 1), LocalDate.of(2029, 12, 31)))
    }

    @Test fun `compromisso repetido agenda os proximos 60 dias`() {
        val c = consulta(data = LocalDate.of(2026, 11, 14), hora = h(9), diasAntes = 0)
            .copy(repeticao = Repeticao(TipoRepeticao.TODO_DIA), frequencia = Frequencia(ModoFrequencia.VEZES, vezes = 1))
        val agora = LocalDateTime.of(2026, 11, 13, 12, 0)
        val l = CalculoAvisos.proximos(listOf(c), janela, false, agora)
        assertTrue(l.all { it.quando > agora && it.quando <= agora.plusDays(60) })
        assertEquals(60, l.filter { it.tipo == TipoAviso.NA_HORA }.size)
    }

    @Test fun `ja fiz cancela os avisos da ocorrencia, a proxima repeticao continua`() {
        val c = consulta().copy(repeticao = Repeticao(TipoRepeticao.TODA_SEMANA))
        val agora = LocalDateTime.of(2026, 11, 19, 6, 0)
        val antes = CalculoAvisos.proximos(listOf(c), janela, false, agora, 10)
        assertTrue(antes.any { it.ocorrencia == sexta })
        val feito = c.copy(feitos = setOf(sexta))
        val depois = CalculoAvisos.proximos(listOf(feito), janela, false, agora, 10)
        assertTrue(depois.none { it.ocorrencia == sexta })
        assertTrue(depois.any { it.ocorrencia == sexta.plusDays(7) })
        assertEquals(Situacao.FEITO, CalculoAvisos.situacao(feito, sexta, agora))
        assertEquals(Situacao.PENDENTE, CalculoAvisos.situacao(c, sexta, agora))
        assertEquals(Situacao.NAO_RESPONDIDO, CalculoAvisos.situacao(c, sexta, LocalDateTime.of(2026, 11, 20, 11, 0)))
    }

    @Test fun `edicao recalcula e exclusao cancela`() {
        val agora = LocalDateTime.of(2026, 11, 19, 6, 0)
        val c = consulta()
        val original = CalculoAvisos.proximos(listOf(c), janela, false, agora)
        val editado = CalculoAvisos.proximos(listOf(c.copy(hora = h(15))), janela, false, agora)
        assertTrue(original.any { it.tipo == TipoAviso.NA_HORA && it.quando == LocalDateTime.of(2026, 11, 20, 10, 30) })
        assertTrue(editado.none { it.quando == LocalDateTime.of(2026, 11, 20, 10, 30) })
        assertTrue(editado.any { it.tipo == TipoAviso.NA_HORA && it.quando == LocalDateTime.of(2026, 11, 20, 15, 0) })
        assertTrue(CalculoAvisos.proximos(emptyList(), janela, false, agora).isEmpty())
    }

    @Test fun `dois compromissos no mesmo dia - avisos juntados`() {
        val consultaC = consulta(diasAntes = 0, id = 1, titulo = "Consulta")
        val banco = consulta(hora = h(15), diasAntes = 0, id = 2, titulo = "Banco")
        val agora = LocalDateTime.of(2026, 11, 20, 6, 0)
        val grupos = CalculoAvisos.agrupar(CalculoAvisos.proximos(listOf(consultaC, banco), janela, false, agora))
        val das7 = grupos.first()
        assertEquals(LocalDateTime.of(2026, 11, 20, 7, 0), das7.first().quando)
        assertEquals(2, das7.size)
        val mapa = mapOf(1L to consultaC, 2L to banco)
        assertEquals("Lembrete: hoje você tem: Consulta às 10h30 e Banco às 15h.", Mensagens.textoDoGrupo(das7, mapa))
        val umSo = grupos.first { g -> g.size == 1 && g[0].tipo == TipoAviso.REPETIDO }
        assertTrue(Mensagens.textoDoGrupo(umSo, mapa).startsWith("Lembrete: hoje você tem Banco às 15h"))
    }

    @Test fun `bom dia com os compromissos do dia`() {
        val a = consulta(diasAntes = 0, id = 1, titulo = "Consulta")
        val b = consulta(hora = h(15), diasAntes = 0, id = 2, titulo = "Banco")
        val agora = LocalDateTime.of(2026, 11, 20, 6, 0)
        val g = CalculoAvisos.agrupar(CalculoAvisos.proximos(listOf(a, b), janela, true, agora)).first()
        assertTrue(g.any { it.tipo == TipoAviso.BOM_DIA })
        assertEquals("Bom dia! Hoje você tem 2 compromissos: Consulta às 10h30 e Banco às 15h.", Mensagens.textoDoGrupo(g, mapOf(1L to a, 2L to b)))
    }

    @Test fun `virada de mes e de ano`() {
        val anoNovo = consulta(data = LocalDate.of(2027, 1, 1), hora = h(9), diasAntes = 2)
        val dias = CalculoAvisos.daOcorrencia(anoNovo, anoNovo.data, janela).map { it.quando.toLocalDate() }.distinct()
        assertEquals(listOf(LocalDate.of(2026, 12, 30), LocalDate.of(2026, 12, 31), LocalDate.of(2027, 1, 1)), dias)
        val dezembro = consulta(data = LocalDate.of(2026, 12, 1), diasAntes = 1)
        assertEquals(LocalDate.of(2026, 11, 30), CalculoAvisos.daOcorrencia(dezembro, dezembro.data, janela).first().quando.toLocalDate())
        val contagem = CalculoAvisos.contagemDoMes(listOf(anoNovo), YearMonth.of(2027, 1))
        assertEquals(mapOf(LocalDate.of(2027, 1, 1) to 1), contagem)
    }

    @Test fun `proximo compromisso de hoje`() {
        val a = consulta(diasAntes = 0, id = 1, titulo = "Consulta")
        val b = consulta(hora = h(15), diasAntes = 0, id = 2, titulo = "Banco")
        assertEquals("Banco", CalculoAvisos.proximoDeHoje(listOf(a, b), LocalDateTime.of(2026, 11, 20, 11, 0))?.titulo)
        assertEquals("Falta 1 hora e 20 minutos", Mensagens.faltaPara(a, sexta, LocalDateTime.of(2026, 11, 20, 9, 10)))
    }
}
