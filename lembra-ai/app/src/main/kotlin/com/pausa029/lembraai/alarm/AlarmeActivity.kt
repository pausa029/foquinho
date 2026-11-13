package com.pausa029.lembraai.alarm

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pausa029.lembraai.LembraApp
import com.pausa029.lembraai.data.Agenda
import com.pausa029.lembraai.data.Ajustes
import com.pausa029.lembraai.domain.Texto
import com.pausa029.lembraai.ui.Botao
import com.pausa029.lembraai.ui.Cores
import com.pausa029.lembraai.ui.Destaque
import com.pausa029.lembraai.ui.Frase
import com.pausa029.lembraai.ui.LembraTema
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Tela cheia do alarme: abre mesmo com o celular bloqueado. */
class AlarmeActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val escala = Ajustes.atual(this).escalaLetra
        setContent {
            LembraTema(escala) {
                val info by AlarmeService.atual.collectAsState()
                var viu by remember { mutableStateOf(false) }
                LaunchedEffect(info) {
                    if (info != null) viu = true
                    else { delay(if (viu) 300 else 2_000); if (AlarmeService.atual.value == null) finish() }
                }
                val i = info
                Column(
                    Modifier.fillMaxSize().background(Cores.fundo).safeDrawingPadding()
                        .verticalScroll(rememberScrollState()).padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    if (i == null) {
                        Frase("Abrindo o aviso…", 24.sp)
                        return@Column
                    }
                    Text(
                        i.topo, fontSize = 38.sp, fontWeight = FontWeight.Bold, lineHeight = 44.sp,
                        color = if (i.topo.startsWith("HORA")) Cores.vermelho else Cores.azul,
                    )
                    Text(i.titulo, fontSize = 34.sp, fontWeight = FontWeight.Bold, color = Cores.texto, lineHeight = 40.sp)
                    Text(Texto.hora(i.hora), fontSize = 64.sp, fontWeight = FontWeight.Bold, color = Cores.texto)
                    Frase(i.mensagem, 24.sp)
                    if (i.observacao.isNotBlank()) Destaque("Observação: ${i.observacao}")
                    if (i.endereco.isNotBlank()) Frase("Endereço: ${i.endereco}", 22.sp)

                    Botao("✓ JÁ FIZ / JÁ ESTOU INDO", {
                        LembraApp.escopo.launch {
                            if (i.compromissoId > 0) Agenda.marcarFeito(applicationContext, i.compromissoId, i.ocorrencia)
                        }
                        AlarmeService.pararAtual()
                    }, cor = Cores.verde, tamanho = 28.sp, altura = 96)
                    Botao("⏰ LEMBRAR EM 10 MINUTOS", {
                        LembraApp.escopo.launch { Disparo.adiar(applicationContext, i.compromissoId, i.ocorrencia, i.minutosAntes) }
                        AlarmeService.pararAtual()
                    }, cor = Cores.azul, tamanho = 26.sp, altura = 88)
                    if (i.telefone.isNotBlank()) Botao("📞 LIGAR", {
                        AlarmeService.silenciar()
                        runCatching { startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + i.telefone.filter { it.isDigit() || it == '+' }))) }
                    }, cor = Color(0xFF00695C))
                    if (i.endereco.isNotBlank()) Botao("🗺 COMO CHEGAR", {
                        AlarmeService.silenciar()
                        runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=" + Uri.encode(i.endereco)))) }
                    }, cor = Color(0xFF00695C))
                    Spacer(Modifier.height(12.dp))
                }
            }
        }
    }
}
