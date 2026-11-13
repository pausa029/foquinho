package com.pausa029.lembraai.ui

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pausa029.lembraai.domain.CalculoAvisos
import com.pausa029.lembraai.domain.Compromisso
import com.pausa029.lembraai.domain.EstiloAviso
import com.pausa029.lembraai.domain.Janela
import com.pausa029.lembraai.domain.Mensagens
import com.pausa029.lembraai.domain.ModoFrequencia
import com.pausa029.lembraai.domain.Texto
import com.pausa029.lembraai.domain.TipoRepeticao
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

private enum class Calend { DATA, INICIO_AVISOS, ATE }

@Composable
fun TelaAgendar(vm: LembraViewModel) {
    val c = vm.formulario ?: run { LaunchedEffect(Unit) { vm.novo() }; return }
    val p by vm.prefs.collectAsState()
    val ctx = LocalContext.current
    val hoje = LocalDate.now()
    val atual by rememberUpdatedState(c)
    val muda: (Compromisso) -> Unit = { vm.formulario = it }

    var calendario by remember { mutableStateOf<Calend?>(null) }
    var erro by remember { mutableStateOf<String?>(null) }
    var perguntaForaJanela by remember { mutableStateOf<Compromisso?>(null) }
    var confirmar by remember { mutableStateOf<Compromisso?>(null) }

    val ditar = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { r ->
        if (r.resultCode == Activity.RESULT_OK) {
            r.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()?.let {
                muda(atual.copy(titulo = Texto.cap(it.trim())))
            }
        }
    }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                if (c.id != 0L) "Mudar compromisso" else "Marcar compromisso",
                fontSize = 30.sp, fontWeight = FontWeight.Bold, color = Cores.texto,
            )
            Frase("Já vem tudo preenchido. Mude só o que quiser e toque em SALVAR.", 20.sp, Cores.suave)

            // 1 — O que é?
            Bloco("1", "O que é?") {
                OutlinedTextField(
                    value = c.titulo,
                    onValueChange = { muda(atual.copy(titulo = it)) },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("Nome do compromisso", fontSize = 18.sp) },
                    placeholder = { Text("Ex.: Consulta com o doutor João", fontSize = 20.sp) },
                    textStyle = TextStyle(fontSize = 24.sp, color = Cores.texto),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Done),
                    maxLines = 3,
                )
                val rapidos = listOf("Consulta", "Exame", "Banco", "Pagar conta", "Família", "Igreja", "Outro")
                Grade(rapidos.map { it to (c.titulo == it) }) { i ->
                    muda(atual.copy(titulo = if (rapidos[i] == "Outro") "" else rapidos[i]))
                }
                Botao("🎤 FALAR O NOME", {
                    val i = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                        .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR")
                        .putExtra(RecognizerIntent.EXTRA_PROMPT, "Fale o nome do compromisso")
                    try { ditar.launch(i) } catch (e: ActivityNotFoundException) {
                        erro = "Este celular não tem o recurso de ditar. Escreva o nome no campo acima."
                    }
                }, cor = Cores.verde)
            }

            // 2 — Que dia?
            Bloco("2", "Que dia?") {
                val dias = listOf("HOJE" to hoje, "AMANHÃ" to hoje.plusDays(1), "DEPOIS DE AMANHÃ" to hoje.plusDays(2))
                dias.forEach { (t, d) -> Opcao(t, c.data == d, { muda(atual.copy(data = d)) }) }
                Botao("📅 ESCOLHER NO CALENDÁRIO", { calendario = Calend.DATA })
                Destaque("Dia escolhido: ${Texto.dataCompleta(c.data)}")
            }

            // 3 — Que horas?
            Bloco("3", "Que horas?") {
                var outro by remember { mutableStateOf(false) }
                val horas = listOf(7, 8, 9, 10, 11, 13, 14, 15, 16, 17)
                Grade(horas.map { "${it}h" to (c.hora == it * 60) }, colunas = 3) { i ->
                    outro = false
                    muda(atual.copy(hora = horas[i] * 60))
                }
                Opcao("OUTRO HORÁRIO", outro, { outro = !outro })
                if (outro) SeletorHora("Horário", c.hora) { muda(atual.copy(hora = it)) }
                Destaque("Horário: ${Texto.hora(c.hora)}")
            }

            // 4 — A partir de quando avisar?
            Bloco("4", "A partir de quando avisar?") {
                var outro by remember { mutableStateOf(c.diasAntes !in listOf(0, 1, 2, 3, 7)) }
                val ops = listOf("Só no dia" to 0, "1 dia antes" to 1, "2 dias antes" to 2, "3 dias antes" to 3, "1 semana antes" to 7)
                Grade(ops.map { (t, n) -> t to (!outro && c.diasAntes == n) } + ("OUTRO" to outro)) { i ->
                    if (i < ops.size) { outro = false; muda(atual.copy(diasAntes = ops[i].second)) } else outro = true
                }
                if (outro) {
                    MaisMenos(
                        "Quantos dias antes", if (c.diasAntes == 1) "1 dia" else "${c.diasAntes} dias",
                        { muda(atual.copy(diasAntes = (atual.diasAntes - 1).coerceIn(0, 30))) },
                        { muda(atual.copy(diasAntes = (atual.diasAntes + 1).coerceIn(0, 30))) },
                    )
                    BotaoContorno("ESCOLHER NO CALENDÁRIO O DIA DE COMEÇAR", { calendario = Calend.INICIO_AVISOS })
                }
                Destaque(Mensagens.comecoDosAvisos(c))
            }

            // 5 — Em que horário do dia pode avisar?
            Bloco("5", "Em que horário do dia pode avisar?") {
                var mudar by remember { mutableStateOf(c.janela != null) }
                val j = c.janela ?: p.janela
                Destaque("Das ${Texto.hora(j.inicio)} às ${Texto.hora(j.fim)}" + if (c.janela != null) " (só para este compromisso)" else "")
                if (!mudar) {
                    BotaoContorno("MUDAR", { mudar = true })
                } else {
                    SeletorHora("Começar a avisar às", j.inicio) { muda(atual.copy(janela = Janela(it, j.fim))) }
                    SeletorHora("Parar de avisar às", j.fim) { muda(atual.copy(janela = Janela(j.inicio, it))) }
                    if (!j.valida) Frase("O começo precisa ser antes do fim.", 20.sp, Cores.vermelho, negrito = true)
                    BotaoContorno("VOLTAR AO PADRÃO (${Texto.hora(p.janela.inicio)} às ${Texto.hora(p.janela.fim)})", {
                        mudar = false; muda(atual.copy(janela = null))
                    })
                }
            }

            // 6 — Quantas vezes avisar por dia?
            Bloco("6", "Quantas vezes avisar por dia?") {
                BlocoFrequencia(c, c.janela ?: p.janela, muda = { muda(it) }, atual = { atual })
                Frase("Prévia dos avisos:", 20.sp, negrito = true)
                Destaque(Mensagens.previa(c.copy(titulo = c.titulo.ifBlank { "compromisso" }), p.janela))
            }

            // 7 — Avisos especiais antes do compromisso
            Bloco("7", "Avisos especiais antes do compromisso") {
                Frase("Estes avisos aparecem em tela cheia, como alarme.", 20.sp, Cores.suave)
                Frase("Avisar na hora do compromisso?", 22.sp, negrito = true)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Opcao("SIM", c.avisarNaHora, { muda(atual.copy(avisarNaHora = true)) }, Modifier.weight(1f))
                    Opcao("NÃO", !c.avisarNaHora, { muda(atual.copy(avisarNaHora = false)) }, Modifier.weight(1f))
                }
                BlocoAvisosAntes(c.avisosAntes) { muda(atual.copy(avisosAntes = it)) }
            }

            // 8 — Como avisar?
            Bloco("8", "Como avisar?") {
                val estilos = listOf(EstiloAviso.TOCAR_E_VIBRAR to "Tocar e vibrar", EstiloAviso.SO_VIBRAR to "Só vibrar", EstiloAviso.SO_TOCAR to "Só tocar")
                estilos.forEach { (e, t) -> Opcao(t, c.estilo == e, { muda(atual.copy(estilo = e)) }) }
                Frase("Falar o aviso em voz alta?", 22.sp, negrito = true)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Opcao("SIM", c.falar, { muda(atual.copy(falar = true)) }, Modifier.weight(1f))
                    Opcao("NÃO", !c.falar, { muda(atual.copy(falar = false)) }, Modifier.weight(1f))
                }
            }

            // 9 — Repetir?
            Bloco("9", "Repetir?") {
                BlocoRepetir(c, { muda(it) }, { atual }, onEscolherFim = { calendario = Calend.ATE })
            }

            // 10 — Extras
            Bloco("10", "Extras (se quiser)") {
                var mais by remember { mutableStateOf(c.observacao.isNotBlank() || c.telefone.isNotBlank() || c.endereco.isNotBlank()) }
                BotaoContorno(if (mais) "MENOS OPÇÕES ▲" else "MAIS OPÇÕES ▼", { mais = !mais })
                if (mais) {
                    Campo("Observação (ex.: Levar os exames)", c.observacao) { muda(atual.copy(observacao = it)) }
                    Campo("Telefone", c.telefone, KeyboardType.Phone) { muda(atual.copy(telefone = it)) }
                    Campo("Endereço", c.endereco) { muda(atual.copy(endereco = it)) }
                }
            }
            Spacer(Modifier.height(8.dp))
        }

        // SALVAR sempre visível
        Column(Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 14.dp, vertical = 8.dp)) {
            Botao("💾 SALVAR", {
                val n = c.copy(titulo = c.titulo.trim())
                val j = n.janela ?: p.janela
                erro = when {
                    n.titulo.isBlank() -> "Escreva ou fale o nome do compromisso (bloco 1)."
                    !j.valida -> "O horário de avisos está errado: o começo precisa ser antes do fim (bloco 5)."
                    !n.repeticao.repete && n.data.atTime(n.hora / 60, n.hora % 60) <= LocalDateTime.now() ->
                        "Esse dia e horário já passaram. Escolha outro dia (bloco 2) ou outro horário (bloco 3)."
                    n.repeticao.ate != null && n.repeticao.ate!! < n.data -> "A data final da repetição é antes do compromisso (bloco 9)."
                    else -> null
                }
                if (erro == null) {
                    if (CalculoAvisos.temEspecialForaDaJanela(n, p.janela)) perguntaForaJanela = n
                    else {
                        val pronto = n.copy(avisarForaDaJanela = true)
                        confirmar = pronto
                        Voz.falar(ctx, Mensagens.resumo(pronto, p.janela))
                    }
                }
            }, cor = Cores.verde, tamanho = 28.sp, altura = 76)
        }
    }

    when (calendario) {
        Calend.DATA -> EscolherDia("Escolha o dia do compromisso", c.data, { muda(atual.copy(data = it)); calendario = null }, { calendario = null })
        Calend.INICIO_AVISOS -> EscolherDia("Em que dia começo a avisar?", c.data.minusDays(c.diasAntes.toLong()), { d ->
            val n = ChronoUnit.DAYS.between(d, atual.data)
            if (n < 0) erro = "O dia de começar a avisar precisa ser antes do compromisso (ou no mesmo dia)."
            else if (n > 30) erro = "Posso começar a avisar no máximo 30 dias antes."
            else muda(atual.copy(diasAntes = n.toInt()))
            calendario = null
        }, { calendario = null })
        Calend.ATE -> EscolherDia("Repetir até que dia?", c.repeticao.ate ?: c.data.plusMonths(1), {
            muda(atual.copy(repeticao = atual.repeticao.copy(ate = it))); calendario = null
        }, { calendario = null })
        null -> Unit
    }

    erro?.let { Informacao(it) { erro = null } }

    perguntaForaJanela?.let { n ->
        Pergunta(
            "Fora do horário de avisos",
            "Este horário é fora do horário de avisos. Quer que eu avise mesmo assim na hora do compromisso?",
            "SIM, AVISAR MESMO ASSIM", "NÃO",
            onFechar = { perguntaForaJanela = null },
            onSim = { perguntaForaJanela = null; val x = n.copy(avisarForaDaJanela = true); confirmar = x; Voz.falar(ctx, Mensagens.resumo(x, p.janela)) },
            onNao = { perguntaForaJanela = null; val x = n.copy(avisarForaDaJanela = false); confirmar = x; Voz.falar(ctx, Mensagens.resumo(x, p.janela)) },
        )
    }

    confirmar?.let { n ->
        Pergunta(
            "Confira, por favor:",
            Mensagens.resumo(n, p.janela),
            "✓ CONFIRMAR", "MUDAR ALGUMA COISA",
            onSim = { confirmar = null; Voz.parar(); vm.salvar(n) },
            onNao = { confirmar = null; Voz.parar() },
        )
    }
}

