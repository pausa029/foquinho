// Conta: criar, confirmar o e-mail, entrar, sincronizar, sair e apagar a conta.
// A conta é opcional: sem ela o app funciona igual, só no aparelho.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_state.dart';
import '../../services/cloud.dart';
import '../../services/cloud_config.dart';
import '../widgets/common.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

enum _Mode { entrar, criar, confirmar }

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _code = TextEditingController();
  _Mode _mode = _Mode.entrar;
  bool _busy = false;
  bool _show = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _emailOk {
    final e = _email.text.trim();
    return e.length >= 6 && e.contains('@') && e.contains('.') && !e.contains(' ');
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await job();
    } on CloudError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível concluir. Tente de novo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _check({bool password = true}) {
    if (!_emailOk) {
      setState(() => _error = 'Confira o e-mail digitado.');
      return false;
    }
    if (password && _pass.text.length < 8) {
      setState(() => _error = 'A senha precisa de 8 caracteres ou mais.');
      return false;
    }
    return true;
  }

  Future<void> _afterEnter(AppState state, bool choose) async {
    if (!mounted) return;
    if (choose) {
      final useCloud = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Quais dados manter?'),
          content: const Text('Já existem dados guardados na sua conta e também neste aparelho. Escolha qual dos dois deve valer. O outro será substituído.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Os deste aparelho')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Os da conta')),
          ],
        ),
      );
      await state.cloudChoose(useCloud: useCloud ?? true);
    }
    _pass.clear();
    _code.clear();
    if (mounted) showSnack(context, 'Você entrou. Seus dados ficam guardados na conta.');
  }

  Future<void> _signIn(AppState state) async {
    if (!_check()) return;
    await _run(() async => _afterEnter(state, await state.cloudSignIn(_email.text, _pass.text)));
  }

  Future<void> _google(AppState state) async {
    await _run(() async {
      final uri = await state.cloudGoogleStart(kAuthRedirect);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw const CloudError('Não consegui abrir o navegador. Tente de novo.');
      if (mounted) setState(() => _info = 'Escolha sua conta Google no navegador. Depois o Foquinho volta sozinho.');
    });
  }

  Future<void> _signUp(AppState state) async {
    if (!_check()) return;
    await _run(() async {
      final entered = await state.cloudSignUp(_email.text, _pass.text);
      if (entered) {
        await _afterEnter(state, false);
      } else if (mounted) {
        setState(() {
          _mode = _Mode.confirmar;
          _info = 'Enviamos uma mensagem para ${_email.text.trim()}.';
        });
      }
    });
  }

  Future<void> _verify(AppState state) async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Digite o código de 6 números que veio no e-mail.');
      return;
    }
    await _run(() async => _afterEnter(state, await state.cloudVerifyCode(_email.text, code)));
  }

  Future<void> _resend(AppState state) async {
    await _run(() async {
      await state.cloudResend(_email.text);
      if (mounted) setState(() => _info = 'E-mail enviado de novo. Veja também a caixa de spam.');
    });
  }

  Future<void> _reset(AppState state) async {
    if (!_check(password: false)) return;
    await _run(() async {
      await state.cloudResetPassword(_email.text);
      if (mounted) setState(() => _info = 'Se existir uma conta com esse e-mail, enviamos um link para criar uma senha nova.');
    });
  }

  Widget _messages(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600))),
          ),
        if (_info != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(liveRegion: true, child: Text(_info!, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600))),
          ),
      ],
    );
  }

  Widget _emailField() => TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
      );

  Widget _passField({required bool creating, required VoidCallback onDone}) => TextField(
        controller: _pass,
        obscureText: !_show,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [creating ? AutofillHints.newPassword : AutofillHints.password],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onDone(),
        decoration: InputDecoration(
          labelText: creating ? 'Crie uma senha (8 caracteres ou mais)' : 'Senha',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: _show ? 'Esconder a senha' : 'Mostrar a senha',
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _show = !_show),
          ),
        ),
      );

  List<Widget> _signedOut(AppState state, ColorScheme cs) {
    if (_mode == _Mode.confirmar) {
      return [
        Text('Confirme o seu e-mail', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Abra a mensagem do Foquinho no seu e-mail e toque no link de confirmação. Depois volte aqui e toque em "Já confirmei".'),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : () => _signIn(state), child: const Text('Já confirmei, entrar')),
        const SizedBox(height: 20),
        const Text('Se a mensagem trouxer um código de 6 números, digite aqui:'),
        const SizedBox(height: 8),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder(), counterText: ''),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _busy ? null : () => _verify(state), child: const Text('Confirmar com o código')),
        _messages(cs),
        const SizedBox(height: 12),
        TextButton(onPressed: _busy ? null : () => _resend(state), child: const Text('Não chegou? Enviar de novo')),
        TextButton(onPressed: _busy ? null : () => setState(() => _mode = _Mode.criar), child: const Text('Corrigir o e-mail')),
      ];
    }
    final creating = _mode == _Mode.criar;
    return [
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF4285F4))),
        label: const Text('Entrar com Google'),
        onPressed: _busy || state.cloudBusy ? null : () => _google(state),
      ),
      if (state.cloudNote != null && !state.signedIn)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(state.cloudNote!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('ou com e-mail')), Expanded(child: Divider())]),
      ),
      SegmentedButton<_Mode>(
        segments: const [
          ButtonSegment(value: _Mode.entrar, label: Text('Entrar')),
          ButtonSegment(value: _Mode.criar, label: Text('Criar conta')),
        ],
        selected: {_mode},
        onSelectionChanged: (v) => setState(() {
          _mode = v.first;
          _error = null;
          _info = null;
        }),
      ),
      const SizedBox(height: 16),
      Text(
        creating
            ? 'Com uma conta, seus dados ficam guardados e aparecem em outro aparelho quando você entrar.'
            : 'Entre para recuperar seus dados ou continuar em outro aparelho.',
      ),
      const SizedBox(height: 16),
      AutofillGroup(
        child: Column(
          children: [
            _emailField(),
            const SizedBox(height: 12),
            _passField(creating: creating, onDone: () => creating ? _signUp(state) : _signIn(state)),
          ],
        ),
      ),
      _messages(cs),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : () => creating ? _signUp(state) : _signIn(state),
        child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(creating ? 'Criar conta' : 'Entrar'),
      ),
      if (!creating) TextButton(onPressed: _busy ? null : () => _reset(state), child: const Text('Esqueci a senha')),
      const SizedBox(height: 16),
      const InfoNote('A conta é opcional. Sem ela, o Foquinho funciona igual e os dados ficam só neste aparelho. A senha nunca é guardada no aparelho.'),
    ];
  }

  List<Widget> _signedIn(AppState state, ColorScheme cs) {
    final s = state.session!;
    final last = state.lastSyncMs;
    String when = 'ainda não sincronizado';
    if (last != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(last);
      when = 'última sincronização: ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} às ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return [
      if (state.needsDataChoice)
        Card(
          color: cs.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quais dados manter?', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onTertiaryContainer, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Já existem dados na sua conta e também neste aparelho. Escolha qual dos dois deve valer. O outro será substituído.', style: TextStyle(color: cs.onTertiaryContainer)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton(onPressed: () => _run(() => state.cloudChoose(useCloud: true)), child: const Text('Os da conta')),
                  OutlinedButton(onPressed: () => _run(() => state.cloudChoose(useCloud: false)), child: const Text('Os deste aparelho')),
                ]),
              ],
            ),
          ),
        ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.verified_user_outlined),
          title: Text(s.email.isEmpty ? 'Conta conectada' : s.email),
          subtitle: Text(state.cloudBusy ? 'sincronizando…' : when),
        ),
      ),
      if (state.cloudNote != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(state.cloudNote!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 8),
      FilledButton.icon(
        icon: const Icon(Icons.sync),
        label: const Text('Sincronizar agora'),
        onPressed: state.cloudBusy
            ? null
            : () async {
                final ok = await state.cloudSync();
                if (mounted && ok) showSnack(context, 'Tudo sincronizado.');
              },
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Sair da conta neste aparelho'),
        onPressed: _busy
            ? null
            : () => _run(() async {
                  await state.cloudSignOut();
                  if (mounted) showSnack(context, 'Você saiu. Os dados continuam neste aparelho e na conta.');
                }),
      ),
      _messages(cs),
      const SizedBox(height: 24),
      const InfoNote('Seus dados são enviados por conexão segura e só a sua conta consegue ler. Cada alteração é copiada para a nuvem alguns segundos depois; sem internet, a cópia é feita quando a conexão voltar.'),
      const SizedBox(height: 16),
      TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: cs.error),
        icon: const Icon(Icons.delete_forever_outlined),
        label: const Text('Apagar a conta e a cópia na nuvem'),
        onPressed: _busy
            ? null
            : () async {
                final yes = await confirmDialog(
                  context,
                  title: 'Apagar a conta?',
                  text: 'A conta e a cópia dos dados na nuvem serão apagadas e não dá para desfazer. Os dados deste aparelho continuam aqui.',
                  yes: 'Apagar a conta',
                  danger: true,
                );
                if (!yes) return;
                await _run(() async {
                  await state.cloudDeleteAccount();
                  if (mounted) showSnack(context, 'Conta apagada.');
                });
              },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (!state.cloudAvailable)
            const EmptyState(icon: Icons.cloud_off_outlined, title: 'Conta indisponível', text: 'Esta versão do app não tem conta na nuvem.')
          else if (state.signedIn)
            ..._signedIn(state, cs)
          else
            ..._signedOut(state, cs),
        ],
      ),
    );
  }
}
