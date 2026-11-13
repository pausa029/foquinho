package com.pausa029.lembraai.data

import android.content.Context
import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Transaction
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.pausa029.lembraai.domain.Compromisso
import com.pausa029.lembraai.domain.EstiloAviso
import com.pausa029.lembraai.domain.Frequencia
import com.pausa029.lembraai.domain.Janela
import com.pausa029.lembraai.domain.ModoFrequencia
import com.pausa029.lembraai.domain.Repeticao
import com.pausa029.lembraai.domain.TipoRepeticao
import kotlinx.coroutines.flow.Flow
import java.time.DayOfWeek
import java.time.LocalDate

@Entity(tableName = "compromisso")
data class CompromissoEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val titulo: String,
    val dataEpoch: Long,
    val hora: Int,
    val diasAntes: Int,
    val janelaInicio: Int?,
    val janelaFim: Int?,
    val modo: String,
    val intervalo: Int,
    val vezes: Int,
    val horarios: String,
    val naHora: Boolean,
    val antes: String,
    val foraJanelaOk: Boolean,
    val estilo: String,
    val falar: Boolean,
    val repete: String,
    val diasSemana: String,
    val cadaDias: Int,
    val ateEpoch: Long?,
    val observacao: String,
    val telefone: String,
    val endereco: String,
    val feitos: String,
    @ColumnInfo(defaultValue = "") val codigoId: String = "",
    @ColumnInfo(defaultValue = "") val enviadoPor: String = "",
)

/** Avisos avulsos: "lembrar em 10 minutos", nova tentativa depois de não responder e o teste. */
@Entity(tableName = "aviso_extra")
data class AvisoExtraEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val compromissoId: Long,
    val ocorrenciaEpoch: Long,
    val quandoMillis: Long,
    val tipo: String,
    val tentativa: Int,
    val minutosAntes: Int,
)

object TipoExtra {
    const val ADIADO = "ADIADO"
    const val NOVA_TENTATIVA = "NOVA_TENTATIVA"
    const val TESTE = "TESTE"
}

@Dao
interface LembraDao {
    @Query("SELECT * FROM compromisso")
    fun observar(): Flow<List<CompromissoEntity>>

    @Query("SELECT * FROM compromisso")
    suspend fun todos(): List<CompromissoEntity>

    @Query("SELECT * FROM compromisso WHERE id = :id")
    suspend fun porId(id: Long): CompromissoEntity?

    @Query("SELECT * FROM compromisso WHERE codigoId = :codigo AND codigoId != '' LIMIT 1")
    suspend fun porCodigo(codigo: String): CompromissoEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun salvar(c: CompromissoEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun salvarTodos(l: List<CompromissoEntity>)

    @Query("DELETE FROM compromisso WHERE id = :id")
    suspend fun apagar(id: Long)

    @Query("DELETE FROM compromisso")
    suspend fun apagarTodos()

    @Query("SELECT * FROM aviso_extra ORDER BY quandoMillis")
    suspend fun extras(): List<AvisoExtraEntity>

    @Insert
    suspend fun inserirExtra(e: AvisoExtraEntity): Long

    @Query("DELETE FROM aviso_extra WHERE id = :id")
    suspend fun apagarExtra(id: Long)

    @Query("DELETE FROM aviso_extra WHERE compromissoId = :cid")
    suspend fun apagarExtrasDe(cid: Long)

    @Query("DELETE FROM aviso_extra WHERE compromissoId = :cid AND ocorrenciaEpoch = :oc")
    suspend fun apagarExtrasDaOcorrencia(cid: Long, oc: Long)

    @Query("DELETE FROM aviso_extra")
    suspend fun apagarTodosExtras()

    @Transaction
    suspend fun trocarTudo(l: List<CompromissoEntity>) {
        apagarTodos()
        apagarTodosExtras()
        salvarTodos(l)
    }
}

@Database(entities = [CompromissoEntity::class, AvisoExtraEntity::class], version = 2, exportSchema = false)
abstract class LembraDb : RoomDatabase() {
    abstract fun dao(): LembraDao