@Composable
private fun Campo(rotulo: String, valor: String, tipo: KeyboardType = KeyboardType.Text, onMuda: (String) -> Unit) {
    OutlinedTextField(
        value = valor, onValueChange = onMuda, modifier = Modifier.fillMaxWidth(),
        label = { Text(rotulo, fontSize = 18.sp) },
        textStyle = TextStyle(fontSize = 22.sp, color = Cores.texto),
        keyboardOptions = KeyboardOptions(
            keyboardType = tipo,
            capitalization = if (tipo == KeyboardType.Text) KeyboardCapitalization.Sentences else KeyboardCapitalization.None,
        ),
        maxLines = 4,
    )
}

/** Bloco 6: os três modos de frequência. Também usado nos Ajustes (padrão para novos compromissos). */
@Composable
fun BlocoFrequencia(c: Compromisso, janela: Janela, muda: (Compromisso) -> Unit, atual: () -> Compromisso) {
    val f = c.frequencia
    val modos = listOf(
        ModoFrequencia.INTERVALO to "De quanto em quanto tempo",
        ModoFrequencia.VEZES to "Quantas vezes no dia",
        ModoFrequencia.HORARIOS to "Horários que eu escolho",
    )
    modos.forEach { (m, t) -> Opcao(t, f.modo == m, { muda(atual().let { a -> a.copy(frequencia = a.frequencia.copy(modo = m)) }) }) }
    Linha()
    when (f.modo) {
        ModoFrequencia.INTERVALO -> {
            val ops = listOf(30, 60, 120, 180, 240)
            var outro by remember { mutableStateOf(f.intervaloMin !in ops) }
            val rotulo = { n: Int -> if (n == 30) "De 30 em 30 min" else Texto.cap(Texto.intervalo(n)) }
            Grade(ops.map { rotulo(it) to (!outro && f.intervaloMin == it) } + ("OUTRO" to outro)) { i ->
                if (i < ops.size) { outro = false; muda(atual().let { a -> a.copy(frequencia = a.frequencia.copy(intervaloMin = ops[i])) }) } else outro = true
            }
            if (outro) {
                val h = f.intervaloMin / 60
                val m = f.intervaloMin % 60
                val novo = { min: Int -> muda(atual().let { a -> a.copy(frequencia = a.frequencia.copy(intervaloMin = min.coerceIn(15, 12 * 60))) }) }
                MaisMenos("Horas", "$h", { novo((h - 1) * 60 + m) }, { novo((h + 1) * 60 + m) })
                MaisMenos("Minutos", "$m", { novo(h * 60 + (m - 5 + 60) % 60) }, { novo(h * 60 + (m + 5) % 60) })
                Destaque("Avisar ${Texto.intervalo(maxOf(15, f.intervaloMin))} (mínimo 15 minutos)")
            }
        }
        ModoFrequencia.VEZES -> {
            val ops = listOf(1, 2, 3, 5)
            var outro by remember { mutableStateOf(f.vezes !in ops) }
            Grade(ops.map { Texto.vezes(it) to (!outro && f.vezes == it) } + ("OUTRO" to outro)) { i ->
                if (i < ops.size) { outro = false; muda(atual().let { a -> a.copy(frequencia = a.frequencia.copy(vezes = ops[i])) }) } else outro = true
            }
            if (outro) {
                MaisMenos(
                    "Quantas vezes por dia", Texto.vezes(f.vezes),
                    { muda(atual().let { a -> a.copy(frequencia = a.frequencia.copy(vezes = (a.frequencia.vezes - 1).coerceIn(1, 20))) }) },
                    { muda(atual().let { a -> a.copy(frequencia = a.frequencia.copy(vezes = (a.frequencia.vezes + 1).coerceIn(1, 20))) }) },
                )
            }
            Frase("Os avisos ficam espalhados igualmente no horário de avisos.", 18.sp, Cores.suave)
        }
        ModoFrequencia.HORARIOS -> {
            f.horarios.sorted().forEach { h ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(Texto.hora(h), fontSize = 30.sp, fontWeight = FontWeight.Bold, color = Cores.texto)
                        if (!janela.contem(h)) Frase("Fora do horário de avisos: não vai tocar", 16.sp, Cores.vermelho, negrito = true)
                    }
                    Botao("TIRAR", { muda(atual().let { a -> a.copy(frequencia = a.frequencia.copy(horarios = a.frequencia.horarios - h)) }) },
                        Modifier.width(130.dp), cor = Cores.vermelho, tamanho = 20.sp)
                }
            }
            if (f.horarios.isEmpty()) Frase("Nenhum horário ainda.", 20.sp, Cores.suave)
            var novo by remember { mutableStateOf<Int?>(null) }
            val n = novo
            if (n == null) {
                Botao("+ ADICIONAR HORÁRIO", { novo = 12 * 60 })
            } else {
                SeletorHora("Novo horário", n) { novo = it }
                Botao("✓ ADICIONAR ESTE HORÁRIO", {
                    muda(atual().let { a -> a.copy(frequencia = a.frequencia.copy(horarios = (a.frequencia.horarios + n).distinct().sorted())) })
                    novo = null
                }, cor = Cores.verde)
                BotaoContorno("CANCELAR", { novo = null })
            }
        }
    }
}

