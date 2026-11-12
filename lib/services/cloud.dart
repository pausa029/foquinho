// Conta e cópia dos dados na nuvem (Supabase), por HTTPS.
// O app continua funcionando sem conta e sem internet; a conta só acrescenta
// a cópia de segurança e o uso em mais de um aparelho.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Erro com mensagem pronta para mostrar à pessoa.
class CloudError implements Exception {
  final String message;
  final String code;
  const CloudError(this.message, [this.code = '']);
  @override
  String toString() => message;
}

class CloudSession {
  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  final int expiresAtMs;

  const CloudSession({required this.userId, required this.email, required this.accessToken, required this.refreshToken, required this.expiresAtMs});

  bool expiresSoon(int nowMs) => nowMs > expiresAtMs - 60000;

  Map<String, dynamic> toJson() => {'userId': userId, 'email': email, 'accessToken': accessToken, 'refreshToken': refreshToken, 'expiresAtMs': expiresAtMs};

  static CloudSession? fromJson(Map<String, dynamic> m) {
    final id = m['userId'], at = m['accessToken'], rt = m['refreshToken'], ex = m['expiresAtMs'];
    if (id is! String || at is! String || rt is! String || ex is! int || id.isEmpty || at.isEmpty || rt.isEmpty) return null;
    final email = m['email'];
    return CloudSession(userId: id, email: email is String ? email : '', accessToken: at, refreshToken: rt, expiresAtMs: ex);
  }
}

/// Linha de dados guardada na nuvem.
class CloudRow {
  final Map<String, dynamic> data;
  final String updatedAt;
  const CloudRow(this.data, this.updatedAt);
}

abstract class CloudApi {
  /// Cria a conta. Devolve a sessão se o e-mail não precisar de confirmação; senão, null.
  Future<CloudSession?> signUp(String email, String password);
  Future<CloudSession> verifyCode(String email, String code);
  Future<CloudSession> signIn(String email, String password);
  Future<CloudSession> refresh(CloudSession s);
  Future<void> resendConfirmation(String email);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut(CloudSession s);
  Future<CloudRow?> pull(CloudSession s);

  /// Grava os dados e devolve o carimbo de data da gravação.
  Future<String> push(CloudSession s, Map<String, dynamic> data);
  Future<void> deleteAccount(CloudSession s);
}

/// Onde ficam guardados, no aparelho, a sessão e o controle da sincronização.
abstract class CloudStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> m);
  Future<void> clear();
}

class PrefsCloudStore implements CloudStore {
  static const _key = 'foquinho.conta.v1';

  @override
  Future<Map<String, dynamic>?> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final d = jsonDecode(raw);
      return d is Map ? Map<String, dynamic>.from(d) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> m) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(m));
    } catch (_) {
      // sem gravação: a pessoa só precisará entrar de novo
    }
  }

  @override
  Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {
      // nada a fazer
    }
  }
}

class SupabaseCloud implements CloudApi {
  final String url;
  final String key;
  final http.Client _client;

