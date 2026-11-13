package com.pausa029.lembraai.ui

import android.Manifest
import android.content.Context
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect

private data class Passo(
    val titulo: String,
    val texto: String,
    val semEla: String,
    val concedido: (Context) -> Boolean,
    val pedir: (Context) -> Unit,
    val abrirConfig: (Context) -> Unit,
)

/** Primeira vez: explica e pede uma permissão de cada vez. */
@Composable
fun TelaBoasVindas(onFim: () -> Unit) {
    val ctx = LocalContext.current
    var etapa by remember { mutableIntStateOf(0) }
    var tentou by remember { mutableStateOf(false) }
    var verificar by remember { mutableIntStateOf(0) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { verificar++ }

    val pedirNotificacao = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        tentou = true; verificar++
    }

    val passos = buildList {
        if (Build.VERSION.SDK_INT >= 33) add(
            Passo(
                "Avisos", "Para o celular poder te avisar.",
                "Sem esta permissão, o app não consegue mostrar nenhum lembrete.",
                Permissoes::notificacoes, { pedirNotificacao.launch(Manifest.permission.POST_NOTIFICATIONS) }, Permissoes::abrirNotificacoes,
            ),
        )
        if (Build.VERSION.SDK_INT >= 31) add(
            Passo(
                "Alarmes", "Para avisar na hora certinha.",
                "Sem esta permissão, os avisos podem chegar atrasados.",
                Permissoes::alarmes, Permissoes::abrirAlarmes, Permissoes::abrirAlarmes,
            ),
        )
        if (Build.VERSION.SDK_INT >= 34) add(
            Passo(
                "Tela cheia", "Para o aviso aparecer mesmo com o celular bloqueado.",
                "Sem esta permissão, o alarme só aparece como uma notificação pequena.",
                Permissoes::telaCheia, Permissoes::abrirTelaCheia, Permissoes::abrirTelaCheia,
            ),
        )
        add(
            Passo(
                "Bateria", "Para o celular não desligar os avisos.",
                "Sem isso, alguns celulares desligam o app para economizar bateria e os avisos não tocam.",
                Permissoes::bateria, Permissoes::abrirBateria, Permissoes::abrirConfigApp,
            ),
        )
    }

    // pula sozinho as permissões que já estão dadas
    LaunchedEffect(etapa, verificar) {
        val i = etapa - 1
        if (i in passos.indices && passos[i].concedido(ctx)) { etapa++; tentou = false }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        when {
            etapa == 0 -> {
                Text("🔔", fontSize = 64.sp)
                Text("Olá!", fontSize = 40.sp, fontWeight = FontWeight.Bold, color = Cores.azul)
                Frase("Este aplicativo vai te lembrar dos seus compromissos.", 28.sp, negrito = true)
                Frase("Ele avisa várias vezes, tocando e vibrando, até chegar a hora.", 22.sp)
                Frase("Antes de começar, preciso de algumas permissões. Vou pedir uma de cada vez.", 22.sp)
                Botao("COMEÇAR", { etapa = 1 }, cor = Cores.verde, tamanho = 26.sp, altura = 72)
            }
            etapa - 1 in passos.indices -> {
                val ps = passos[etapa - 1]
                val ok = remember(verificar, etapa) { ps.concedido(ctx) }
                Text("Passo $etapa de ${passos.size + 1}", fontSize = 20.sp, color = Cores.suave)
                Text(ps.titulo, fontSize = 34.sp, fontWeight = FontWeight.Bold, color = Cores.azul)
                Frase(ps.texto, 28.sp, negrito = true)
                if (ok) {
                    Mensagem("✓ Pronto! Permissão dada.")
                    Botao("CONTINUAR", { etapa++; tentou = false }, cor = Cores.verde)
                } else {
                    Botao("PERMITIR", { tentou = true; ps.pedir(ctx) }, cor = Cores.verde, tamanho = 26.sp, altura = 72)
                    if (tentou) {
                        AvisoAmarelo(ps.semEla, "ABRIR CONFIGURAÇÕES") { ps.abrirConfig(ctx) }
                        BotaoContorno("CONTINUAR MESMO ASSIM", { etapa++; tentou = false })
                    }
                }
            }
            else -> {
                Text("Passo ${passos.size + 1} de ${passos.size + 1}", fontSize = 20.sp, color = Cores.suave)
                Text("Último cuidado", fontSize = 34.sp, fontWeight = FontWeight.Bold, color = Cores.azul)
                Frase("Alguns celulares (Xiaomi, Samsung, Motorola) desligam os apps que ficam fechados. Aí os avisos não tocam.", 22.sp)
                Destaque(Permissoes.dicaFabricante())
                Botao("ABRIR AJUSTES DO CELULAR", { Permissoes.abrirInicioAutomatico(ctx) })
                Botao("PRONTO, COMEÇAR", onFim, cor = Cores.verde, tamanho = 26.sp, altura = 72)
            }
        }
    }
}