/** Bloco 7: lista de "avisar antes", com TIRAR e botões para acrescentar. */
@Composable
fun BlocoAvisosAntes(lista: List<Int>, onMuda: (List<Int>) -> Unit) {
    Frase("Avisar antes:", 22.sp, negrito = true)
    val ordenada = lista.distinct().sortedDescending()
    if (ordenada.isEmpty()) Frase("Nenhum aviso antes.", 20.sp, Cores.suave)
    ordenada.forEach { m ->
        Row(verticalAlignment = Alignment.CenterVertically) {
            Frase(Texto.cap(Texto.antes(m)), 24.sp, negrito = true, modifier = Modifier.weight(1f))
            Botao("TIRAR", { onMuda(lista - m) }, Modifier.width(130.dp), cor = Cores.vermelho, tamanho = 20.sp)
        }
    }
    val prontos = listOf(15, 30, 60, 120).filter { it !in lista }
    if (prontos.isNotEmpty()) Grade(prontos.map { "+ " + Texto.antes(it).replace(" minutos", " min") to false }) { i ->
        onMuda((lista + prontos[i]).distinct())
    }
    var h by remember { mutableIntStateOf(0) }
    var m by remember { mutableIntStateOf(45) }
    var outro by remember { mutableStateOf(false) }
    if (!outro) {
        BotaoContorno("ESCOLHER OUTRO TEMPO", { outro = true })
    } else {
        MaisMenos("Horas antes", "$h", { h = (h - 1).coerceAtLeast(0) }, { h = (h + 1).coerceAtMost(72) })
        MaisMenos("Minutos antes", "$m", { m = (m - 5 + 60) % 60 }, { m = (m + 5) % 60 })
        val total = h * 60 + m
        Botao(if (total > 0) "✓ ADICIONAR: ${Texto.antes(total)}" else "Escolha um tempo", {
            if (total > 0) { onMuda((lista + total).distinct()); outro = false }
        }, cor = Cores.verde, enabled = total > 0)
        BotaoContorno("CANCELAR", { outro = false })
    }
}

