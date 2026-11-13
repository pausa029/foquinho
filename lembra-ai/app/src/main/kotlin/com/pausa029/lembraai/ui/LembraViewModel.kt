package com.pausa029.lembraai.ui

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.pausa029.lembraai.alarm.Agendador
import com.pausa029.lembraai.data.Agenda
import com.pausa029.lembraai.data.Ajustes
import com.pausa029.lembraai.data.Preferencias
import com.pausa029.lembraai.domain.Compromisso
import com.pausa029.lembraai.domain.Mensagens
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth

sealed interface Tela {
    data object Compromissos : Tela
    data object Agendar : Tela
    data class Detalhe(val id: Long, val dia: LocalDate) : Tela
    data object Ajustes : Tela
}

class LembraViewModel(app: Application) : AndroidViewModel(app) {
    private val ctx get() = getApplication<Application>()

    val compromissos: StateFlow<List<Compromisso>> =
        Agenda.observar(app).stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())
    val prefs: StateFlow<Preferencias> = Ajustes.fluxo(app)

    var tela by mutableStateOf<Tela>(Tela.Compromissos)
    var dia by mutableStateOf(LocalDate.now())
    var mes by mutableStateOf(YearMonth.now())
    /** Compromisso sendo marcado ou editado na aba AGENDAR (título pode estar vazio). */
    var formulario by mutableStateOf<Compromisso?>(null)
    var mensagem by mutableStateOf<String?>(null)
    var agora by mutableStateOf(LocalDateTime.now())

    init {
        viewModelScope.launch {
            while (true) {
                agora = LocalDateTime.now()
                delay(15_000)
            }
        }
    }

    fun mostrarDia(d: LocalDate) {
        dia = d
        mes = YearMonth.from(d)
        tela = Tela.Compromissos
    }

    fun novo(data: LocalDate? = null) {
        val hoje = LocalDate.now()
        val p = prefs.value
        val d = data?.takeIf { it >= hoje } ?: hoje
        formulario = Compromisso(
            titulo = "", data = d, hora = 9 * 60,
            diasAntes = p.diasAntes, frequencia = p.frequencia,
            avisarNaHora = p.avisarNaHora, avisosAntes = p.avisosAntes,
            estilo = p.estilo, falar = p.falar,
        )
        tela = Tela.Agendar
    }

    fun editar(c: Compromisso) {
        formulario = c
        tela = Tela.Agendar
    }

    fun salvar(c: Compromisso) {
        viewModelScope.launch {
            Agenda.salvar(ctx, c)
            val txt = Mensagens.salvo(c, LocalDate.now(), editado = c.id != 0L)
            formulario = null
            mostrarDia(c.data)
            avisar(txt)
        }
    }

    fun apagar(c: Compromisso) {
        viewModelScope.launch {
            Agenda.apagar(ctx, c.id)
            tela = Tela.Compromissos
            avisar("Pronto! Apaguei o compromisso ${c.titulo}.")
        }
    }

    fun feito(c: Compromisso, d: LocalDate) {
        viewModelScope.launch {
            Agenda.marcarFeito(ctx, c.id, d)
            avisar("Muito bem! Marquei como feito: ${c.titulo}. Não vou mais avisar deste compromisso.")
        }
    }

    fun desfazerFeito(c: Compromisso, d: LocalDate) {
        viewModelScope.launch {
            Agenda.desmarcarFeito(ctx, c.id, d)
            avisar("Pronto! ${c.titulo} voltou a ficar pendente.")
        }
    }

    fun salvarPrefs(p: Preferencias) {
        Ajustes.salvar(ctx, p)
        viewModelScope.launch { Agendador.reagendar(ctx) }
    }

    fun avisar(texto: String, falar: Boolean = true) {
        mensagem = texto
        if (falar) Voz.falar(ctx, texto)
    }
}
