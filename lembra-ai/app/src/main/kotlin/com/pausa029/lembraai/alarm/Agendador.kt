package com.pausa029.lembraai.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.pausa029.lembraai.data.Agenda
import com.pausa029.lembraai.data.Ajustes
import com.pausa029.lembraai.data.LembraDb
import com.pausa029.lembraai.domain.CalculoAvisos
import com.pausa029.lembraai.ui.MainActivity
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.concurrent.TimeUnit

/**
 * Agenda sempre só o PRÓXIMO aviso no AlarmManager (o Android limita a quantidade de alarmes por app).
 * Quando ele toca, o app mostra o que venceu e agenda o seguinte. Os avisos são recalculados
 * a partir do banco, para os próximos 60 dias, a cada mudança, ao ligar o celular e uma vez por dia.
 */
object Agendador {
    private const val PEDIDO = 4242
    private val trava = Mutex()

    fun zona(): ZoneId = ZoneId.systemDefault()
    fun millis(t: LocalDateTime) = t.atZone(zona()).toInstant().toEpochMilli()
    fun data(ms: Long): LocalDateTime = LocalDateTime.ofInstant(Instant.ofEpochMilli(ms), zona())

    suspend fun reagendar(ctx: Context) = trava.withLock {
        val app = ctx.applicationContext
        val p = Ajustes.atual(app)
        val agora = System.currentTimeMillis()
        val base = maxOf(agora, Ajustes.ultimoDisparo(app))
        val comps = Agenda.todos(app)
        val prox = CalculoAvisos.proximos(comps, p.janela, p.bomDia, data(base)).firstOrNull()
        val extra = LembraDb.get(app).dao().extras().minByOrNull { it.quandoMillis }

        val candidatos = listOfNotNull(
            prox?.let { millis(it.quando) to it.especial },
            extra?.let { maxOf(it.quandoMillis, agora + 1000) to true },
        )
        val am = app.getSystemService(AlarmManager::class.java)
        val pi = disparo(app)
        am.cancel(pi)
        val alvo = candidatos.minByOrNull { it.first } ?: return@withLock
        val (quando, especial) = alvo
        try {
            when {
                Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms() ->
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, quando, pi)
                especial -> am.setAlarmClock(AlarmManager.AlarmClockInfo(quando, abrirApp(app)), pi)
                else -> am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, quando, pi)
            }
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, quando, pi)
        }
    }

    private fun disparo(ctx: Context): PendingIntent = PendingIntent.getBroadcast(
        ctx, PEDIDO,
        Intent(ctx, DisparoReceiver::class.java).setAction("com.pausa029.lembraai.DISPARAR"),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun abrirApp(ctx: Context): PendingIntent = PendingIntent.getActivity(
        ctx, 1,
        Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /** Verificação diária: renova os avisos dos compromissos que repetem. */
    fun agendarRenovacao(ctx: Context) {
        WorkManager.getInstance(ctx).enqueueUniquePeriodicWork(
            "renovar-avisos",
            ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<RenovacaoWorker>(1, TimeUnit.DAYS).build(),
        )
    }
}

class RenovacaoWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result {
        Agendador.reagendar(applicationContext)
        return Result.success()
    }
}