@Composable
private fun BlocoRepetir(c: Compromisso, muda: (Compromisso) -> Unit, atual: () -> Compromisso, onEscolherFim: () -> Unit) {
    val r = c.repeticao
    val simples = listOf(
        TipoRepeticao.NAO_REPETE to "Não repete", TipoRepeticao.TODO_DIA to "Todo dia", TipoRepeticao.TODA_SEMANA to "Toda semana",
        TipoRepeticao.TODO_MES to "Todo mês", TipoRepeticao.TODO_ANO to "Todo ano",
    )
    val ehOutro = r.tipo == TipoRepeticao.DIAS_DA_SEMANA || r.tipo == TipoRepeticao.A_CADA_X_DIAS
    val setTipo = { t: TipoRepeticao -> muda(atual().let { a -> a.copy(repeticao = a.repeticao.copy(tipo = t)) }) }
    Grade(simples.map { (t, s) -> s to (r.tipo == t) } + ("OUTRO" to ehOutro)) { i ->
        if (i < simples.size) setTipo(simples[i].first)
        else setTipo(TipoRepeticao.DIAS_DA_SEMANA)
    }
    if (ehOutro) {
        Linha()
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Opcao("Dias da semana", r.tipo == TipoRepeticao.DIAS_DA_SEMANA, { setTipo(TipoRepeticao.DIAS_DA_SEMANA) }, Modifier.weight(1f))
            Opcao("A cada X dias", r.tipo == TipoRepeticao.A_CADA_X_DIAS, { setTipo(TipoRepeticao.A_CADA_X_DIAS) }, Modifier.weight(1f))
        }
        if (r.tipo == TipoRepeticao.DIAS_DA_SEMANA) {
            val dias = listOf(
                DayOfWeek.MONDAY to "Seg", DayOfWeek.TUESDAY to "Ter", DayOfWeek.WEDNESDAY to "Qua", DayOfWeek.THURSDAY to "Qui",
                DayOfWeek.FRIDAY to "Sex", DayOfWeek.SATURDAY to "Sáb", DayOfWeek.SUNDAY to "Dom",
            )
            val marcados = r.diasSemana.ifEmpty { setOf(c.data.dayOfWeek) }
            Grade(dias.map { (d, t) -> t to (d in marcados) }, colunas = 4) { i ->
                val d = dias[i].first
                val novo = if (d in marcados) marcados - d else marcados + d
                muda(atual().let { a -> a.copy(repeticao = a.repeticao.copy(diasSemana = novo.ifEmpty { setOf(d) })) })
            }
        } else {
            MaisMenos(
                "Repetir a cada", "${r.cadaDias} dias",
                { muda(atual().let { a -> a.copy(repeticao = a.repeticao.copy(cadaDias = (a.repeticao.cadaDias - 1).coerceIn(2, 90))) }) },
                { muda(atual().let { a -> a.copy(repeticao = a.repeticao.copy(cadaDias = (a.repeticao.cadaDias + 1).coerceIn(2, 90))) }) },
            )
        }
    }
    if (r.repete) {
        Linha()
        Frase("Até quando?", 22.sp, negrito = true)
        Opcao("Para sempre", r.ate == null, { muda(atual().let { a -> a.copy(repeticao = a.repeticao.copy(ate = null)) }) })
        Opcao(if (r.ate != null) "Até ${Texto.dataSemSemana(r.ate!!)}" else "ESCOLHER DATA FINAL", r.ate != null, onEscolherFim)
        Destaque(Mensagens.repeticao(c))
    }
}
