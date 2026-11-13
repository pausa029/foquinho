package com.pausa029.lembraai.ui

import android.content.Intent
import android.graphics.Color as CorAndroid
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.lifecycleScope
import com.pausa029.lembraai.alarm.Agendador
import kotlinx.coroutines.launch
import java.time.LocalDate

class MainActivity : ComponentActivity() {
    private val vm: LembraViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(CorAndroid.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(CorAndroid.WHITE, CorAndroid.BLACK),
        )
        super.onCreate(savedInstanceState)
        runCatching { Agendador.agendarRenovacao(this) }
        lifecycleScope.launch { Agendador.reagendar(applicationContext) }
        tratar(intent)
        setContent {
            val p by vm.prefs.collectAsState()
            LembraTema(p.escalaLetra) { App(vm) }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        tratar(intent)
    }

    private fun tratar(i: Intent?) {
        val d = i?.getLongExtra(EXTRA_DIA, Long.MIN_VALUE) ?: return
        if (d != Long.MIN_VALUE) vm.mostrarDia(LocalDate.ofEpochDay(d))
    }

    companion object {
        const val EXTRA_DIA = "dia"
    }
}

@Composable
fun App(vm: LembraViewModel) {
    val p by vm.prefs.collectAsState()
    if (!p.boasVindasFeita) {
        Box(Modifier.fillMaxSize().background(Cores.fundo).statusBarsPadding().navigationBarsPadding()) {
            TelaBoasVindas { vm.salvarPrefs(p.copy(boasVindasFeita = true)) }
        }
        return
    }

    var pedirSair by remember { mutableStateOf<(() -> Unit)?>(null) }
    val irPara: (() -> Unit) -> Unit = { destino ->
        if (vm.tela == Tela.Agendar && vm.formulario?.titulo?.isNotBlank() == true) pedirSair = destino
        else {
            if (vm.tela == Tela.Agendar) vm.formulario = null
            destino()
        }
    }
    BackHandler(enabled = vm.tela != Tela.Compromissos) { irPara { vm.tela = Tela.Compromissos } }

    Column(Modifier.fillMaxSize().background(Cores.azul).statusBarsPadding()) {
        // topo
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("🔔 Lembra Aí", Modifier.weight(1f), fontSize = 26.sp, fontWeight = FontWeight.Bold, color = Color.White)
            Botao(
                "⚙ Ajustes", { irPara { vm.tela = Tela.Ajustes } },
                Modifier.wrapContentWidth(), cor = Color.White, corTexto = Cores.azul, tamanho = 18.sp, altura = 52,
            )
        }
        Box(Modifier.weight(1f).fillMaxWidth().background(Cores.fundo).imePadding()) {
            when (val t = vm.tela) {
                Tela.Compromissos -> TelaCompromissos(vm)
                Tela.Agendar -> TelaAgendar(vm)
                is Tela.Detalhe -> TelaDetalhe(vm, t.id, t.dia)
                Tela.Ajustes -> TelaAjustes(vm)
            }
        }
        // as duas abas
        Row(
            Modifier.fillMaxWidth().background(Color.White).navigationBarsPadding().padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            val naAgenda = vm.tela is Tela.Agendar
            Opcao("📅 MEUS COMPROMISSOS", !naAgenda, { irPara { vm.tela = Tela.Compromissos } }, Modifier.weight(1f))
            Opcao("+ AGENDAR", naAgenda, {
                if (vm.tela != Tela.Agendar) { if (vm.formulario == null) vm.novo() else vm.tela = Tela.Agendar }
            }, Modifier.weight(1f))
        }
    }

    pedirSair?.let { destino ->
        Pergunta(
            "Sair sem salvar?",
            "O compromisso que você estava marcando ainda não foi salvo.",
            "SIM, SAIR", "NÃO, CONTINUAR MARCANDO",
            onSim = { vm.formulario = null; pedirSair = null; destino() },
            onNao = { pedirSair = null },
            corSim = Cores.vermelho,
        )
    }
}
