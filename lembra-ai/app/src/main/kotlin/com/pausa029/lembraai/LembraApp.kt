package com.pausa029.lembraai

import android.app.Application
import com.pausa029.lembraai.alarm.Notificacoes
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

class LembraApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Notificacoes.criarCanais(this)
    }

    companion object {
        /** Para gravações que não podem ser canceladas quando uma tela fecha. */
        val escopo = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    }
}
