package com.pausa029.lembraai.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.pausa029.lembraai.domain.Texto

object Cores {
    val azul = Color(0xFF0B3D91)
    val azulClaro = Color(0xFFDDE8FB)
    val verde = Color(0xFF1B5E20)
    val verdeClaro = Color(0xFFDFF3E0)
    val vermelho = Color(0xFFB71C1C)
    val amarelo = Color(0xFFFFE082)
    val amareloBorda = Color(0xFFB26A00)
    val laranja = Color(0xFFD84315)
    val texto = Color(0xFF111111)
    val suave = Color(0xFF3A3A3A)
    val fundo = Color(0xFFFFFDF7)
    val branco = Color.White
    val borda = Color(0xFF5A5A5A)
}

@Composable
fun LembraTema(escala: Float, conteudo: @Composable () -> Unit) {
    val esquema = lightColorScheme(
        primary = Cores.azul, onPrimary = Color.White,
        secondary = Cores.verde, onSecondary = Color.White,
        background = Cores.fundo, onBackground = Cores.texto,
        surface = Color.White, onSurface = Cores.texto,
        error = Cores.vermelho,
    )
    val tipos = Typography(
        bodyLarge = TextStyle(fontSize = 20.sp, lineHeight = 28.sp),
        bodyMedium = TextStyle(fontSize = 20.sp, lineHeight = 28.sp),
        bodySmall = TextStyle(fontSize = 18.sp, lineHeight = 24.sp),
        titleLarge = TextStyle(fontSize = 28.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold),
        titleMedium = TextStyle(fontSize = 24.sp, lineHeight = 30.sp, fontWeight = FontWeight.Bold),
        labelLarge = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold),
    )
    val d = LocalDensity.current
    CompositionLocalProvider(LocalDensity provides Density(d.density, d.fontScale * escala)) {
        MaterialTheme(colorScheme = esquema, typography = tipos) { conteudo() }
    }
}

private val forma = RoundedCornerShape(14.dp)

@Composable
fun Botao(
    texto: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier.fillMaxWidth(),
    cor: Color = Cores.azul,
    corTexto: Color = Color.White,
    tamanho: TextUnit = 22.sp,
    altura: Int = 64,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        modifier = modifier.heightIn(min = altura.dp),
        enabled = enabled,
        shape = forma,
        colors = ButtonDefaults.buttonColors(containerColor = cor, contentColor = corTexto),
        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp),
    ) {
        Text(texto, fontSize = tamanho, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, lineHeight = (tamanho.value + 4).sp)
    }
}

@Composable
fun BotaoContorno(
    texto: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier.fillMaxWidth(),
    cor: Color = Cores.azul,
    tamanho: TextUnit = 20.sp,
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.heightIn(min = 64.dp),
        shape = forma,
        border = BorderStroke(3.dp, cor),
        colors = ButtonDefaults.outlinedButtonColors(containerColor = Color.White, contentColor = cor),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
    ) {
        Text(texto, fontSize = tamanho, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, lineHeight = (tamanho.value + 4).sp)
    }
}

/** Opção que fica marcada: além da cor, aparece o "✓" escrito (não depende só de cor). */
@Composable
fun Opcao(texto: String, marcado: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier.fillMaxWidth()) {
    if (marcado) Botao("✓ $texto", onClick, modifier, tamanho = 20.sp)
    else BotaoContorno(texto, onClick, modifier, cor = Cores.azul, tamanho = 20.sp)
}

/** Opções em grade (2 colunas por padrão). */
@Composable
fun Grade(itens: List<Pair<String, Boolean>>, colunas: Int = 2, onClick: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        itens.chunked(colunas).forEachIndexed { linha, grupo ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                grupo.forEachIndexed { i, (t, m) ->
                    Opcao(t, m, { onClick(linha * colunas + i) }, Modifier.weight(1f))
                }
                repeat(colunas - grupo.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
fun Bloco(numero: String?, titulo: String, conteudo: @Composable ColumnScope.() -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        color = Color.White,
        border = BorderStroke(2.dp, Cores.borda),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                if (numero != null) "$numero — $titulo" else titulo,
                fontSize = 26.sp, fontWeight = FontWeight.Bold, color = Cores.azul, lineHeight = 32.sp,
            )
            conteudo()
        }
    }
}

@Composable
fun Frase(texto: String, tamanho: TextUnit = 20.sp, cor: Color = Cores.texto, negrito: Boolean = false, modifier: Modifier = Modifier) {
    Text(texto, modifier = modifier, fontSize = tamanho, color = cor, lineHeight = (tamanho.value * 1.35f).sp, fontWeight = if (negrito) FontWeight.Bold else FontWeight.Normal)
}

