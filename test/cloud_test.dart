import 'package:flutter_test/flutter_test.dart';
import 'package:foquinho/data/app_state.dart';
import 'package:foquinho/models/models.dart';
import 'package:foquinho/services/cloud.dart';

class MemStore {
  String? v;
  Future<String?> read() async => v;
  Future<bool> write(String s) async {
    v = s;
    return true;
  }

  Future<bool> clear() async {
    v = null;
    return true;
  }
}

class MemCloudStore implements CloudStore {
  Map<String, dynamic>? m;
  @override
  Future<Map<String, dynamic>?> read() async => m;
  @override
  Future<void> write(Map<String, dynamic> x) async => m = x;
  @override
  Future<void> clear() async => m = null;
}

/// Servidor de mentira: uma conta, uma linha de dados.
class FakeCloud implements CloudApi {
  CloudRow? row;
  int pushes = 0;
  int stamp = 0;
  bool confirmed = true;
  bool offline = false;

  CloudSession _s(String email) => CloudSession(userId: 'u1', email: email, accessToken: 'a', refreshToken: 'r', expiresAtMs: DateTime.now().millisecondsSinceEpoch + 3600000);

  void _net() {
    if (offline) throw const CloudError('Sem conexão com a internet. Tente de novo em instantes.', 'offline');
  }

  @override
  Future<CloudSession?> signUp(String email, String password) async => confirmed ? _s(email) : null;
  @override
  Future<CloudSession> verifyCode(String email, String code) async {
    if (code != '123456') throw const CloudError('Código inválido ou vencido. Peça um novo e-mail.', 'otp_expired');
    return _s(email);
  }

  @override
  Future<CloudSession> signIn(String email, String password) async {
    if (password != 'senha-certa') throw const CloudError('E-mail ou senha incorretos.', 'invalid_credentials');
    return _s(email);
  }

  @override
  Future<CloudSession> refresh(CloudSession s) async => s;
  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signOut(CloudSession s) async {}
  @override
  Future<CloudRow?> pull(CloudSession s) async {
    _net();
    return row;
  }

  @override
  Future<String> push(CloudSession s, Map<String, dynamic> data) async {
    _net();
    pushes++;
    stamp++;
    final at = DateTime.now().toUtc().add(Duration(seconds: stamp)).toIso8601String();
    row = CloudRow(Map<String, dynamic>.from(data), at);
    return at;
  }

  @override
  Future<void> deleteAccount(CloudSession s) async => row = null;

  String? challenge;
  @override
  Uri googleSignInUrl({required String codeChallenge, required String redirectTo}) {
    challenge = codeChallenge;
    return Uri.parse('https://exemplo.test/auth?redirect_to=$redirectTo');
  }

  @override
  Future<CloudSession> exchangeCode(String code, String codeVerifier) async {
    if (code != 'codigo-bom' || Pkce.challengeOf(codeVerifier) != challenge) {
      throw const CloudError('Não foi possível concluir. Tente de novo.', 'bad_code_verifier');
    }
    return _s('g@gmail.com');
  }

  Map<String, dynamic>? lastQuiz;
  @override
  Future<List<QuizQuestion>> quiz(CloudSession s, Map<String, dynamic> request) async {
    lastQuiz = request;
    return const [QuizQuestion(q: '1/2 + 1/2 = ?', options: ['1', '2', '1/4', '0'], answer: 0, explain: 'Metade mais metade é um inteiro.')];
  }
}

AppState make(MemStore m, FakeCloud c, MemCloudStore cs) => AppState(read: m.read, write: m.write, clear: m.clear, cloud: c, cloudStore: cs);

Future<AppState> withProfile(MemStore m, FakeCloud c, MemCloudStore cs, String name) async {
  final st = make(m, c, cs);
  await st.load();
  await st.saveProfile(Profile(nickname: name));
  await st.finishOnboarding();
  return st;
}

