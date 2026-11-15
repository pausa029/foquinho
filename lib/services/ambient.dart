// Som de fundo do temporizador (chuva, ondas, lareira, ruído) e o sino de troca de fase.
// Os sons são gerados pelo próprio projeto (tool/sons/gerar.py) e ficam em assets/sons/.

import 'package:audioplayers/audioplayers.dart';

class Ambient {
  Ambient._();
  static final Ambient instance = Ambient._();

  AudioPlayer? _loop;
  AudioPlayer? _bell;
  String? _playing; // som tocando agora (null = parado)
  double _volume = 0.6;

  /// Deixa tocando o som [id] (ou para, se for 'nenhum' ou [on] for falso).
  Future<void> ensure(String id, {required bool on, required double volume}) async {
    try {
      if (!on || id == 'nenhum') {
        if (_playing != null) {
          _playing = null;
          await _loop?.pause();
        }
        return;
      }
      final p = _loop ??= AudioPlayer(playerId: 'foquinho_fundo');
      if (_playing == id) {
        if ((volume - _volume).abs() > 0.01) {
          _volume = volume;
          await p.setVolume(volume);
        }
        return;
      }
      _playing = id;
      _volume = volume;
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(volume);
      await p.play(AssetSource('sons/$id.m4a'));
    } catch (_) {
      // Sem som não pode travar o temporizador.
      _playing = null;
    }
  }

  Future<void> stop() async {
    _playing = null;
    try {
      await _loop?.stop();
    } catch (_) {}
  }

  /// Toque curto de sino (troca de foco/intervalo e fim da sessão).
  Future<void> bell() async {
    try {
      final b = _bell ??= AudioPlayer(playerId: 'foquinho_sino');
      await b.setReleaseMode(ReleaseMode.stop);
      await b.setVolume(0.9);
      await b.play(AssetSource('sons/sino.m4a'));
    } catch (_) {}
  }

  /// Amostra de 4 segundos para escolher o som.
  Future<void> preview(String id, double volume) async {
    if (id == 'nenhum') {
      await stop();
      return;
    }
    await ensure(id, on: true, volume: volume);
    Future.delayed(const Duration(seconds: 4), () {
      if (_playing == id && !_keep) stop();
    });
  }

  bool _keep = false;

  /// Quando o temporizador está rodando, a amostra não para o som.
  set keepPlaying(bool v) => _keep = v;
}
