package com.pausa029.lembraai.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import com.pausa029.lembraai.LembraApp
import com.pausa029.lembraai.data.Agenda
import com.pausa029.lembraai.data.Ajustes
import com.pausa029.lembraai.data.AvisoExtraEntity
import com.pausa029.lembraai.data.LembraDb
import com.pausa029.lembraai.data.TipoExtra
import com.pausa029.lembraai.domain.CalculoAvisos
import com.pausa029.lembraai.domain.Compromisso
import com.pausa029.lembraai.domain.Mensagens
import com.pausa029.lembraai.domain.TipoAviso
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit

private fun BroadcastReceiver.emSegundoPlano(bloco: suspend () -> Unit) {
    val pendente = goAsync()
    LembraApp.escopo.launch {
        try { bloco() } finally { pendente.finish() }
    }
}

/** O alarme agendado tocou: mostra tudo que venceu e agenda o próximo. */
class DisparoReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = emSegundoPlano { Disparo.processar(context) }
}

/** Reiniciou, mudou a hora ou o fuso, ou o app foi atualizado: recalcula tudo. */
class SistemaReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = emSegundoPlano {
        when (intent.action) {
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED ->
                Ajustes.marcarDisparo(context, System.currentTimeMillis())
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                runCatching { Agendador.agendarRenovacao(context) }
        }
        Agendador.reagendar(context)
    }
}

/** Botões das notificações: JÁ FIZ, OK ENTENDI, LEMBRAR EM 10 MINUTOS. */
class AcaoReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = emSegundoPlano {
        val id = intent.getLongExtra(EXTRA_ID, -1)
        val oc = LocalDate.ofEpochDay(intent.getLongExtra(EXTRA_OCORRENCIA, 0))
        val notif = intent.getIntExtra(EXTRA_NOTIFICACAO, -1)
        if (notif != -1) NotificationManagerCompat.from(context).cancel(notif)
        when (intent.action) {
            ACAO_FEITO -> {
                if (id > 0) Agenda.marcarFeito(context, id, oc)
                AlarmeService.pararSeFor(id, oc)
            }
            ACAO_ADIAR -> {
                Disparo.adiar(context, id, oc, intent.getIntExtra(EXTRA_MINUTOS, 0))
                AlarmeService.pararSeFor(id, oc)
            }
            ACAO_OK -> Unit
        }
    }

    companion object {
        const val ACAO_FEITO = "com.pausa029.lembraai.FEITO"
        const val ACAO_OK = "com.pausa029.lembraai.OK"
        const val ACAO_ADIAR = "com.pausa029.lembraai.ADIAR"
        const val EXTRA_ID = "id"
        const val EXTRA_OCORRENCIA = "ocorrencia"
        const val EXTRA_NOTIFICACAO = "notificacao"
        const val EXTRA_MINUTOS = "minutos"
    }
}

object Disparo {
    const val TENTATIVAS = 3
    private const val FOLGA = 30_000L

    suspend fun processar(ctx: Context) {
        val app = ctx.applicationContext
        val p = Ajustes.atual(app)
        val agora = System.currentTimeMillis()
        var ultimo = Ajustes.ultimoDisparo(app)
        // celular desligado por muito tempo ou relógio voltou: só olha os últimos 10 minutos
        if (ultimo > agora + 60_000 || ultimo < agora - 10 * 60_000) ultimo = agora - 10 * 60_000
        val ate = Agendador.data(agora + FOLGA)
        val comps = Agenda.todos(app)
        val mapa = comps.associateBy { it.id }
        val devidos = CalculoAvisos.proximos(comps, p.janela, p.bomDia, Agendador.data(ultimo), dias = 2).filter { it.quando <= ate }
        Ajustes.marcarDisparo(app, agora + FOLGA)

        for (grupo in CalculoAvisos.agrupar(devidos)) {
            val comuns = grupo.filter { !it.especial }
            if (comuns.isNotEmpty()) Notificacoes.lembrete(app, comuns, mapa, p)
            for (a in grupo.filter { it.especial }) {
                val c = mapa[a.compromissoId] ?: continue
                AlarmeService.tocar(app, info(c, a.ocorrencia, a.tipo.name, a.minutosAntes, 0))
            }
        }

        val dao = LembraDb.get(app).dao()
        for (e in dao.extras().filter { it.quandoMillis <= agora + FOLGA }) {
            dao.apagarExtra(e.id)
            if (e.tipo == TipoExtra.TESTE) { AlarmeService.tocar(app, infoTeste(p.falar)); continue }
            val c = mapa[e.compromissoId] ?: continue
            val oc = LocalDate.ofEpochDay(e.ocorrenciaEpoch)
            if (oc in c.feitos) continue
            AlarmeService.tocar(app, info(c, oc, e.tipo, e.minutosAntes, e.tentativa))
        }
        Agendador.reagendar(app)
    }

