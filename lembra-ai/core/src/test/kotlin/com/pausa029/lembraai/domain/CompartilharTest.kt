package com.pausa029.lembraai.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate

class CompartilharTest {
    private val janela = Janela()
    private val base = Compromisso(
        titulo = "Consulta com o doutor João", data = LocalDate.of(2026, 11, 20), hora = 630,
        observacao = "Levar os exames", telefone = "(11) 3333-4444", endereco = "Rua das Flores, 120",
    )

    private fun idaEVolta(c: Compromisso, de: String = "Luiz"): Compromisso {
        val cod = Compartilhar.codificar(c, "1b4e28ba-2fa1-11d2-883f-0016d3cca427", de)
        val l = Compartilhar.decodificar(cod.link)
        assertTrue("não leu: $l", l is Compartilhar.Leitura.Ok)
        return (l as Compartilhar.Leitura.Ok).pacote.compromisso
    }

    /** Compara tudo que vai no link (situação/histórico não vão). */
    private fun semLocal(c: Compromisso) = c.copy(id = 0, feitos = emptySet(), codigoId = "", enviadoPor = "")

    @Test fun `ida e volta devolve o mesmo compromisso nos 3 modos`() {
        val variacoes = listOf(
            base,
            base.copy(frequencia = Frequencia(ModoFrequencia.INTERVALO, intervaloMin = 90), janela = Janela(480, 1200), diasAntes = 3),
            base.copy(frequencia = Frequencia(ModoFrequencia.VEZES, vezes = 5), avisarNaHora = false, avisosAntes = listOf(15, 120)),
            base.copy(
                frequencia = Frequencia(ModoFrequencia.HORARIOS, horarios = listOf(420, 720, 1080)),
                estilo = EstiloAviso.SO_VIBRAR, falar = false, avisarForaDaJanela = false,
                repeticao = Repeticao(TipoRepeticao.DIAS_DA_SEMANA, setOf(DayOfWeek.MONDAY, DayOfWeek.THURSDAY), ate = LocalDate.of(2027, 2, 1)),
            ),
            base.copy(repeticao = Repeticao(TipoRepeticao.A_CADA_X_DIAS, cadaDias = 3)),
            base.copy(repeticao = Repeticao(TipoRepeticao.TODO_MES), observacao = "", telefone = "", endereco = ""),
        )
        for (c in variacoes) {
            val volta = idaEVolta(c.copy(id = 7, feitos = setOf(c.data)))
            assertEquals(semLocal(c), semLocal(volta))
            assertEquals("Luiz", volta.enviadoPor)
            assertEquals("1b4e28ba-2fa1-11d2-883f-0016d3cca427", volta.codigoId)
            assertTrue("histórico não pode ir no link", volta.feitos.isEmpty())
        }
    }

    @Test fun `alarmes de quem recebe sao iguais aos de quem enviou`() {
        val volta = idaEVolta(base)
        assertEquals(CalculoAvisos.daOcorrencia(base, base.data, janela), CalculoAvisos.daOcorrencia(volta, volta.data, janela))
    }

    @Test fun `acento, emoji e mensagem inteira do WhatsApp`() {
        val c = base.copy(titulo = "Aniversário da vó 🎂 — São João", observacao = "Levar \"bolo\" e açúcar\nNão esquecer!")
        val cod = Compartilhar.codificar(c, "x1", "Luiz")
        assertTrue(cod.codigo.startsWith("LA1."))
        val msg = Compartilhar.mensagem(c, cod.link)
        assertTrue(msg.contains("*Aniversário da vó 🎂 — São João*"))
        assertTrue(msg.contains("Sexta-feira, 20 de novembro de 2026, às 10h30"))
        val l = Compartilhar.decodificar(msg) as Compartilhar.Leitura.Ok
        assertEquals(c.titulo, l.pacote.compromisso.titulo)
        assertEquals(c.observacao, l.pacote.compromisso.observacao)
        // também pelo esquema próprio
        assertTrue(Compartilhar.decodificar(Compartilhar.ESQUEMA + cod.codigo) is Compartilhar.Leitura.Ok)
    }

    @Test fun `observacao longa e cortada para caber no limite`() {
        val longa = (1..900).joinToString(" ") { "palavra$it" }
        val cod = Compartilhar.codificar(base.copy(observacao = longa), "x2", "")
        assertTrue(cod.codigo.length <= Compartilhar.LIMITE)
        assertTrue(cod.observacaoCortada)
        val volta = (Compartilhar.decodificar(cod.codigo) as Compartilhar.Leitura.Ok).pacote.compromisso
        assertTrue(volta.observacao.isNotEmpty() && volta.observacao.length < longa.length)
        assertTrue(!Compartilhar.codificar(base, "x3", "").observacaoCortada)
    }

    @Test fun `codigo quebrado, vazio ou versao nova nao trava`() {
        val bom = Compartilhar.codificar(base, "x4", "").codigo
        assertEquals(Compartilhar.Leitura.Nenhum, Compartilhar.decodificar(""))
        assertEquals(Compartilhar.Leitura.Nenhum, Compartilhar.decodificar("Bom dia, tudo bem?"))
        assertEquals(Compartilhar.Leitura.Quebrado, Compartilhar.decodificar(bom.dropLast(15)))
        assertEquals(Compartilhar.Leitura.Quebrado, Compartilhar.decodificar("LA1.aaaaaaaaaaaaaaaaaaaa"))
        assertEquals(Compartilhar.Leitura.Quebrado, Compartilhar.decodificar("LA1."))
        assertEquals(Compartilhar.Leitura.VersaoNova, Compartilhar.decodificar("LA2." + bom.removePrefix("LA1.")))
    }

    @Test fun `valores fora dos limites sao corrigidos`() {
        val c = base.copy(diasAntes = 99, frequencia = Frequencia(ModoFrequencia.VEZES, intervaloMin = 1, vezes = 500))
        val volta = idaEVolta(c)
        assertEquals(30, volta.diasAntes)
        assertEquals(20, volta.frequencia.vezes)
        assertEquals(15, volta.frequencia.intervaloMin)
    }

    @Test fun `json minimo le e escreve`() {
        val m = mapOf("a" to listOf(1, 2), "b" to "x\"y\\z\n", "c" to null, "d" to true)
        assertEquals(m, Json.ler(Json.escrever(m)).let { o -> (o as Map<*, *>).mapValues { (_, v) -> if (v is List<*>) v.map { (it as Number).toInt() } else v } })
    }
}
