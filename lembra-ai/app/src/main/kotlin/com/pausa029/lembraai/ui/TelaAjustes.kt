package com.pausa029.lembraai.ui

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import com.pausa029.lembraai.R
import com.pausa029.lembraai.alarm.Disparo
import com.pausa029.lembraai.data.Agenda
import com.pausa029.lembraai.data.CompromissoEntity
import com.pausa029.lembraai.domain.Compromisso
import com.pausa029.lembraai.domain.EstiloAviso
import com.pausa029.lembraai.domain.Janela
import com.pausa029.lembraai.domain.Mensagens
import com.pausa029.lembraai.domain.Texto
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.LocalDate

@Composable
fun TelaAjustes(vm: LembraViewModel) {
    val ctx = LocalContext.current
    val p by vm.prefs.collectAsState()
    val pAtual by rememberUpdatedState(p)
    val lista by vm.compromissos.collectAsState()
    val escopo = rememberCoroutineScope()

    var tocando by remember { mutableStateOf<MediaPlayer?>(null) }
    DisposableEffect(Unit) { onDispose { runCatching { tocando?.release() } } }

    var apagarAntigos by remember { mutableStateOf(0) }
    var restaurar by remember { mutableStateOf<List<CompromissoEntity>?>(null) }
    var info by remember { mutableStateOf<String?>(null) }

    val abrirCopia = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        escopo.launch {
            val r = withContext(Dispatchers.IO) {
                runCatching { ctx.contentResolver.openInputStream(uri)!!.bufferedReader().use { it.readText() }.let { Agenda.lerCopia(it) } }
            }
            r.onSuccess { restaurar = it }.onFailure { info = "Este arquivo não é uma cópia da agenda do Lembra Aí." }
        }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        BotaoContorno("◀ VOLTAR", { vm.tela = Tela.Compromissos })
        Text("Ajustes", fontSize = 32.sp, fontWeight = FontWeight.Bold)
        vm.mensagem?.let { Mensagem(it) }

        Bloco(null, "Testar") {
            Frase("Toque e espere 10 segundos. O alarme de teste vai tocar, mesmo com o app fechado.", 20.sp)
            Botao("🔔 TESTAR AVISO AGORA", {
                escopo.launch { Disparo.testar(ctx) }
                vm.avisar("Pronto! Em 10 segundos o celular vai tocar o aviso de teste.")
            }, cor = Cores.verde)
        }

        Bloco(null, "Horário que o app pode avisar") {
            Destaque("Das ${Texto.hora(p.janela.inicio)} às ${Texto.hora(p.janela.fim)}")
            SeletorHora("Começar às", p.janela.inicio) { vm.salvarPrefs(pAtual.copy(janela = Janela(it, pAtual.janela.fim))) }
            SeletorHora("Parar às", p.janela.fim) { vm.salvarPrefs(pAtual.copy(janela = Janela(pAtual.janela.inicio, it))) }
            if (!p.janela.valida) Frase("O começo precisa ser antes do fim. Enquanto isso, nenhum aviso repetido vai tocar.", 20.sp, Cores.vermelho, negrito = true)
        }

        Bloco(null, "Padrões para novos compromissos") {
            Frase("A partir de quando avisar:", 22.sp, negrito = true)
            val ops = listOf("Só no dia" to 0, "1 dia antes" to 1, "2 dias antes" to 2, "3 dias antes" to 3, "1 semana antes" to 7)
            Grade(ops.map { (t, n) -> t to (p.diasAntes == n) }) { i -> vm.salvarPrefs(pAtual.copy(diasAntes = ops[i].second)) }
            Linha()
            Frase("Quantas vezes avisar por dia:", 22.sp, negrito = true)
            val modelo = Compromisso(titulo = "", data = LocalDate.now(), hora = 12 * 60, frequencia = p.frequencia)
            BlocoFrequencia(modelo, p.janela, muda = { vm.salvarPrefs(pAtual.copy(frequencia = it.frequencia)) }, atual = { modelo.copy(frequencia = pAtual.frequencia) })
            Linha()
            Frase("Avisar na hora do compromisso?", 22.sp, negrito = true)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Opcao("SIM", p.avisarNaHora, { vm.salvarPrefs(pAtual.copy(avisarNaHora = true)) }, Modifier.weight(1f))
                Opcao("NÃO", !p.avisarNaHora, { vm.salvarPrefs(pAtual.copy(avisarNaHora = false)) }, Modifier.weight(1f))
            }
            BlocoAvisosAntes(p.avisosAntes) { vm.salvarPrefs(pAtual.copy(avisosAntes = it)) }
            Linha()
            Frase("Como avisar:", 22.sp, negrito = true)
            listOf(EstiloAviso.TOCAR_E_VIBRAR to "Tocar e vibrar", EstiloAviso.SO_VIBRAR to "Só vibrar", EstiloAviso.SO_TOCAR to "Só tocar")
                .forEach { (e, t) -> Opcao(t, p.estilo == e, { vm.salvarPrefs(pAtual.copy(estilo = e)) }) }
        }

        Bloco(null, "Tamanho da letra") {
            listOf("Normal", "Grande", "Muito grande").forEachIndexed { i, t ->
                Opcao(t, p.letra == i, { vm.salvarPrefs(pAtual.copy(letra = i)) })
            }
        }

        Bloco(null, "Som do alarme") {
            val sons = listOf("Alarme do celular", "Sino", "Bipe forte", "Toque do celular")
            sons.forEachIndexed { i, t -> Opcao(t, p.som == i, { vm.salvarPrefs(pAtual.copy(som = i)) }) }
            MaisMenos(
                "Volume do alarme", "${p.volume} de 10",
                { vm.salvarPrefs(pAtual.copy(volume = (pAtual.volume - 1).coerceIn(1, 10))) },
                { vm.salvarPrefs(pAtual.copy(volume = (pAtual.volume + 1).coerceIn(1, 10))) },
            )
            Botao("🔊 TESTAR SOM", {
                runCatching { tocando?.release() }
                tocando = tocarAmostra(ctx, p.som, p.volume)
            }, cor = Cores.verde)
            if (tocando != null) BotaoContorno("PARAR O SOM", { runCatching { tocando?.release() }; tocando = null })
        }

        Bloco(null, "Voz") {
            Frase("Falar os avisos em voz alta?", 22.sp, negrito = true)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Opcao("SIM", p.falar, { vm.salvarPrefs(pAtual.copy(falar = true)) }, Modifier.weight(1f))
                Opcao("NÃO", !p.falar, { vm.salvarPrefs(pAtual.copy(falar = false)) }, Modifier.weight(1f))
            }
            Frase("Bom dia com os compromissos do dia? (no começo do horário de avisos)", 22.sp, negrito = true)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Opcao("SIM", p.bomDia, { vm.salvarPrefs(pAtual.copy(bomDia = true)) }, Modifier.weight(1f))
                Opcao("NÃO", !p.bomDia, { vm.salvarPrefs(pAtual.copy(bomDia = false)) }, Modifier.weight(1f))
            }
        }

        Bloco(null, "Enviar e guardar a agenda") {
            Botao("📲 ENVIAR MINHA AGENDA PELO WHATSAPP", {
                val texto = Mensagens.agendaDaSemana(lista, LocalDate.now())
                val envio = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, texto)
                try {
                    ctx.startActivity(Intent(envio).setPackage("com.whatsapp"))
                } catch (e: ActivityNotFoundException) {
                    Permissoes.abrir(ctx, Intent.createChooser(envio, "Enviar a agenda"))
                }
            }, cor = Cores.verde)
            Botao("💾 SALVAR CÓPIA DA AGENDA", {
                escopo.launch {
                    val arquivo = withContext(Dispatchers.IO) {
                        val pasta = File(ctx.cacheDir, "copias").apply { mkdirs() }
                        File(pasta, "agenda-lembra-ai-${LocalDate.now()}.json").apply { writeText(Agenda.exportar(ctx)) }
                    }
                    val uri = FileProvider.getUriForFile(ctx, ctx.packageName + ".arquivos", arquivo)
                    val envio = Intent(Intent.ACTION_SEND).setType("application/json")
                        .putExtra(Intent.EXTRA_STREAM, uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    Permissoes.abrir(ctx, Intent.createChooser(envio, "Guardar a cópia da agenda"))
                }
            })
            BotaoContorno("📂 RESTAURAR CÓPIA", { abrirCopia.launch(arrayOf("*/*")) })
        }

        Bloco(null, "Limpar") {
            Botao("🗑 APAGAR COMPROMISSOS ANTIGOS", { apagarAntigos = 1 }, cor = Cores.vermelho)
        }

        Bloco(null, "Permissões e bateria") {
            AvisosDePermissao()
            Frase(Permissoes.dicaFabricante(), 20.sp)
            Botao("ABRIR AJUSTES DE BATERIA DO CELULAR", { Permissoes.abrirInicioAutomatico(ctx) })
            BotaoContorno("ABRIR AS CONFIGURAÇÕES DO APP", { Permissoes.abrirConfigApp(ctx) })
        }
        Spacer(Modifier.height(24.dp))
    }

    when (apagarAntigos) {
        1 -> Pergunta(
            "Tem certeza?", "Vou apagar os compromissos que já passaram e não repetem mais.",
            "SIM, APAGAR", "NÃO", onSim = { apagarAntigos = 2 }, onNao = { apagarAntigos = 0 }, corSim = Cores.vermelho,
        )
        2 -> Pergunta(
            "Última confirmação", "Apagar mesmo os compromissos antigos? Isso não tem volta.",
            "SIM, APAGAR", "NÃO", onSim = {
                apagarAntigos = 0
                escopo.launch {
                    val n = Agenda.apagarAntigos(ctx)
                    vm.avisar(if (n == 0) "Não havia compromissos antigos." else if (n == 1) "Pronto! Apaguei 1 compromisso antigo." else "Pronto! Apaguei $n compromissos antigos.")
                }
            }, onNao = { apagarAntigos = 0 }, corSim = Cores.vermelho,
        )
    }

    restaurar?.let { l ->
        Pergunta(
            "Restaurar a cópia?",
            "Encontrei ${l.size} compromisso(s) na cópia. Isso troca a agenda atual pela cópia. Tem certeza?",
            "SIM, RESTAURAR", "NÃO",
            onSim = {
                restaurar = null
                escopo.launch { Agenda.restaurar(ctx, l); vm.avisar("Pronto! A agenda foi restaurada.") }
            },
            onNao = { restaurar = null },
        )
    }
    info?.let { Informacao(it) { info = null } }
}

private fun tocarAmostra(ctx: android.content.Context, som: Int, volume: Int): MediaPlayer? {
    val uri: Uri = when (som) {
        1 -> Uri.parse("android.resource://${ctx.packageName}/${R.raw.sino}")
        2 -> Uri.parse("android.resource://${ctx.packageName}/${R.raw.bipe}")
        3 -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        else -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
    } ?: Uri.parse("android.resource://${ctx.packageName}/${R.raw.sino}")
    return runCatching {
        MediaPlayer().apply {
            setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            setDataSource(ctx, uri)
            val v = volume.coerceIn(1, 10) / 10f
            setVolume(v, v)
            prepare()
            start()
            setOnCompletionListener { it.release() }
        }
    }.getOrNull()
}
