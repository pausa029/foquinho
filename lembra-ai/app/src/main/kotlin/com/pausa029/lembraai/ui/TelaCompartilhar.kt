package com.pausa029.lembraai.ui

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.pausa029.lembraai.data.Agenda
import com.pausa029.lembraai.data.Ajustes
import com.pausa029.lembraai.domain.Compartilhar
import com.pausa029.lembraai.domain.Compromisso
import com.pausa029.lembraai.domain.Mensagens
import com.pausa029.lembraai.domain.Texto
import java.time.LocalDateTime

private val CINZA = Color(0xFF616161)

// ===================== enviar =====================

@Composable
fun TelaEnviar(vm: LembraViewModel, id: Long) {
    val ctx = LocalContext.current
    val lista by vm.compromissos.collectAsState()
    val p by vm.prefs.collectAsState()
    val original = lista.firstOrNull { it.id == id }
    var preparado by remember(id) { mutableStateOf<Compromisso?>(null) }
    LaunchedEffect(id, original?.codigoId) { if (original != null) preparado = Agenda.garantirCodigo(ctx, original) }
    var apagarDepois by remember { mutableStateOf(false) }
    var qr by remember { mutableStateOf(false) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        BotaoContorno("◀ VOLTAR", { vm.tela = Tela.Compromissos })
        Text("Enviar compromisso", fontSize = 30.sp, fontWeight = FontWeight.Bold)
        val c = preparado
        if (original == null || c == null) {
            Frase(if (original == null) "Este compromisso não existe mais." else "Preparando…", 22.sp)
            return@Column
        }
        val cod = remember(c, p.nome) { Compartilhar.codificar(c, c.codigoId, p.nome) }
        val mensagem = remember(cod) { Compartilhar.mensagem(c, cod.link) }
        val depois = {
            if (apagarDepois) vm.apagarDepoisDeEnviar(c)
        }

        Text(c.titulo, fontSize = 30.sp, fontWeight = FontWeight.Bold, lineHeight = 36.sp)
        Text(
            "${Texto.cap(Texto.dataCompleta(c.data))}, às ${Texto.hora(c.hora)}",
            fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Cores.azul, lineHeight = 30.sp,
        )
        Bloco(null, "Como vai avisar") { Frase(Mensagens.comoAvisar(c, p.janela), 20.sp) }
        if (cod.observacaoCortada) AvisoAmarelo("A observação era muito grande e foi cortada para caber no link.")
        if (p.nome.isBlank()) Frase("Dica: escreva seu nome em ⚙ Ajustes para a pessoa saber quem enviou.", 18.sp, Cores.suave)

        Bloco(null, "Apagar este compromisso da minha agenda depois de enviar?") {
            Frase("Útil quando você marcou só para a outra pessoa.", 18.sp, Cores.suave)
            Opcao("NÃO, DEIXAR NA MINHA AGENDA", !apagarDepois, { apagarDepois = false })
            Opcao("SIM, APAGAR DA MINHA AGENDA", apagarDepois, { apagarDepois = true })
        }

        Botao("📲 ENVIAR PELO WHATSAPP", { enviarWhatsApp(ctx, mensagem); depois() }, cor = Cores.verde, tamanho = 24.sp, altura = 76)
        Botao("📤 ENVIAR DE OUTRO JEITO", { enviarOutro(ctx, mensagem); depois() })
        Botao("🔳 MOSTRAR QR CODE", { qr = true })
        BotaoContorno("📋 COPIAR CÓDIGO", {
            copiar(ctx, cod.link)
            Ajustes.marcarCodigoVisto(ctx, cod.codigo)
            vm.avisar("Pronto! Copiei o código. É só colar na conversa.", falar = false)
            depois()
        })
        vm.mensagem?.let { Mensagem(it) }
        Spacer(Modifier.height(20.dp))

        if (qr) {
            val imagem = remember(cod) { gerarQr(cod.link) }
            Caixa({ qr = false }) {
                Text("Mostre para a pessoa", fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Frase("Peça para ela apontar a câmera do celular para este código e tocar no link que aparecer.", 20.sp)
                if (imagem != null) {
                    Image(
                        imagem.asImageBitmap(), contentDescription = "QR code do compromisso ${c.titulo}",
                        modifier = Modifier.fillMaxWidth().aspectRatio(1f), filterQuality = FilterQuality.None,
                    )
                } else {
                    AvisoAmarelo("Não consegui fazer o QR code. Use \"ENVIAR PELO WHATSAPP\".")
                }
                Botao("PRONTO, JÁ LERAM", { qr = false; depois() }, cor = Cores.verde)
                BotaoContorno("FECHAR", { qr = false })
            }
        }
    }
}

private fun enviarWhatsApp(ctx: Context, texto: String) {
    val base = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, texto)
    for (pacote in listOf("com.whatsapp", "com.whatsapp.w4b")) {
        try {
            ctx.startActivity(Intent(base).setPackage(pacote).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return
        } catch (e: ActivityNotFoundException) { /* tenta o próximo */ }
    }
    enviarOutro(ctx, texto)
}

private fun enviarOutro(ctx: Context, texto: String) {
    val base = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, texto)
    Permissoes.abrir(ctx, Intent.createChooser(base, "Enviar o compromisso"))
}

