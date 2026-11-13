package com.pausa029.lembraai.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pausa029.lembraai.domain.Texto
import java.time.LocalDate
import java.time.YearMonth

/** Calendário do mês grande, com setas, botão HOJE e ESCOLHER MÊS. */
@Composable
fun Calendario(
    mes: YearMonth,
    onMes: (YearMonth) -> Unit,
    selecionado: LocalDate?,
    contagem: Map<LocalDate, Int>,
    onDia: (LocalDate) -> Unit,
    hoje: LocalDate = LocalDate.now(),
) {
    var escolherMes by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            Texto.mesAno(mes), modifier = Modifier.fillMaxWidth(),
            fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, color = Cores.texto,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Botao("◀ MÊS ANTERIOR", { onMes(mes.minusMonths(1)) }, Modifier.weight(1f), tamanho = 18.sp)
            Botao("PRÓXIMO MÊS ▶", { onMes(mes.plusMonths(1)) }, Modifier.weight(1f), tamanho = 18.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            BotaoContorno("HOJE", { onMes(YearMonth.from(hoje)); onDia(hoje) }, Modifier.weight(1f), tamanho = 18.sp)
            BotaoContorno("ESCOLHER MÊS", { escolherMes = true }, Modifier.weight(1f), tamanho = 18.sp)
        }
        Row {
            Texto.SEMANA_CURTA.forEach {
                Text(it, Modifier.weight(1f), fontSize = 18.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, color = Cores.suave)
            }
        }
        val deslocamento = mes.atDay(1).dayOfWeek.value % 7 // domingo = 0
        val total = deslocamento + mes.lengthOfMonth()
        val linhas = (total + 6) / 7
        for (l in 0 until linhas) {
            Row {
                for (col in 0 until 7) {
                    val n = l * 7 + col - deslocamento + 1
                    if (n < 1 || n > mes.lengthOfMonth()) {
                        Spacer(Modifier.weight(1f).height(66.dp))
                    } else {
                        val d = mes.atDay(n)
                        DiaCelula(d, d == selecionado, d == hoje, contagem[d] ?: 0, { onDia(d) }, Modifier.weight(1f))
                    }
                }
            }
        }
    }
    if (escolherMes) {
        EscolherMes(mes, { onMes(it); escolherMes = false }, { escolherMes = false })
    }
}

@Composable
private fun DiaCelula(d: LocalDate, selecionado: Boolean, ehHoje: Boolean, qtd: Int, onClick: () -> Unit, modifier: Modifier) {
    val fundo = when {
        selecionado -> Cores.azul
        qtd > 0 -> Cores.azulClaro
        else -> Color.White
    }
    val corTexto = if (selecionado) Color.White else Cores.texto
    val descricao = buildString {
        append("${Texto.diaSemana(d.dayOfWeek)}, dia ${d.dayOfMonth}")
        if (ehHoje) append(", hoje")
        if (qtd == 1) append(", 1 compromisso") else if (qtd > 1) append(", $qtd compromissos")
        if (selecionado) append(", escolhido")
    }
    Box(
        modifier
            .height(66.dp)
            .padding(2.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(fundo)
            .border(if (ehHoje) 4.dp else 1.dp, if (ehHoje) Cores.texto else Color(0xFFBDBDBD), RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .semantics { contentDescription = descricao },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("${d.dayOfMonth}", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = corTexto)
            if (qtd > 0) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(10.dp).clip(CircleShape).background(if (selecionado) Color.White else Cores.laranja))
                    Text(" $qtd", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = corTexto)
                }
            }
        }
    }
}

/** Os 12 meses em botões grandes, com setas para trocar o ano. */
@Composable
fun EscolherMes(atual: YearMonth, onEscolhe: (YearMonth) -> Unit, onFechar: () -> Unit) {
    var ano by remember { mutableIntStateOf(atual.year) }
    Caixa(onFechar) {
        Text("Escolha o mês", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Cores.texto)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Botao("◀", { ano-- }, Modifier.size(72.dp), tamanho = 28.sp, altura = 72)
            Text("$ano", Modifier.weight(1f), fontSize = 34.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Botao("▶", { ano++ }, Modifier.size(72.dp), tamanho = 28.sp, altura = 72)
        }
        Grade((1..12).map { Texto.nomeMes(it) to (ano == atual.year && it == atual.monthValue) }, colunas = 2) { i ->
            onEscolhe(YearMonth.of(ano, i + 1))
        }
        BotaoContorno("FECHAR", onFechar)
    }
}

/** Escolher um dia num calendário que abre por cima da tela. */
@Composable
fun EscolherDia(titulo: String, inicial: LocalDate, onEscolhe: (LocalDate) -> Unit, onFechar: () -> Unit) {
    var mes by remember { mutableStateOf(YearMonth.from(inicial)) }
    Caixa(onFechar) {
        Text(titulo, fontSize = 26.sp, fontWeight = FontWeight.Bold, color = Cores.azul, lineHeight = 32.sp)
        Calendario(mes, { mes = it }, inicial, emptyMap(), onEscolhe)
        BotaoContorno("FECHAR", onFechar)
    }
}
