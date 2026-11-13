package com.pausa029.lembraai.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.pausa029.lembraai.domain.CalculoAvisos
import com.pausa029.lembraai.domain.Compromisso
import com.pausa029.lembraai.domain.Mensagens
import com.pausa029.lembraai.domain.Situacao
import com.pausa029.lembraai.domain.Texto
import kotlinx.coroutines.delay
import java.time.LocalDate

@Composable
fun TelaCompromissos(vm: LembraViewModel) {
    val ctx = LocalContext.current
    val lista by vm.compromissos.collectAsState()
    val hoje = vm.agora.toLocalDate()
    val doDia = CalculoAvisos.doDia(lista, vm.dia)

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        vm.mensagem?.let { m ->
            Mensagem(m)
            LaunchedEffect(m) { delay(9_000); if (vm.mensagem == m) vm.mensagem = null }
        }
        AvisosDePermissao()

        Calendario(vm.mes, { vm.mes = it }, vm.dia, CalculoAvisos.contagemDoMes(lista, vm.mes), { vm.dia = it }, hoje)
        Linha()
        Text(
            Texto.cap(Texto.dataCompleta(vm.dia)) + if (vm.dia == hoje) " (hoje)" else "",
            fontSize = 26.sp, fontWeight = FontWeight.Bold, color = Cores.texto, lineHeight = 32.sp,
        )

        if (vm.dia == hoje) {
            CalculoAvisos.proximoDeHoje(lista, vm.agora)?.let { c -> CartaoProximo(c, vm) }
        }

        if (doDia.isEmpty()) {
            Frase("Nenhum compromisso neste dia.", 22.sp, Cores.suave)
        } else {
            doDia.forEach { c -> ItemDoDia(c, vm.dia, vm) }
        }

        Botao(
            "🔊 OUVIR OS COMPROMISSOS DESTE DIA",
            { Voz.falarSempre(ctx, Mensagens.ouvirDia(vm.dia, doDia, hoje)) },
            cor = Cores.verde,
        )
        Botao("+ AGENDAR NESTE DIA", { vm.novo(vm.dia) })
        Spacer(Modifier.height(20.dp))
    }
}

@Composable
private fun CartaoProximo(c: Compromisso, vm: LembraViewModel) {
    Surface(
        Modifier.fillMaxWidth().clickable { vm.tela = Tela.Detalhe(c.id, vm.dia) },
        shape = RoundedCornerShape(18.dp), color = Cores.azul,
    ) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("PRÓXIMO COMPROMISSO", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color.White)
            Text(Texto.hora(c.hora), fontSize = 52.sp, fontWeight = FontWeight.Bold, color = Color.White)
            Text(c.titulo, fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Color.White, lineHeight = 34.sp)
            Text(Mensagens.faltaPara(c, vm.agora.toLocalDate(), vm.agora), fontSize = 24.sp, color = Color(0xFFFFE082), fontWeight = FontWeight.Bold)
        }
    }
}

fun corDaSituacao(s: Situacao) = when (s) {
    Situacao.PENDENTE -> Cores.azul
    Situacao.FEITO -> Cores.verde
    Situacao.NAO_RESPONDIDO -> Cores.vermelho
}

@Composable
private fun ItemDoDia(c: Compromisso, dia: LocalDate, vm: LembraViewModel) {
    val s = CalculoAvisos.situacao(c, dia, vm.agora)
    val situacao = Mensagens.situacao(s)
    Surface(
        Modifier.fillMaxWidth()
            .clickable { vm.tela = Tela.Detalhe(c.id, dia) }
            .semantics { contentDescription = "${Texto.hora(c.hora)}, ${c.titulo}, $situacao. Toque para ver os detalhes." },
        shape = RoundedCornerShape(16.dp), color = Color.White,
        border = BorderStroke(3.dp, corDaSituacao(s)),
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                Texto.hora(c.hora), Modifier.widthIn(min = 120.dp),
                fontSize = 40.sp, fontWeight = FontWeight.Bold, color = Cores.texto,
            )
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(c.titulo, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Cores.texto, lineHeight = 30.sp)
                Etiqueta(situacao, corDaSituacao(s))
                if (c.repeticao.repete) Frase("🔁 " + Mensagens.repeticao(c).removeSuffix("."), 18.sp, Cores.suave)
            }
            Text("▶", fontSize = 28.sp, color = Cores.azul)
        }
    }
}

