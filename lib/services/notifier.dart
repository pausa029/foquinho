// Notificações do sistema (Android e iOS), agendadas no próprio aparelho.
// Não usa servidor nem internet. Na versão web este serviço fica desativado.

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../logic/reminders.dart';

abstract class Notifier {
  /// Este aparelho/plataforma tem notificações do sistema?
  bool get supported;

  Future<bool> init();

  /// Pede a permissão ao sistema. Chame só depois de explicar o motivo à pessoa.
  Future<bool> requestPermission();

  Future<bool> isAllowed();

  /// Deixa agendada exatamente a lista nova (cancela pendentes que saíram dela).
  Future<void> replaceAll(List<PlannedNotice> notices);

  /// Tira da tela (e silencia) os alarmes do temporizador que já tocaram.
  Future<void> dismissAlarms();

  Future<void> showTest();
}

class LocalNotifier implements Notifier {
  final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> init() async {
    if (!supported) return false;
    if (_ready) return true;
    try {
      // Os horários são passados como instantes em UTC; não é preciso o banco de fusos.
      tz.setLocalLocation(tz.UTC);
      await _p.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<bool> requestPermission() async {
    if (!await init()) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final r = await a?.requestNotificationsPermission();
        return r ?? await isAllowed();
      }
      final i = _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final r = await i?.requestPermissions(alert: true, sound: true, badge: false);
      return r ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isAllowed() async {
    if (!await init()) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await a?.areNotificationsEnabled() ?? false;
      }
      final i = _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final o = await i?.checkPermissions();
      return o?.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  NotificationDetails _details(bool alarm, {bool loop = false}) {
    if (alarm) {
      // Canal novo (v2): o Android não deixa mudar som e vibração de um canal já criado.
      return NotificationDetails(
        android: AndroidNotificationDetails(
          'foquinho_alarme_v2',
          'Alarme do temporizador',
          channelDescription: 'Toca quando uma sessão de foco, intervalo ou exercício termina.',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('foquinho_alarme'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList(<int>[0, 700, 400, 700, 400, 700, 400, 700]),
          visibility: NotificationVisibility.public,
          // 4 = FLAG_INSISTENT: repete o som até a pessoa tocar no aviso ou parar pelo app.
          additionalFlags: loop ? Int32List.fromList(<int>[4]) : null,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );
    }
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'foquinho_lembretes',
        'Lembretes',
        channelDescription: 'Lembretes de estudo, movimento, pausas de tela, tarefas e provas.',
        importance: Importance.high,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
  }

  Future<void> _schedule(PlannedNotice n, AndroidScheduleMode mode) {
    return _p.zonedSchedule(
      n.id,
      n.title,
      n.body,
      tz.TZDateTime.from(n.when, tz.UTC),
      _details(n.alarm, loop: n.loop),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> replaceAll(List<PlannedNotice> notices) async {
    if (!await init()) return;
    // Cancela só o que ainda está pendente e saiu da lista. Avisos que já tocaram
    // ficam na tela (cancelar tudo cortaria o som do alarme que acabou de disparar).
    final keep = notices.map((n) => n.id).toSet();
    try {
      final pending = await _p.pendingNotificationRequests();
      for (final r in pending) {
        if (!keep.contains(r.id)) await _p.cancel(r.id);
      }
    } catch (_) {
      // segue: agendar por cima substitui os que tiverem o mesmo id
    }
    final now = DateTime.now();
    for (final n in notices) {
      if (!n.when.isAfter(now)) continue;
      try {
        // alarmClock é o modo mais pontual do Android (o mesmo do despertador).
        await _schedule(n, n.alarm ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (_) {
        // Sem permissão de alarme exato: agenda de forma aproximada.
        try {
          await _schedule(n, AndroidScheduleMode.inexactAllowWhileIdle);
        } catch (_) {
          // Este aviso não pôde ser agendado; os outros continuam.
        }
      }
    }
  }

  @override
  Future<void> dismissAlarms() async {
    if (!await init()) return;
    try {
      final pending = (await _p.pendingNotificationRequests()).map((r) => r.id).toSet();
      for (var id = kTimerIdBase; id < kTimerIdBase + kTimerIdCount; id++) {
        if (!pending.contains(id)) await _p.cancel(id);
      }
      await _p.cancel(2);
    } catch (_) {
      // nada a fazer
    }
  }

  @override
  Future<void> showTest() async {
    if (!await init()) return;
    try {
      // Teste com o mesmo som e vibração do alarme (toca uma vez).
      await _p.show(2, 'Foquinho', 'Assim toca o alarme do temporizador.', _details(true));
    } catch (_) {
      // nada a fazer
    }
  }
}