    companion object {
        @Volatile private var instancia: LembraDb? = null

        /** Versão 2: compromisso enviado por link (identificador e nome de quem enviou). */
        val MIGRACAO_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE compromisso ADD COLUMN codigoId TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE compromisso ADD COLUMN enviadoPor TEXT NOT NULL DEFAULT ''")
            }
        }

        /** Fica no armazenamento que funciona antes do primeiro desbloqueio, para os alarmes voltarem depois de reiniciar. */
        fun get(ctx: Context): LembraDb = instancia ?: synchronized(this) {
            instancia ?: Room.databaseBuilder(
                ctx.applicationContext.createDeviceProtectedStorageContext(),
                LembraDb::class.java,
                "lembra.db",
            ).addMigrations(MIGRACAO_1_2).build().also { instancia = it }
        }
    }
}

// ---------- conversão entre o banco e o domínio ----------

private fun lista(s: String): List<Int> = s.split(',').mapNotNull { it.trim().toIntOrNull() }

fun CompromissoEntity.paraDominio() = Compromisso(
    id = id,
    titulo = titulo,
    data = LocalDate.ofEpochDay(dataEpoch),
    hora = hora,
    diasAntes = diasAntes,
    janela = if (janelaInicio != null && janelaFim != null) Janela(janelaInicio, janelaFim) else null,
    frequencia = Frequencia(
        modo = runCatching { ModoFrequencia.valueOf(modo) }.getOrDefault(ModoFrequencia.INTERVALO),
        intervaloMin = intervalo,
        vezes = vezes,
        horarios = lista(horarios),
    ),
    avisarNaHora = naHora,
    avisosAntes = lista(antes),
    avisarForaDaJanela = foraJanelaOk,
    estilo = runCatching { EstiloAviso.valueOf(estilo) }.getOrDefault(EstiloAviso.TOCAR_E_VIBRAR),
    falar = falar,
    repeticao = Repeticao(
        tipo = runCatching { TipoRepeticao.valueOf(repete) }.getOrDefault(TipoRepeticao.NAO_REPETE),
        diasSemana = lista(diasSemana).filter { it in 1..7 }.map { DayOfWeek.of(it) }.toSet(),
        cadaDias = cadaDias,
        ate = ateEpoch?.let { LocalDate.ofEpochDay(it) },
    ),
    observacao = observacao,
    telefone = telefone,
    endereco = endereco,
    feitos = feitos.split(',').mapNotNull { it.trim().toLongOrNull() }.map { LocalDate.ofEpochDay(it) }.toSet(),
    codigoId = codigoId,
    enviadoPor = enviadoPor,
)

fun Compromisso.paraEntidade() = CompromissoEntity(
    id = id,
    titulo = titulo,
    dataEpoch = data.toEpochDay(),
    hora = hora,
    diasAntes = diasAntes,
    janelaInicio = janela?.inicio,
    janelaFim = janela?.fim,
    modo = frequencia.modo.name,
    intervalo = frequencia.intervaloMin,
    vezes = frequencia.vezes,
    horarios = frequencia.horarios.joinToString(","),
    naHora = avisarNaHora,
    antes = avisosAntes.joinToString(","),
    foraJanelaOk = avisarForaDaJanela,
    estilo = estilo.name,
    falar = falar,
    repete = repeticao.tipo.name,
    diasSemana = repeticao.diasSemana.map { it.value }.sorted().joinToString(","),
    cadaDias = repeticao.cadaDias,
    ateEpoch = repeticao.ate?.toEpochDay(),
    observacao = observacao,
    telefone = telefone,
    endereco = endereco,
    // guarda só os "já fiz" dos últimos 400 dias
    feitos = feitos.filter { it >= LocalDate.now().minusDays(400) }.map { it.toEpochDay() }.sorted().joinToString(","),
    codigoId = codigoId,
    enviadoPor = enviadoPor,
)