void main() {
  test('sem conta, nada vai para a nuvem', () async {
    final c = FakeCloud();
    final st = await withProfile(MemStore(), c, MemCloudStore(), 'Ana');
    expect(st.signedIn, isFalse);
    expect(c.pushes, 0);
    st.dispose();
  });

  test('senha errada devolve mensagem clara e não entra', () async {
    final st = await withProfile(MemStore(), FakeCloud(), MemCloudStore(), 'Ana');
    await expectLater(st.cloudSignIn('a@b.com', 'errada'), throwsA(isA<CloudError>()));
    expect(st.signedIn, isFalse);
    st.dispose();
  });

  test('entrar com conta vazia envia os dados do aparelho', () async {
    final c = FakeCloud();
    final st = await withProfile(MemStore(), c, MemCloudStore(), 'Ana');
    final choose = await st.cloudSignIn('a@b.com', 'senha-certa');
    expect(choose, isFalse);
    expect(st.signedIn, isTrue);
    expect(c.pushes, 1);
    expect((c.row!.data['profile'] as Map)['nickname'], 'Ana');
    st.dispose();
  });

  test('aparelho novo recebe os dados da conta', () async {
    final c = FakeCloud();
    final a = await withProfile(MemStore(), c, MemCloudStore(), 'Ana');
    await a.cloudSignIn('a@b.com', 'senha-certa');
    a.dispose();

    final b = make(MemStore(), c, MemCloudStore());
    await b.load();
    final choose = await b.cloudSignIn('a@b.com', 'senha-certa');
    expect(choose, isFalse);
    expect(b.data.onboarded, isTrue);
    expect(b.data.profile!.nickname, 'Ana');
    expect(c.pushes, 1); // receber não reenvia
    b.dispose();
  });

  test('dados nos dois lados: a pessoa escolhe', () async {
    final c = FakeCloud();
    final a = await withProfile(MemStore(), c, MemCloudStore(), 'Ana');
    await a.cloudSignIn('a@b.com', 'senha-certa');
    a.dispose();

    final b = await withProfile(MemStore(), c, MemCloudStore(), 'Bia');
    expect(await b.cloudSignIn('a@b.com', 'senha-certa'), isTrue);
    expect(b.data.profile!.nickname, 'Bia'); // nada muda antes da escolha
    await b.cloudChoose(useCloud: true);
    expect(b.data.profile!.nickname, 'Ana');
    b.dispose();

    final d = await withProfile(MemStore(), c, MemCloudStore(), 'Duda');
    expect(await d.cloudSignIn('a@b.com', 'senha-certa'), isTrue);
    await d.cloudChoose(useCloud: false);
    expect((c.row!.data['profile'] as Map)['nickname'], 'Duda');
    d.dispose();
  });

  test('alteração local é enviada na sincronização e a sessão é lembrada', () async {
    final c = FakeCloud();
    final m = MemStore();
    final cs = MemCloudStore();
    final st = await withProfile(m, c, cs, 'Ana');
    await st.cloudSignIn('a@b.com', 'senha-certa');
    final p = st.data.profile!..nickname = 'Ana Clara';
    await st.saveProfile(p);
    expect(await st.cloudSync(), isTrue);
    expect((c.row!.data['profile'] as Map)['nickname'], 'Ana Clara');
    st.dispose();

    // Reabrindo o app: continua na conta, sem pedir senha.
    final again = make(m, c, cs);
    await again.load();
    expect(again.signedIn, isTrue);
    expect(again.data.profile!.nickname, 'Ana Clara');
    again.dispose();
  });

  test('sem internet: os dados ficam no aparelho e vão depois', () async {
    final c = FakeCloud();
    final st = await withProfile(MemStore(), c, MemCloudStore(), 'Ana');
    await st.cloudSignIn('a@b.com', 'senha-certa');
    c.offline = true;
    await st.saveProfile(st.data.profile!..nickname = 'Offline');
    expect(await st.cloudSync(), isFalse);
    expect(st.cloudNote, isNotNull);
    expect(st.signedIn, isTrue);
    expect(st.data.profile!.nickname, 'Offline');
    c.offline = false;
    expect(await st.cloudSync(), isTrue);
    expect((c.row!.data['profile'] as Map)['nickname'], 'Offline');
    st.dispose();
  });

  test('mudança feita em outro aparelho chega aqui', () async {
    final c = FakeCloud();
    final a = await withProfile(MemStore(), c, MemCloudStore(), 'Ana');
    await a.cloudSignIn('a@b.com', 'senha-certa');
    final b = make(MemStore(), c, MemCloudStore());
    await b.load();
    await b.cloudSignIn('a@b.com', 'senha-certa');
    await b.saveProfile(b.data.profile!..nickname = 'Do outro');
    await b.cloudSync();
    await a.cloudSync();
    expect(a.data.profile!.nickname, 'Do outro');
    a.dispose();
    b.dispose();
  });

  test('sair mantém os dados; apagar tudo no aparelho não apaga a nuvem', () async {
    final c = FakeCloud();
    final st = await withProfile(MemStore(), c, MemCloudStore(), 'Ana');
    await st.cloudSignIn('a@b.com', 'senha-certa');
    await st.cloudSignOut();
    expect(st.signedIn, isFalse);
    expect(st.data.profile!.nickname, 'Ana');
    await st.cloudSignIn('a@b.com', 'senha-certa');
    await st.cloudChoose(useCloud: true);
    await st.deleteEverything();
    expect(st.signedIn, isFalse);
    expect((c.row!.data['profile'] as Map)['nickname'], 'Ana');
    st.dispose();
  });

  test('criar conta com confirmação por e-mail e código', () async {
    final c = FakeCloud()..confirmed = false;
    final st = await withProfile(MemStore(), c, MemCloudStore(), 'Ana');
    expect(await st.cloudSignUp('a@b.com', 'senha-certa'), isFalse);
    expect(st.signedIn, isFalse);
    await expectLater(st.cloudVerifyCode('a@b.com', '000000'), throwsA(isA<CloudError>()));
    await st.cloudVerifyCode('a@b.com', '123456');
    expect(st.signedIn, isTrue);
    st.dispose();
  });

  test('apagar a conta remove a cópia da nuvem e mantém o aparelho', () async {
    final c = FakeCloud();
    final st = await withProfile(MemStore(), c, MemCloudStore(), 'Ana');
    await st.cloudSignIn('a@b.com', 'senha-certa');
    await st.cloudDeleteAccount();
    expect(c.row, isNull);
    expect(st.signedIn, isFalse);
    expect(st.data.profile!.nickname, 'Ana');
    st.dispose();
  });

  test('login com Google: só entra com o código e o verificador certos', () async {
    final c = FakeCloud();
    final cs = MemCloudStore();
    final m = MemStore();
    final st = await withProfile(m, c, cs, 'Ana');
    final url = await st.cloudGoogleStart('foquinho://login-callback');
    expect(url.toString(), contains('login-callback'));
    expect(c.challenge, isNotNull);

    // Link de outro app, ou cancelado: não entra.
    await st.cloudHandleLink(Uri.parse('https://outro.site/?code=codigo-bom'));
    expect(st.signedIn, isFalse);
    await st.cloudHandleLink(Uri.parse('foquinho://login-callback?error=access_denied'));
    expect(st.signedIn, isFalse);
    expect(st.cloudNote, isNotNull);

    // Começa de novo e volta com o código certo.
    await st.cloudGoogleStart('foquinho://login-callback');
    await st.cloudHandleLink(Uri.parse('foquinho://login-callback?code=codigo-bom'));
    expect(st.signedIn, isTrue);
    expect(st.session!.email, 'g@gmail.com');
    expect((c.row!.data['profile'] as Map)['nickname'], 'Ana');
    st.dispose();
  });

  test('login com Google sobrevive ao app fechar enquanto o navegador está aberto', () async {
    final c = FakeCloud();
    final cs = MemCloudStore();
    final m = MemStore();
    final a = await withProfile(m, c, cs, 'Ana');
    await a.cloudGoogleStart('foquinho://login-callback');
    a.dispose();
    final b = make(m, c, cs);
    await b.load();
    await b.cloudHandleLink(Uri.parse('foquinho://login-callback?code=codigo-bom'));
    expect(b.signedIn, isTrue);
    b.dispose();
  });

  test('Google com dados nos dois lados pede a escolha', () async {
    final c = FakeCloud();
    final a = await withProfile(MemStore(), c, MemCloudStore(), 'Ana');
    await a.cloudSignIn('a@b.com', 'senha-certa');
    a.dispose();
    final b = await withProfile(MemStore(), c, MemCloudStore(), 'Bia');
    await b.cloudGoogleStart('foquinho://login-callback');
    await b.cloudHandleLink(Uri.parse('foquinho://login-callback?code=codigo-bom'));
    expect(b.needsDataChoice, isTrue);
    await b.cloudChoose(useCloud: true);
    expect(b.needsDataChoice, isFalse);
    expect(b.data.profile!.nickname, 'Ana');
    b.dispose();
  });

  test('quiz: precisa de conta e manda matéria e assunto', () async {
    final m = MemStore();
    final c = FakeCloud();
    final st = make(m, c, MemCloudStore());
    await st.load();
    final subj = await st.addSubject('Matemática');
    await expectLater(st.makeQuiz(subjectId: subj.id, topic: 'Frações'), throwsA(isA<CloudError>()));
    await st.cloudSignUp('a@b.com', 'senha-forte-1');
    if (!st.signedIn) await st.cloudVerifyCode('a@b.com', '123456');
    final qs = await st.makeQuiz(subjectId: subj.id, topic: 'Frações');
    expect(qs.single.answer, 0);
    expect(c.lastQuiz!['subject'], 'Matemática');
    expect(c.lastQuiz!['topic'], 'Frações');
  });
}