  SupabaseCloud({required this.url, required this.key, http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers([CloudSession? s]) => {
        'apikey': key,
        'Content-Type': 'application/json',
        if (s != null) 'Authorization': 'Bearer ${s.accessToken}',
      };

  static const _offline = CloudError('Sem conexão com a internet. Tente de novo em instantes.', 'offline');

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 20));
    } on CloudError {
      rethrow;
    } catch (_) {
      throw _offline;
    }
  }

  dynamic _json(http.Response r) {
    if (r.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  CloudError _error(http.Response r) {
    final j = _json(r);
    var code = '';
    var msg = '';
    if (j is Map) {
      code = '${j['error_code'] ?? j['code'] ?? j['error'] ?? ''}';
      msg = '${j['msg'] ?? j['message'] ?? j['error_description'] ?? ''}';
    }
    final all = '$code $msg'.toLowerCase();
    String text;
    if (all.contains('invalid_credentials') || all.contains('invalid login')) {
      text = 'E-mail ou senha incorretos.';
    } else if (all.contains('email_not_confirmed') || all.contains('not confirmed')) {
      text = 'Confirme o seu e-mail antes de entrar. Veja a mensagem que enviamos.';
    } else if (all.contains('user_already_exists') || all.contains('already registered')) {
      text = 'Já existe uma conta com esse e-mail. Use "Entrar".';
    } else if (all.contains('weak_password') || all.contains('password should')) {
      text = 'Senha fraca. Use 8 caracteres ou mais.';
    } else if (all.contains('rate_limit') || r.statusCode == 429) {
      text = 'Muitas tentativas em pouco tempo. Espere alguns minutos e tente de novo.';
    } else if (all.contains('otp_expired') || all.contains('token has expired') || all.contains('invalid token')) {
      text = 'Código inválido ou vencido. Peça um novo e-mail.';
    } else if (all.contains('validation_failed') || all.contains('invalid format') || all.contains('email_address_invalid')) {
      text = 'Confira o e-mail digitado.';
    } else if (all.contains('signup_disabled')) {
      text = 'A criação de contas está desligada no momento.';
    } else if (r.statusCode == 401 || r.statusCode == 403) {
      text = 'Sua sessão venceu. Entre de novo.';
      code = code.isEmpty ? 'unauthorized' : code;
    } else if (r.statusCode >= 500) {
      text = 'O servidor não respondeu direito. Tente de novo em instantes.';
    } else {
      text = 'Não foi possível concluir. Tente de novo.';
    }
    return CloudError(text, code.isEmpty ? 'http_${r.statusCode}' : code);
  }

  CloudSession _session(dynamic j, {String fallbackEmail = ''}) {
    if (j is Map && j['access_token'] is String && j['refresh_token'] is String) {
      final user = j['user'];
      final id = user is Map ? '${user['id'] ?? ''}' : '';
      final email = user is Map && user['email'] is String ? user['email'] as String : fallbackEmail;
      final exp = j['expires_in'];
      final secs = exp is num ? exp.toInt() : 3600;
      if (id.isNotEmpty) {
        return CloudSession(
          userId: id,
          email: email,
          accessToken: j['access_token'] as String,
          refreshToken: j['refresh_token'] as String,
          expiresAtMs: DateTime.now().millisecondsSinceEpoch + secs * 1000,
        );
      }
    }
    throw const CloudError('Resposta inesperada do servidor. Tente de novo.', 'formato');
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body, {CloudSession? s, Map<String, String> extra = const {}}) async {
    final r = await _send(() => _client.post(Uri.parse('$url$path'), headers: {..._headers(s), ...extra}, body: jsonEncode(body)));
    if (r.statusCode < 200 || r.statusCode >= 300) throw _error(r);
    return _json(r);
  }

  @override
  Future<CloudSession?> signUp(String email, String password) async {
    final j = await _post('/auth/v1/signup', {'email': email, 'password': password});
    if (j is Map && j['access_token'] is String) return _session(j, fallbackEmail: email);
    return null;
  }

  @override
  Future<CloudSession> verifyCode(String email, String code) async {
    return _session(await _post('/auth/v1/verify', {'type': 'signup', 'email': email, 'token': code}), fallbackEmail: email);
  }

  @override
  Future<CloudSession> signIn(String email, String password) async {
    return _session(await _post('/auth/v1/token?grant_type=password', {'email': email, 'password': password}), fallbackEmail: email);
  }

  @override
  Future<CloudSession> refresh(CloudSession s) async {
    return _session(await _post('/auth/v1/token?grant_type=refresh_token', {'refresh_token': s.refreshToken}), fallbackEmail: s.email);
  }

  @override
  Future<void> resendConfirmation(String email) async {
    await _post('/auth/v1/resend', {'type': 'signup', 'email': email});
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _post('/auth/v1/recover', {'email': email});
  }

  @override
  Future<void> signOut(CloudSession s) async {
    try {
      await _post('/auth/v1/logout?scope=local', const {}, s: s);
    } catch (_) {
      // sair do aparelho vale mesmo sem internet
    }
  }

  @override
  Future<CloudRow?> pull(CloudSession s) async {
    final uri = Uri.parse('$url/rest/v1/user_data?select=data,updated_at&user_id=eq.${s.userId}&limit=1');
    final r = await _send(() => _client.get(uri, headers: _headers(s)));
    if (r.statusCode < 200 || r.statusCode >= 300) throw _error(r);
    final j = _json(r);
    if (j is List && j.isNotEmpty && j.first is Map) {
      final row = j.first as Map;
      final data = row['data'];
      if (data is Map) return CloudRow(Map<String, dynamic>.from(data), '${row['updated_at'] ?? ''}');
    }
    return null;
  }

  @override
  Future<String> push(CloudSession s, Map<String, dynamic> data) async {
    final stamp = DateTime.now().toUtc().toIso8601String();
    final j = await _post(
      '/rest/v1/user_data?on_conflict=user_id&select=updated_at',
      {'user_id': s.userId, 'data': data, 'updated_at': stamp},
      s: s,
      extra: const {'Prefer': 'resolution=merge-duplicates,return=representation'},
    );
    if (j is List && j.isNotEmpty && j.first is Map) return '${(j.first as Map)['updated_at'] ?? stamp}';
    return stamp;
  }

  @override
  Future<void> deleteAccount(CloudSession s) async {
    await _post('/rest/v1/rpc/delete_my_account', const {}, s: s);
  }
}
