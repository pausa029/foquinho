package com.pausa029.lembraai.domain

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

/** Todas as frases que o app mostra ou fala. */
object Mensagens {

    data class Item(val titulo: String, val dia: LocalDate, val hora: Int)

    /** "Lembrete: amanhã você tem Consulta às 10h30." / "Lembrete: hoje você tem: Consulta às 10h30 e Banco às 15h." */
    fun lembrete(itens: List<Item>, hoje: LocalDate): String {
        if (itens.isEmpty()) return ""
        val ordenados = itens.sortedWith(compareBy({ it.dia }, { it.hora }, { it.titulo }))
        if (ordenados.size == 1) {
            val i = ordenados[0]
            return "Lembrete: ${Texto.quando(i.dia, hoje)} você tem ${i.titulo} às ${Texto.hora(i.hora)}."
        }
        val partes = ordenados.groupBy { it.dia }.map { (dia, l) ->
            val lista = Texto.juntar(l.map { "${it.titulo} às ${Texto.hora(it.hora)}" })
            "${Texto.cap(Texto.quando(dia, hoje))} você tem${if (l.size > 1) ":" else ""} $lista."
        }
        return "Lembrete: " + partes.joinToString(" ").replaceFirstChar { it.lowercaseChar() }
    }

    /** "Atenção! Falta 1 hora para Consulta com o doutor João (10h30)." */
    fun antes(titulo: String, hora: Int, minutosAntes: Int) =
        "Atenção! ${Texto.falta(minutosAntes.toLong())} para $titulo (${Texto.hora(hora)})."

    fun naHora(titulo: String, hora: Int) = "Hora do seu compromisso: $titulo, às ${Texto.hora(hora)}."

    /** "Bom dia! Hoje você tem 2 compromissos: Consulta às 10h30 e Banco às 15h." */
    fun bomDia(itens: List<Item>): String {
        val l = itens.sortedBy { it.hora }
        val qtd = if (l.size == 1) "1 compromisso" else "${l.size} compromissos"
        return "Bom dia! Hoje você tem $qtd: " + Texto.juntar(l.map { "${it.titulo} às ${Texto.hora(it.hora)}" }) + "."
    }

    /** Texto da notificação de um grupo de avisos repetidos (e do bom dia) que caem no mesmo minuto. */
    fun textoDoGrupo(grupo: List<Aviso>, compromissos: Map<Long, Compromisso>): String {
        if (grupo.isEmpty()) return ""
        val hoje = grupo.first().quando.toLocalDate()
        val repetidos = grupo.filter { it.tipo == TipoAviso.REPETIDO }
            .mapNotNull { a -> compromissos[a.compromissoId]?.let { Item(it.titulo, a.ocorrencia, it.hora) } }
        if (grupo.none { it.tipo == TipoAviso.BOM_DIA }) return lembrete(repetidos, hoje)
        val deHoje = CalculoAvisos.doDia(compromissos.values, hoje).filter { hoje !in it.feitos }.map { Item(it.titulo, hoje, it.hora) }
        val outros = repetidos.filter { it.dia != hoje }
        val bom = if (deHoje.isEmpty()) "Bom dia!" else bomDia(deHoje)
        return if (outros.isEmpty()) bom else bom + " " + lembrete(outros, hoje)
    }

    /** "Pronto! Compromisso salvo para amanhã às 9h30." */
    fun salvo(c: Compromisso, hoje: LocalDate, editado: Boolean = false) =
        "Pronto! Compromisso ${if (editado) "alterado" else "salvo"} para ${Texto.paraQuando(c.data, hoje)} às ${Texto.hora(c.hora)}."

    /** Para o botão "OUVIR OS COMPROMISSOS DESTE DIA". */
    fun ouvirDia(dia: LocalDate, itens: List<Compromisso>, hoje: LocalDate): String {
        val cabeca = Texto.cap(if (dia == hoje) "hoje, ${Texto.dataSemAno(dia)}" else Texto.dataSemAno(dia))
        if (itens.isEmpty()) return "$cabeca. Nenhum compromisso neste dia."
        val qtd = if (itens.size == 1) "Você tem 1 compromisso." else "Você tem ${itens.size} compromissos."
        return "$cabeca. $qtd " + itens.joinToString(" ") { c ->
            val feito = if (dia in c.feitos) " Já feito." else ""
            "Às ${Texto.hora(c.hora)}, ${c.titulo}.$feito"
        }
    }

    /** Frase de "como vou avisar": "Vou te avisar desde quinta, de 1 em 1 hora, das 7h às 22h, e também 1 hora antes e na hora." */
    fun comoAvisar(c: Compromisso, padrao: Janela): String {
        val j = CalculoAvisos.janelaDe(c, padrao)
        val inicio = c.data.minusDays(c.diasAntes.toLong())
        val desde = when {
            c.diasAntes <= 0 -> "Vou te avisar no próprio dia"
            c.diasAntes <= 6 -> "Vou te avisar desde ${Texto.diaSemanaCurto(inicio.dayOfWeek)}"
            else -> "Vou te avisar desde ${inicio.dayOfMonth} de ${Texto.MESES[inicio.monthValue - 1]}"
        }
        val f = c.frequencia
        val freq = when (f.modo) {
            ModoFrequencia.INTERVALO -> "${Texto.intervalo(maxOf(CalculoAvisos.INTERVALO_MINIMO, f.intervaloMin))}, das ${Texto.hora(j.inicio)} às ${Texto.hora(j.fim)}"
            ModoFrequencia.VEZES -> "${Texto.vezes(f.vezes.coerceIn(1, CalculoAvisos.MAX_VEZES))} por dia, das ${Texto.hora(j.inicio)} às ${Texto.hora(j.fim)}"
            ModoFrequencia.HORARIOS -> {
                val h = CalculoAvisos.horariosDoDia(f, j)
                if (h.isEmpty()) "sem avisos repetidos" else "às " + Texto.juntar(h.map { Texto.hora(it) })
            }
        }
        val esp = c.avisosAntes.filter { it > 0 }.distinct().sortedDescending().map { Texto.antes(it) } +
            (if (c.avisarNaHora) listOf("na hora") else emptyList())
        val final = if (esp.isEmpty()) "." else ", e também ${Texto.juntar(esp)}."
        val rep = repeticao(c)
        return "$desde, $freq$final" + (if (rep.isEmpty()) "" else " $rep")
    }

