package com.pausa029.lembraai.alarm

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.pausa029.lembraai.R
import com.pausa029.lembraai.data.Preferencias
import com.pausa029.lembraai.domain.Aviso
import com.pausa029.lembraai.domain.Compromisso
import com.pausa029.lembraai.domain.EstiloAviso
import com.pausa029.lembraai.domain.Mensagens
import com.pausa029.lembraai.domain.TipoAviso
import com.pausa029.lembraai.ui.MainActivity

object Notificacoes {
    const val CANAL_ALARME = "alarme_compromisso"
    const val CANAL_LEMBRETE = "lembretes"
    const val CANAL_LEMBRETE_VIBRAR = "lembretes_so_vibrar"
    const val CANAL_LEMBRETE_TOCAR = "lembretes_so_tocar"
    const val CANAL_APP = "avisos_do_app"
    const val ID_ALARME = 7000
    const val ID_VOZ = 7001

    private val VIBRACAO = longArrayOf(0, 700, 400, 700, 400, 700)

    fun criarCanais(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        val somNotif = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val attrsNotif = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()

        val alarme = NotificationChannel(CANAL_ALARME, "Alarme do compromisso", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Tela cheia na hora do compromisso e nos avisos antes. O som é tocado pelo próprio app, como alarme."
            setSound(null, null)
            enableVibration(false)
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val lembrete = NotificationChannel(CANAL_LEMBRETE, "Lembretes", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Lembretes repetidos, com som e vibração."
            setSound(somNotif, attrsNotif)
            enableVibration(true)
            vibrationPattern = VIBRACAO
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val soVibrar = NotificationChannel(CANAL_LEMBRETE_VIBRAR, "Lembretes (só vibrar)", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Lembretes que só vibram."
            setSound(null, null)
            enableVibration(true)
            vibrationPattern = VIBRACAO
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val soTocar = NotificationChannel(CANAL_LEMBRETE_TOCAR, "Lembretes (só tocar)", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Lembretes que só tocam, sem vibrar."
            setSound(somNotif, attrsNotif)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val app = NotificationChannel(CANAL_APP, "Avisos do aplicativo", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Avisos como \"você não respondeu\" e leitura em voz alta."
        }
        nm.createNotificationChannels(listOf(alarme, lembrete, soVibrar, soTocar, app))
    }

    private fun abrir(ctx: Context, diaEpoch: Long?): PendingIntent {
        val i = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        if (diaEpoch != null) i.putExtra(MainActivity.EXTRA_DIA, diaEpoch)
        return PendingIntent.getActivity(ctx, (diaEpoch ?: 0L).toInt(), i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun acao(ctx: Context, acao: String, id: Long, ocEpoch: Long, notif: Int, minutos: Int = 0): PendingIntent {
        val i = Intent(ctx, AcaoReceiver::class.java).setAction(acao)
            .putExtra(AcaoReceiver.EXTRA_ID, id)
            .putExtra(AcaoReceiver.EXTRA_OCORRENCIA, ocEpoch)
            .putExtra(AcaoReceiver.EXTRA_NOTIFICACAO, notif)
            .putExtra(AcaoReceiver.EXTRA_MINUTOS, minutos)
        val codigo = (acao.hashCode() * 31 + notif) xor id.toInt()
        return PendingIntent.getBroadcast(ctx, codigo, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    @SuppressLint("MissingPermission")
    private fun mostrar(ctx: Context, id: Int, n: Notification) {
        runCatching { NotificationManagerCompat.from(ctx).notify(id, n) }
    }

    /** Lembrete repetido (e o "bom dia"). Vários compromissos no mesmo horário viram uma notificação só. */
    fun lembrete(ctx: Context, grupo: List<Aviso>, compromissos: Map<Long, Compromisso>, p: Preferencias) {
        val texto = Mensagens.textoDoGrupo(grupo, compromissos)
        if (texto.isBlank()) return
        val envolvidos = grupo.mapNotNull { compromissos[it.compromissoId] }
        val bomDia = grupo.any { it.tipo == TipoAviso.BOM_DIA }
        val estilos = envolvidos.map { it.estilo }.ifEmpty { listOf(p.estilo) }
        val canal = when {
            estilos.contains(EstiloAviso.TOCAR_E_VIBRAR) || (estilos.contains(EstiloAviso.SO_TOCAR) && estilos.contains(EstiloAviso.SO_VIBRAR)) -> CANAL_LEMBRETE
            estilos.contains(EstiloAviso.SO_TOCAR) -> CANAL_LEMBRETE_TOCAR
            else -> CANAL_LEMBRETE_VIBRAR
        }
        val quando = grupo.first().quando
        val idNotif = (Agendador.millis(quando) / 60_000L % 1_000_000L).toInt() + 10_000
        val dia = (grupo.firstOrNull { it.compromissoId > 0 }?.ocorrencia ?: quando.toLocalDate()).toEpochDay()
        val b = NotificationCompat.Builder(ctx, canal)
            .setSmallIcon(R.drawable.ic_notificacao)
            .setContentTitle(if (bomDia) "Bom dia!" else "Lembrete")
            .setContentText(texto)
            .setStyle(NotificationCompat.BigTextStyle().bigText(texto))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(abrir(ctx, dia))
            .setAutoCancel(true)
        val repetidos = grupo.filter { it.tipo == TipoAviso.REPETIDO }
        if (!bomDia && repetidos.size == 1) {
            val a = repetidos[0]
            b.addAction(0, "JÁ FIZ", acao(ctx, AcaoReceiver.ACAO_FEITO, a.compromissoId, a.ocorrencia.toEpochDay(), idNotif))
        }
        b.addAction(0, "OK, ENTENDI", acao(ctx, AcaoReceiver.ACAO_OK, 0, 0, idNotif))
        mostrar(ctx, idNotif, b.build())

        val falar = if (bomDia && envolvidos.isEmpty()) p.falar else envolvidos.any { it.falar } || (bomDia && p.falar)
        if (falar) AlarmeService.falar(ctx, texto)
    }

    /** Notificação do alarme (tela cheia). Usada pelo serviço que toca o som. */
    fun alarme(ctx: Context, i: AlarmeService.Info): Notification {
        val tela = PendingIntent.getActivity(
            ctx, 2,
            Intent(ctx, AlarmeActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val oc = i.ocorrencia.toEpochDay()
        return NotificationCompat.Builder(ctx, CANAL_ALARME)
            .setSmallIcon(R.drawable.ic_notificacao)
            .setContentTitle(i.topo)
            .setContentText(i.mensagem)
            .setStyle(NotificationCompat.BigTextStyle().bigText(i.mensagem))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setFullScreenIntent(tela, true)
            .setContentIntent(tela)
            .addAction(0, "✓ JÁ FIZ", acao(ctx, AcaoReceiver.ACAO_FEITO, i.compromissoId, oc, ID_ALARME))
            .addAction(0, "LEMBRAR EM 10 MIN", acao(ctx, AcaoReceiver.ACAO_ADIAR, i.compromissoId, oc, ID_ALARME, i.minutosAntes))
            .build()
    }

    fun lendo(ctx: Context): Notification = NotificationCompat.Builder(ctx, CANAL_APP)
        .setSmallIcon(R.drawable.ic_notificacao)
        .setContentTitle("Lendo o aviso em voz alta")
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setSilent(true)
        .build()

    fun naoRespondido(ctx: Context, i: AlarmeService.Info, vaiRepetir: Boolean) {
        val texto = "Você não respondeu ao aviso: ${i.titulo} (${com.pausa029.lembraai.domain.Texto.hora(i.hora)})." +
            if (vaiRepetir) " Vou avisar de novo em 10 minutos." else ""
        val n = NotificationCompat.Builder(ctx, CANAL_APP)
            .setSmallIcon(R.drawable.ic_notificacao)
            .setContentTitle("Não respondido")
            .setContentText(texto)
            .setStyle(NotificationCompat.BigTextStyle().bigText(texto))
            .setContentIntent(abrir(ctx, i.ocorrencia.toEpochDay()))
            .setAutoCancel(true)
            .build()
        mostrar(ctx, 8000 + (i.compromissoId % 1000).toInt(), n)
    }
}