@Composable
fun Destaque(texto: String, fundo: Color = Cores.azulClaro, cor: Color = Cores.texto) {
    Surface(Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp), color = fundo) {
        Frase(texto, 20.sp, cor, negrito = true, modifier = Modifier.padding(14.dp))
    }
}

/** Escolher um número com botões grandes de − e +. */
@Composable
fun MaisMenos(rotulo: String, valor: String, onMenos: () -> Unit, onMais: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Frase(rotulo, 20.sp, negrito = true)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Botao("−", onMenos, Modifier.size(72.dp), tamanho = 34.sp, altura = 72)
            Text(
                valor, modifier = Modifier.weight(1f).semantics { contentDescription = "$rotulo: $valor" },
                fontSize = 32.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, color = Cores.texto,
            )
            Botao("+", onMais, Modifier.size(72.dp), tamanho = 34.sp, altura = 72)
        }
    }
}

/** Seletor grande de hora e minuto, sem relógio de ponteiro. Minutos de 5 em 5, com opção de 1 em 1. */
@Composable
fun SeletorHora(rotulo: String, minutos: Int, onMuda: (Int) -> Unit) {
    var passo by remember { mutableIntStateOf(5) }
    val h = minutos / 60
    val m = minutos % 60
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Frase("$rotulo: ${Texto.hora(minutos)}", 24.sp, Cores.azul, negrito = true)
        MaisMenos("Hora", "${h}h", { onMuda(((h + 23) % 24) * 60 + m) }, { onMuda(((h + 1) % 24) * 60 + m) })
        MaisMenos(
            "Minutos", m.toString().padStart(2, '0'),
            { onMuda(h * 60 + ((m - passo) % 60 + 60) % 60) },
            { onMuda(h * 60 + (m + passo) % 60) },
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Opcao("De 5 em 5 min", passo == 5, { passo = 5 }, Modifier.weight(1f))
            Opcao("De 1 em 1 min", passo == 1, { passo = 1 }, Modifier.weight(1f))
        }
    }
}

@Composable
fun AvisoAmarelo(texto: String, botao: String? = null, onBotao: () -> Unit = {}) {
    Surface(
        Modifier.fillMaxWidth(), shape = RoundedCornerShape(14.dp),
        color = Cores.amarelo, border = BorderStroke(3.dp, Cores.amareloBorda),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Frase("⚠ $texto", 20.sp, Cores.texto, negrito = true)
            if (botao != null) Botao(botao, onBotao, cor = Cores.texto)
        }
    }
}

@Composable
fun Mensagem(texto: String) {
    Surface(
        Modifier.fillMaxWidth(), shape = RoundedCornerShape(14.dp),
        color = Cores.verdeClaro, border = BorderStroke(3.dp, Cores.verde),
    ) {
        Frase(texto, 22.sp, Cores.verde, negrito = true, modifier = Modifier.padding(16.dp))
    }
}

/** Janela por cima da tela, larga e rolável. */
@Composable
fun Caixa(onFechar: () -> Unit, conteudo: @Composable ColumnScope.() -> Unit) {
    Dialog(onDismissRequest = onFechar, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(
            Modifier.fillMaxWidth(0.95f).padding(vertical = 16.dp),
            shape = RoundedCornerShape(20.dp), color = Color.White,
        ) {
            Column(
                Modifier.verticalScroll(rememberScrollState()).padding(18.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) { conteudo() }
        }
    }
}

/** Pergunta com dois botões grandes, um embaixo do outro. */
@Composable
fun Pergunta(
    titulo: String,
    texto: String,
    sim: String,
    nao: String,
    onSim: () -> Unit,
    onNao: () -> Unit,
    corSim: Color = Cores.verde,
    onFechar: () -> Unit = onNao,
) {
    Caixa(onFechar) {
        Text(titulo, fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Cores.texto, lineHeight = 34.sp)
        if (texto.isNotBlank()) Frase(texto, 22.sp)
        Botao(sim, onSim, cor = corSim)
        BotaoContorno(nao, onNao)
    }
}

@Composable
fun Informacao(texto: String, onFechar: () -> Unit) {
    Caixa(onFechar) {
        Frase(texto, 22.sp, negrito = true)
        Botao("OK, ENTENDI", onFechar)
    }
}

@Composable
fun Linha(cor: Color = Cores.borda) {
    Spacer(Modifier.fillMaxWidth().height(2.dp).background(cor))
}

@Composable
fun Etiqueta(texto: String, cor: Color) {
    Text(
        texto,
        modifier = Modifier.border(2.dp, cor, RoundedCornerShape(8.dp)).padding(horizontal = 10.dp, vertical = 4.dp),
        color = cor, fontSize = 18.sp, fontWeight = FontWeight.Bold,
    )
}