private fun copiar(ctx: Context, texto: String) {
    runCatching {
        ctx.getSystemService(ClipboardManager::class.java).setPrimaryClip(ClipData.newPlainText("Lembra Aí", texto))
    }
}

fun lerAreaDeTransferencia(ctx: Context): String? = runCatching {
    val clip = ctx.getSystemService(ClipboardManager::class.java).primaryClip ?: return null
    if (clip.itemCount == 0) null else clip.getItemAt(0).coerceToText(ctx)?.toString()
}.getOrNull()

private fun gerarQr(texto: String): Bitmap? = runCatching {
    val m = QRCodeWriter().encode(
        texto, BarcodeFormat.QR_CODE, 0, 0,
        mapOf(EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.L, EncodeHintType.MARGIN to 2, EncodeHintType.CHARACTER_SET to "UTF-8"),
    )
    val px = IntArray(m.width * m.height) { i -> if (m.get(i % m.width, i / m.width)) 0xFF000000.toInt() else 0xFFFFFFFF.toInt() }
    Bitmap.createBitmap(px, m.width, m.height, Bitmap.Config.ARGB_8888)
}.getOrNull()

// ===================== receber =====================

/** Botão "📥 RECEBER COMPROMISSO" da aba Agendar: colar código ou ler QR code. */
@Composable
fun ReceberCompromisso(vm: LembraViewModel, onFechar: () -> Unit) {
    val ctx = LocalContext.current
    var erro by remember { mutableStateOf<String?>(null) }
    Caixa(onFechar) {
        Text("Receber compromisso", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Frase("Copiou a mensagem ou o link que mandaram? Toque em COLAR CÓDIGO.", 20.sp)
        Botao("📋 COLAR CÓDIGO", {
            val t = lerAreaDeTransferencia(ctx)
            if (Compartilhar.temCodigo(t) || t?.contains("LA") == true) {
                onFechar()
                vm.receberTexto(t)
            } else {
                erro = "Não encontrei nenhum compromisso copiado. Na conversa, toque e segure a mensagem, escolha \"Copiar\" e tente de novo."
            }
        }, cor = Cores.verde)
        Botao("🔳 LER QR CODE", {
            runCatching {
                GmsBarcodeScanning.getClient(ctx).startScan()
                    .addOnSuccessListener { b -> onFechar(); vm.receberTexto(b.rawValue) }
                    .addOnFailureListener {
                        erro = "Não consegui abrir o leitor. Use a câmera do celular: aponte para o QR code e toque no link que aparecer."
                    }
            }.onFailure { erro = "Não consegui abrir o leitor. Use a câmera do celular: aponte para o QR code e toque no link que aparecer." }
        })
        erro?.let { AvisoAmarelo(it) }
        BotaoContorno("FECHAR", onFechar)
    }
}

/** Tela "Compromisso recebido": tocar no link → SALVAR NA MINHA AGENDA. */
@Composable
fun TelaRecebido(vm: LembraViewModel, pacote: Compartilhar.Pacote) {
    val ctx = LocalContext.current
    val p by vm.prefs.collectAsState()
    val c = pacote.compromisso
    var existente by remember(pacote) { mutableStateOf<Compromisso?>(null) }
    LaunchedEffect(pacote) { existente = Agenda.porCodigo(ctx, pacote.id) }
    // 0 = tela, 1 = "já tem este compromisso", 2 = "já passou"
    var pergunta by remember(pacote) { mutableIntStateOf(0) }
    val passou = !c.repeticao.repete && c.data.atTime(c.hora / 60, c.hora % 60) <= LocalDateTime.now()

    fun seguir(depoisDe: Int) {
        if (depoisDe < 1 && existente != null) { pergunta = 1; return }
        if (depoisDe < 2 && passou) { pergunta = 2; return }
        pergunta = 0
        vm.salvarRecebido(c, existente)
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Destaque(if (pacote.enviadoPor.isNotBlank()) "📩 Compromisso enviado por ${pacote.enviadoPor}" else "📩 Você recebeu um compromisso")
        Text(c.titulo, fontSize = 32.sp, fontWeight = FontWeight.Bold, lineHeight = 38.sp, color = Cores.texto)
        Text(
            "${Texto.cap(Texto.dataCompleta(c.data))}, às ${Texto.hora(c.hora)}",
            fontSize = 26.sp, fontWeight = FontWeight.Bold, color = Cores.azul, lineHeight = 32.sp,
        )
        if (c.repeticao.repete) Frase("🔁 " + Mensagens.repeticao(c), 20.sp)
        Bloco(null, "Como vou avisar") { Frase(Mensagens.comoAvisar(c, p.janela), 20.sp) }
        if (c.observacao.isNotBlank()) Destaque("Observação: ${c.observacao}")
        if (c.telefone.isNotBlank()) Frase("Telefone: ${c.telefone}", 22.sp)
        if (c.endereco.isNotBlank()) Frase("Endereço: ${c.endereco}", 22.sp)

        Botao("✓ SALVAR NA MINHA AGENDA", { seguir(0) }, cor = Cores.verde, tamanho = 28.sp, altura = 96)
        Botao("NÃO QUERO", { vm.recusarRecebido() }, cor = CINZA, tamanho = 24.sp, altura = 72)
        BotaoContorno("MUDAR ALGUMA COISA ANTES", { vm.mudarRecebido(c, existente) }, tamanho = 18.sp)
        Spacer(Modifier.height(16.dp))
    }

    when (pergunta) {
        1 -> Pergunta(
            "Você já tem este compromisso",
            "Quer trocar pelo novo?",
            "SIM, ATUALIZAR", "NÃO",
            onSim = { seguir(1) },
            onNao = { pergunta = 0; vm.recusarRecebido() },
        )
        2 -> Pergunta(
            "Já passou",
            "Este compromisso já passou (${Texto.dataSemSemana(c.data).substringBeforeLast(" de ")} às ${Texto.hora(c.hora)}). Quer salvar mesmo assim?",
            "SIM, SALVAR", "NÃO",
            onSim = { seguir(2) },
            onNao = { pergunta = 0; vm.recusarRecebido() },
        )
    }
}

/** Avisos do recebimento: código quebrado, versão nova, compromisso copiado. */
@Composable
fun AvisosDeRecebimento(vm: LembraViewModel) {
    val ctx = LocalContext.current
    when (vm.erroRecebido) {
        Compartilhar.Leitura.Quebrado, Compartilhar.Leitura.Nenhum ->
            Informacao("Não consegui ler este compromisso. Peça para enviarem de novo.") { vm.erroRecebido = null }
        Compartilhar.Leitura.VersaoNova -> Pergunta(
            "Atualize o Lembra Aí",
            "Atualize o Lembra Aí para receber este compromisso.",
            "BAIXAR A VERSÃO NOVA", "AGORA NÃO",
            onSim = {
                vm.erroRecebido = null
                Permissoes.abrir(ctx, Intent(Intent.ACTION_VIEW, Uri.parse(Compartilhar.BAIXAR_APK)))
            },
            onNao = { vm.erroRecebido = null },
        )
        else -> Unit
    }
    vm.codigoCopiado?.let { texto ->
        Pergunta(
            "Compromisso copiado",
            "Encontrei um compromisso copiado. Quer adicionar na sua agenda?",
            "SIM, VER", "NÃO",
            onSim = { vm.codigoCopiado = null; vm.receberTexto(texto) },
            onNao = { vm.codigoCopiado = null },
        )
    }
}