    fun repeticao(c: Compromisso): String {
        val r = c.repeticao
        val base = when (r.tipo) {
            TipoRepeticao.NAO_REPETE -> return ""
            TipoRepeticao.TODO_DIA -> "Repete todo dia"
            TipoRepeticao.TODA_SEMANA -> "Repete toda semana"
            TipoRepeticao.TODO_MES -> "Repete todo mês"
            TipoRepeticao.TODO_ANO -> "Repete todo ano"
            TipoRepeticao.A_CADA_X_DIAS -> "Repete a cada ${r.cadaDias} dias"
            TipoRepeticao.DIAS_DA_SEMANA -> {
                val dias = r.diasSemana.ifEmpty { setOf(c.data.dayOfWeek) }.sortedBy { it.value }
                "Repete " + Texto.juntar(dias.map { d ->
                    val nome = Texto.diaSemanaCurto(d)
                    (if (d.value >= 6) "aos ${nome}s" else "às ${nome}s")
                })
            }
        }
        return base + if (r.ate != null) ", até ${Texto.dataSemSemana(r.ate)}." else ", para sempre."
    }

    /** Resumo mostrado antes de salvar. */
    fun resumo(c: Compromisso, padrao: Janela): String =
        "${c.titulo}, ${Texto.dataCompleta(c.data)}, às ${Texto.hora(c.hora)}. ${comoAvisar(c, padrao)}"

    /** Prévia: "Quinta: 7h, 8h, 9h … 22h (16 avisos). Sexta: 7h, 8h, 9h, 9h30, 10h30." */
    fun previa(c: Compromisso, padrao: Janela): String {
        val avisos = CalculoAvisos.daOcorrencia(c, c.data, padrao)
        if (avisos.isEmpty()) return "Nenhum aviso."
        val longo = c.diasAntes > 6
        return avisos.groupBy { it.quando.toLocalDate() }.entries.joinToString(" ") { (dia, l) ->
            val nome = Texto.cap(Texto.diaSemanaCurto(dia.dayOfWeek)) + if (longo) " (${dia.dayOfMonth}/${dia.monthValue})" else ""
            val hs = l.map { Texto.hora(it.quando) }
            val lista = if (hs.size > 6) "${hs.take(3).joinToString(", ")} … ${hs.last()} (${hs.size} avisos)" else hs.joinToString(", ")
            "$nome: $lista."
        }
    }

    /** "Vou começar a avisar na quinta-feira, 19 de novembro." */
    fun comecoDosAvisos(c: Compromisso): String {
        if (c.diasAntes <= 0) return "Vou avisar só no dia do compromisso."
        val d = c.data.minusDays(c.diasAntes.toLong())
        val prep = if (d.dayOfWeek.value >= 6) "no" else "na"
        return "Vou começar a avisar $prep ${Texto.dataSemAno(d)}."
    }

    /** Texto simples dos próximos 7 dias, para mandar pelo WhatsApp. */
    fun agendaDaSemana(compromissos: Collection<Compromisso>, hoje: LocalDate): String {
        val sb = StringBuilder("Minha agenda dos próximos 7 dias (Lembra Aí):\n")
        var algum = false
        for (k in 0L until 7L) {
            val dia = hoje.plusDays(k)
            val l = CalculoAvisos.doDia(compromissos, dia)
            if (l.isEmpty()) continue
            algum = true
            sb.append("\n").append(Texto.cap(Texto.dataSemAno(dia))).append(":\n")
            l.forEach { c ->
                sb.append("• ").append(Texto.hora(c.hora)).append(" — ").append(c.titulo)
                if (dia in c.feitos) sb.append(" (feito)")
                if (c.observacao.isNotBlank()) sb.append(" (").append(c.observacao.trim()).append(")")
                if (c.endereco.isNotBlank()) sb.append(" — ").append(c.endereco.trim())
                sb.append("\n")
            }
        }
        if (!algum) sb.append("\nNenhum compromisso marcado.\n")
        return sb.toString().trimEnd()
    }

    /** "Falta 1 hora e 20 minutos" até o compromisso. */
    fun faltaPara(c: Compromisso, dia: LocalDate, agora: LocalDateTime): String {
        val alvo = dia.atTime(c.hora / 60, c.hora % 60)
        return Texto.falta(ChronoUnit.MINUTES.between(agora.withSecond(0).withNano(0), alvo))
    }

    fun situacao(s: Situacao) = when (s) {
        Situacao.PENDENTE -> "Pendente"
        Situacao.FEITO -> "Feito ✓"
        Situacao.NAO_RESPONDIDO -> "Não respondido"
    }
}
