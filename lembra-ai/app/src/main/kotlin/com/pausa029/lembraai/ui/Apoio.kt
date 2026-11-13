package com.pausa029.lembraai.ui

import android.Manifest
import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.speech.tts.TextToSpeech
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.pausa029.lembraai.data.Ajustes
import java.util.Locale

/** Voz para as confirmações das telas ("Pronto! Compromisso salvo..."). */
object Voz {
    private var tts: TextToSpeech? = null
    private var pronto = false
    private var pendente: String? = null

    /** Fala só se "Falar os avisos em voz alta" estiver ligado. */
    fun falar(ctx: Context, texto: String) {
        if (Ajustes.atual(ctx).falar) falarSempre(ctx, texto)
    }

    /** Fala porque a pessoa pediu (ex.: OUVIR OS COMPROMISSOS DESTE DIA). */
    fun falarSempre(ctx: Context, texto: String) {
        val t = tts
        if (t == null) {
            pendente = texto
            tts = TextToSpeech(ctx.applicationContext) { st ->
                if (st == TextToSpeech.SUCCESS) {
                    tts?.language = Locale.forLanguageTag("pt-BR")
                    pronto = true
                    pendente?.let { tts?.speak(it, TextToSpeech.QUEUE_FLUSH, null, "tela") }
                    pendente = null
                }
            }
            return
        }
        if (pronto) t.speak(texto, TextToSpeech.QUEUE_FLUSH, null, "tela") else pendente = texto
    }

    fun parar() {
        runCatching { tts?.stop() }
    }
}

/** Situação das permissões e atalhos para as telas certas das configurações do celular. */
object Permissoes {
    fun notificacoes(ctx: Context): Boolean =
        (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            NotificationManagerCompat.from(ctx).areNotificationsEnabled()

    fun alarmes(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < 31 || ctx.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    fun telaCheia(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < 34 || ctx.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()

    fun bateria(ctx: Context): Boolean =
        ctx.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(ctx.packageName)

    /** "Não perturbe" em silêncio total bloqueia até alarmes. */
    fun silencioTotal(ctx: Context): Boolean =
        ctx.getSystemService(NotificationManager::class.java).currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_NONE

    private fun pacote(ctx: Context) = Uri.parse("package:" + ctx.packageName)

    fun abrir(ctx: Context, i: Intent): Boolean =
        runCatching { ctx.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }.isSuccess

    fun abrirConfigApp(ctx: Context) {
        abrir(ctx, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pacote(ctx)))
    }

    fun abrirNotificacoes(ctx: Context) {
        if (!abrir(ctx, Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName))) abrirConfigApp(ctx)
    }

    fun abrirAlarmes(ctx: Context) {
        if (Build.VERSION.SDK_INT >= 31 && abrir(ctx, Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pacote(ctx)))) return
        abrirConfigApp(ctx)
    }

    fun abrirTelaCheia(ctx: Context) {
        if (Build.VERSION.SDK_INT >= 34 && abrir(ctx, Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pacote(ctx)))) return
        abrirConfigApp(ctx)
    }

    @SuppressLint("BatteryLife")
    fun abrirBateria(ctx: Context) {
        if (abrir(ctx, Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pacote(ctx)))) return
        if (abrir(ctx, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))) return
        abrirConfigApp(ctx)
    }

    fun abrirNaoPerturbe(ctx: Context) {
        if (!abrir(ctx, Intent("android.settings.ZEN_MODE_SETTINGS"))) abrir(ctx, Intent(Settings.ACTION_SETTINGS))
    }

    /** Tela de "início automático" / bateria de cada fabricante, quando existir. */
    fun abrirInicioAutomatico(ctx: Context) {
        val telas = listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            ComponentName("com.samsung.android.sm", "com.samsung.android.sm.battery.ui.BatteryActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.entry.FunctionActivity"),
        )
        val fab = Build.MANUFACTURER.lowercase()
        val doFabricante = telas.filter { c ->
            val p = c.packageName
            (fab.contains("xiaomi") || fab.contains("redmi") || fab.contains("poco")) && p.contains("miui") ||
                fab.contains("samsung") && p.contains("samsung") ||
                (fab.contains("oppo") || fab.contains("realme") || fab.contains("oneplus")) && (p.contains("coloros") || p.contains("oppo")) ||
                fab.contains("vivo") && p.contains("vivo") ||
                (fab.contains("huawei") || fab.contains("honor")) && p.contains("huawei") ||
                fab.contains("asus") && p.contains("asus")
        }
        for (c in doFabricante) if (abrir(ctx, Intent().setComponent(c))) return
        abrirConfigApp(ctx)
    }

    fun dicaFabricante(): String {
        val f = Build.MANUFACTURER.lowercase()
        return when {
            f.contains("xiaomi") || f.contains("redmi") || f.contains("poco") ->
                "No Xiaomi: ligue \"Início automático\" para o Lembra Aí e, em \"Economia de bateria\", escolha \"Sem restrições\"."
            f.contains("samsung") ->
                "No Samsung: em Bateria, escolha \"Sem restrição\" para o Lembra Aí e confira se ele não está em \"Apps em suspensão\"."
            f.contains("motorola") ->
                "No Motorola: em Bateria do app, escolha \"Sem restrição\"."
            else ->
                "Nas configurações do app, em Bateria, escolha \"Sem restrição\". Se existir \"Início automático\", deixe ligado."
        }
    }
}
