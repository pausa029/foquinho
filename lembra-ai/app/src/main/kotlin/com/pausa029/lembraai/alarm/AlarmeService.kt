package com.pausa029.lembraai.alarm

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.pausa029.lembraai.LembraApp
import com.pausa029.lembraai.R
import com.pausa029.lembraai.data.Ajustes
import com.pausa029.lembraai.domain.EstiloAviso
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.Locale
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Toca o alarme (som de alarme + vibração + voz) até a pessoa responder ou por no máximo 2 minutos.
 * Também lê em voz alta os lembretes comuns.
 */
class AlarmeService : Service() {

    data class Info(
        val compromissoId: Long,
        val ocorrencia: LocalDate,
        val tipo: String,
        val minutosAntes: Int,
        val tentativa: Int,
        val topo: String,
        val titulo: String,
        val hora: Int,
        val mensagem: String,
        val observacao: String,
        val endereco: String,
        val telefone: String,
        val estilo: EstiloAviso,
        val falar: Boolean,
    )

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var vibrador: Vibrator? = null
    private var tts: TextToSpeech? = null
    private var ttsPronto = false
    private var falaPendente: Pair<String, () -> Unit>? = null
    private var volumeOriginal: Int? = null
    private var falando = false

    private val semResposta = Runnable {
        val i = estado.value ?: return@Runnable
        pararSom()
        val repetir = i.compromissoId > 0 && i.tentativa < Disparo.TENTATIVAS
        if (repetir) LembraApp.escopo.launch { Disparo.novaTentativa(applicationContext, i) }
        if (i.compromissoId > 0) Notificacoes.naoRespondido(this, i, repetir)
        estado.value = null
        proximo()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instancia = this
        tts = TextToSpeech(applicationContext) { st ->
            if (st == TextToSpeech.SUCCESS) {
                tts?.language = Locale.forLanguageTag("pt-BR")
                tts?.setAudioAttributes(atributosAlarme())
                ttsPronto = true
                falaPendente?.let { (t, depois) -> falaPendente = null; falarAgora(t, depois) }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACAO_ALARME -> {
                if (estado.value == null) proximo() else primeiroPlano(Notificacoes.ID_ALARME, Notificacoes.alarme(this, estado.value!!))
            }
            ACAO_FALAR -> {
                val texto = intent.getStringExtra(EXTRA_TEXTO).orEmpty()
                if (estado.value != null) {
                    // alarme tocando: não fala por cima
                    primeiroPlano(Notificacoes.ID_ALARME, Notificacoes.alarme(this, estado.value!!))
                } else {
                    primeiroPlano(Notificacoes.ID_VOZ, Notificacoes.lendo(this))
                    falando = true
                    falar(texto) { falando = false; encerrarSeOcioso() }
                }
            }
            else -> encerrarSeOcioso()
        }
        return START_NOT_STICKY
    }

    private fun primeiroPlano(id: Int, n: android.app.Notification) {
        try {
            if (Build.VERSION.SDK_INT >= 29) startForeground(id, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(id, n)
        } catch (e: Exception) {
            // Sem permissão para primeiro plano: pelo menos mostra a notificação.
            runCatching { NotificationManagerCompat.from(this).notify(id, n) }
        }
    }

    private fun proximo() {
        handler.removeCallbacks(semResposta)
        val i = fila.poll()
        if (i == null) {
            estado.value = null
            NotificationManagerCompat.from(this).cancel(Notificacoes.ID_ALARME)
            encerrarSeOcioso()
            return
        }
        estado.value = i
        primeiroPlano(Notificacoes.ID_ALARME, Notificacoes.alarme(this, i))
        abrirTela()
        if (i.falar) falar(i.mensagem) { if (estado.value === i) tocar(i) } else tocar(i)
        handler.postDelayed(semResposta, DURACAO_MAXIMA)
    }

    /** Se o celular estiver em uso, tenta abrir a tela do alarme por cima (nem todo Android deixa). */
    private fun abrirTela() {
        runCatching {
            startActivity(Intent(this, AlarmeActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION))
        }
    }

    private fun atributosAlarme() = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private fun uriDoSom(som: Int): Uri {
        val raw = { nome: Int -> Uri.parse("android.resource://$packageName/$nome") }
        return when (som) {
            1 -> raw(R.raw.sino)
            2 -> raw(R.raw.bipe)
            3 -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE) ?: raw(R.raw.sino)
            else -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) ?: raw(R.raw.sino)
        }
    }

    private fun tocar(i: Info) {
        val p = Ajustes.atual(this)
        if (i.estilo != EstiloAviso.SO_VIBRAR) {
            ajustarVolume(p.volume)
            player = criarPlayer(uriDoSom(p.som)) ?: criarPlayer(Uri.parse("android.resource://$packageName/${R.raw.sino}"))
            player?.start()
        }
        if (i.estilo != EstiloAviso.SO_TOCAR) vibrar()
    }