    suspend fun adiar(ctx: Context, id: Long, oc: LocalDate, minutosAntes: Int) {
        Agenda.avisoExtra(
            ctx,
            AvisoExtraEntity(
                compromissoId = id, ocorrenciaEpoch = oc.toEpochDay(),
                quandoMillis = System.currentTimeMillis() + 10 * 60_000L,
                tipo = if (id > 0) TipoExtra.ADIADO else TipoExtra.TESTE, tentativa = 0, minutosAntes = minutosAntes,
            ),
        )
    }

    suspend fun novaTentativa(ctx: Context, i: AlarmeService.Info) {
        Agenda.avisoExtra(
            ctx,
            AvisoExtraEntity(
                compromissoId = i.compromissoId, ocorrenciaEpoch = i.ocorrencia.toEpochDay(),
                quandoMillis = System.currentTimeMillis() + 10 * 60_000L,
                tipo = TipoExtra.NOVA_TENTATIVA, tentativa = i.tentativa + 1, minutosAntes = i.minutosAntes,
            ),
        )
    }

    suspend fun testar(ctx: Context) {
        Agenda.avisoExtra(
            ctx,
            AvisoExtraEntity(
                compromissoId = -1, ocorrenciaEpoch = LocalDate.now().toEpochDay(),
                quandoMillis = System.currentTimeMillis() + 10_000L, tipo = TipoExtra.TESTE, tentativa = TENTATIVAS, minutosAntes = 0,
            ),
        )
    }

    fun info(c: Compromisso, oc: LocalDate, tipo: String, minutosAntes: Int, tentativa: Int): AlarmeService.Info {
        val momento = oc.atTime(c.hora / 60, c.hora % 60)
        val faltam = ChronoUnit.MINUTES.between(LocalDateTime.now().withSecond(0).withNano(0), momento)
        val ehAntes = if (tipo == TipoAviso.ANTES.name) true else if (tipo == TipoAviso.NA_HORA.name) false else faltam > 0
        val min = if (tipo == TipoAviso.ANTES.name) minutosAntes else faltam.toInt()
        return AlarmeService.Info(
            compromissoId = c.id, ocorrencia = oc, tipo = tipo, minutosAntes = minutosAntes, tentativa = tentativa,
            topo = if (ehAntes) "ATENÇÃO!" else "HORA DO SEU COMPROMISSO",
            titulo = c.titulo, hora = c.hora,
            mensagem = if (ehAntes) Mensagens.antes(c.titulo, c.hora, min) else Mensagens.naHora(c.titulo, c.hora),
            observacao = c.observacao, endereco = c.endereco, telefone = c.telefone,
            estilo = c.estilo, falar = c.falar,
        )
    }

    fun infoTeste(falar: Boolean) = AlarmeService.Info(
        compromissoId = -1, ocorrencia = LocalDate.now(), tipo = TipoExtra.TESTE, minutosAntes = 0, tentativa = TENTATIVAS,
        topo = "AVISO DE TESTE", titulo = "Teste do Lembra Aí", hora = LocalDateTime.now().let { it.hour * 60 + it.minute },
        mensagem = "Este é um aviso de teste. Se você está vendo e ouvindo, está tudo funcionando.",
        observacao = "", endereco = "", telefone = "",
        estilo = com.pausa029.lembraai.domain.EstiloAviso.TOCAR_E_VIBRAR, falar = falar,
    )
}