/** Avisos amarelos enquanto faltar alguma permissão importante. */
@Composable
fun AvisosDePermissao() {
    val ctx = LocalContext.current
    var verificar by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { verificar++ }
    key(verificar) { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (!Permissoes.notificacoes(ctx)) AvisoAmarelo(
            "Os avisos estão desligados. Sem eles, o app não consegue te lembrar.",
            "ABRIR CONFIGURAÇÕES",
        ) { Permissoes.abrirNotificacoes(ctx) }
        if (!Permissoes.alarmes(ctx)) AvisoAmarelo(
            "Falta permitir \"Alarmes\". Sem isso, os avisos podem atrasar.",
            "ABRIR CONFIGURAÇÕES",
        ) { Permissoes.abrirAlarmes(ctx) }
        if (!Permissoes.telaCheia(ctx)) AvisoAmarelo(
            "Falta permitir a tela cheia. Sem isso, o alarme não aparece com o celular bloqueado.",
            "ABRIR CONFIGURAÇÕES",
        ) { Permissoes.abrirTelaCheia(ctx) }
        if (!Permissoes.bateria(ctx)) AvisoAmarelo(
            "O celular pode desligar os avisos para economizar bateria.",
            "LIBERAR",
        ) { Permissoes.abrirBateria(ctx) }
        if (Permissoes.silencioTotal(ctx)) AvisoAmarelo(
            "O celular está em \"Não perturbe\" com silêncio total. Assim nem o alarme toca.",
            "ABRIR CONFIGURAÇÕES",
        ) { Permissoes.abrirNaoPerturbe(ctx) }
    } }
}

@Composable
fun TelaDetalhe(vm: LembraViewModel, id: Long, dia: LocalDate) {
    val ctx = LocalContext.current
    val lista by vm.compromissos.collectAsState()
    val p by vm.prefs.collectAsState()
    val c = lista.firstOrNull { it.id == id }
    var apagar by remember { mutableStateOf(false) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        BotaoContorno("◀ VOLTAR", { vm.tela = Tela.Compromissos })
        if (c == null) {
            Frase("Este compromisso não existe mais.", 22.sp)
            return@Column
        }
        val s = CalculoAvisos.situacao(c, dia, vm.agora)
        Frase(Texto.cap(Texto.dataCompleta(dia)), 22.sp, Cores.suave, negrito = true)
        Text(Texto.hora(c.hora), fontSize = 56.sp, fontWeight = FontWeight.Bold, color = Cores.azul)
        Text(c.titulo, fontSize = 30.sp, fontWeight = FontWeight.Bold, color = Cores.texto, lineHeight = 36.sp)
        Etiqueta(Mensagens.situacao(s), corDaSituacao(s))
        if (s == Situacao.PENDENTE && dia == vm.agora.toLocalDate()) Frase(Mensagens.faltaPara(c, dia, vm.agora), 22.sp, Cores.azul, negrito = true)

        if (c.observacao.isNotBlank()) Destaque("Observação: ${c.observacao}")
        if (c.telefone.isNotBlank()) Frase("Telefone: ${c.telefone}", 22.sp)
        if (c.endereco.isNotBlank()) Frase("Endereço: ${c.endereco}", 22.sp)

        Bloco(null, "Como vou avisar") {
            Frase(Mensagens.comoAvisar(c.copy(data = dia), p.janela), 20.sp)
        }

        if (s == Situacao.FEITO) {
            BotaoContorno("DESFAZER \"JÁ FIZ\"", { vm.desfazerFeito(c, dia) })
        } else {
            Botao("✓ JÁ FIZ", { vm.feito(c, dia) }, cor = Cores.verde, tamanho = 26.sp, altura = 72)
        }
        Botao("✏ EDITAR", { vm.editar(c) })
        if (c.telefone.isNotBlank()) Botao("📞 LIGAR", {
            Permissoes.abrir(ctx, Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + c.telefone.filter { it.isDigit() || it == '+' })))
        }, cor = Cores.verde)
        if (c.endereco.isNotBlank()) Botao("🗺 COMO CHEGAR", {
            Permissoes.abrir(ctx, Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=" + Uri.encode(c.endereco))))
        }, cor = Cores.verde)
        Botao("🗑 APAGAR", { apagar = true }, cor = Cores.vermelho)
        Spacer(Modifier.height(20.dp))
    }

    if (apagar && c != null) {
        Pergunta(
            "Tem certeza?",
            "Vou apagar \"${c.titulo}\"" + (if (c.repeticao.repete) " e todas as repetições dele." else "."),
            "SIM, APAGAR", "NÃO",
            onSim = { apagar = false; vm.apagar(c) },
            onNao = { apagar = false },
            corSim = Cores.vermelho,
        )
    }
}