    private fun criarPlayer(uri: Uri): MediaPlayer? = try {
        MediaPlayer().apply {
            setAudioAttributes(atributosAlarme())
            setDataSource(this@AlarmeService, uri)
            isLooping = true
            prepare()
        }
    } catch (e: Exception) { null }

    /** Coloca o volume de alarme do celular no nível escolhido nos Ajustes e devolve depois. */
    private fun ajustarVolume(nivel: Int) {
        val am = getSystemService(AudioManager::class.java) ?: return
        runCatching {
            val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val alvo = maxOf(1, (max * nivel.coerceIn(1, 10)) / 10)
            if (volumeOriginal == null) volumeOriginal = am.getStreamVolume(AudioManager.STREAM_ALARM)
            am.setStreamVolume(AudioManager.STREAM_ALARM, alvo, 0)
        }
    }

    private fun vibrar() {
        val v = if (Build.VERSION.SDK_INT >= 31) getSystemService(VibratorManager::class.java)?.defaultVibrator
        else getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        vibrador = v
        runCatching {
            @Suppress("DEPRECATION")
            v?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 900, 600), 0), atributosAlarme())
        }
    }

    private fun pararSom() {
        handler.removeCallbacks(semResposta)
        runCatching { player?.stop() }
        runCatching { player?.release() }
        player = null
        runCatching { vibrador?.cancel() }
        vibrador = null
        runCatching { tts?.stop() }
        volumeOriginal?.let { v ->
            runCatching { getSystemService(AudioManager::class.java)?.setStreamVolume(AudioManager.STREAM_ALARM, v, 0) }
        }
        volumeOriginal = null
    }

    private fun falar(texto: String, depois: () -> Unit) {
        val uma = AtomicBoolean(false)
        val segue = { if (uma.compareAndSet(false, true)) depois() }
        handler.postDelayed({ segue() }, 20_000) // segurança: se a voz travar, segue
        if (!ttsPronto) {
            falaPendente = texto to segue
            handler.postDelayed({ if (falaPendente != null) { falaPendente = null; segue() } }, 5_000)
            return
        }
        falarAgora(texto, segue)
    }

    private fun falarAgora(texto: String, depois: () -> Unit) {
        val t = tts ?: return depois()
        t.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) { handler.post { depois() } }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) { handler.post { depois() } }
        })
        if (t.speak(texto, TextToSpeech.QUEUE_FLUSH, null, "aviso") != TextToSpeech.SUCCESS) depois()
    }

    private fun encerrarSeOcioso() {
        if (estado.value == null && fila.isEmpty() && !falando) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    /** Resposta da pessoa (JÁ FIZ, LEMBRAR EM 10 MINUTOS): para o alarme atual e mostra o próximo, se houver. */
    fun pararAtual() {
        pararSom()
        estado.value = null
        proximo()
    }

    fun silenciar() {
        handler.removeCallbacks(semResposta)
        runCatching { player?.stop() }
        runCatching { vibrador?.cancel() }
        runCatching { tts?.stop() }
    }

    override fun onDestroy() {
        pararSom()
        runCatching { tts?.shutdown() }
        if (instancia === this) instancia = null
        estado.value = null
        super.onDestroy()
    }

    companion object {
        const val ACAO_ALARME = "com.pausa029.lembraai.ALARME"
        const val ACAO_FALAR = "com.pausa029.lembraai.FALAR"
        const val EXTRA_TEXTO = "texto"
        const val DURACAO_MAXIMA = 2 * 60_000L

        private val fila = ConcurrentLinkedQueue<Info>()
        private val estado = MutableStateFlow<Info?>(null)
        val atual: StateFlow<Info?> = estado

        @Volatile private var instancia: AlarmeService? = null

        fun tocar(ctx: Context, i: Info) {
            fila.add(i)
            ContextCompat.startForegroundService(ctx, Intent(ctx, AlarmeService::class.java).setAction(ACAO_ALARME))
        }

        fun falar(ctx: Context, texto: String) {
            runCatching {
                ContextCompat.startForegroundService(ctx, Intent(ctx, AlarmeService::class.java).setAction(ACAO_FALAR).putExtra(EXTRA_TEXTO, texto))
            }
        }

        fun pararAtual() {
            Handler(Looper.getMainLooper()).post { instancia?.pararAtual() }
        }

        fun silenciar() {
            Handler(Looper.getMainLooper()).post { instancia?.silenciar() }
        }

        /** Para o alarme se ele for deste compromisso (ou o teste). Também tira da fila. */
        fun pararSeFor(id: Long, oc: LocalDate) {
            fila.removeAll { it.compromissoId == id && it.ocorrencia == oc }
            val a = estado.value
            if (a != null && a.compromissoId == id && (id <= 0 || a.ocorrencia == oc)) pararAtual()
        }
    }
}
