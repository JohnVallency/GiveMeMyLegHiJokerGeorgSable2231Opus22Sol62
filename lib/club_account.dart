import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ClubAccount extends ChangeNotifier {
  ClubAccount._();
  static final instance = ClubAccount._();

  static const _configured = String.fromEnvironment('CLUB_SERVER');
  static String get base => kIsWeb ? Uri.base.origin : _configured;
  String? _token;
  int _sessionVersion = 0;
  String? name;
  int coins = 0;

  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    if (base.isEmpty) {
      throw const ClubError('Адрес облачного сервера ещё не настроен.');
    }
    final uri = Uri.parse('$base/api/$path');
    final headers = {
      'Accept': 'application/json',
      if (data != null) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    try {
      final response =
          await (data == null
                  ? http.get(uri, headers: headers)
                  : http.post(uri, headers: headers, body: jsonEncode(data)))
              .timeout(const Duration(seconds: 12));
      final result =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw ClubError(
          result['error']?.toString() ?? 'Ошибка сервера.',
          response.statusCode,
        );
      }
      return result;
    } on ClubError {
      rethrow;
    } catch (_) {
      throw const ClubError('Нет связи с облачным сервером.');
    }
  }

  void _update(Map<String, dynamic> response) {
    name = response['name'] as String;
    coins = response['coins'] as int;
    notifyListeners();
  }

  Future<void> restore() async {
    final version = _sessionVersion;
    try {
      final profile = await request('me');
      if (version == _sessionVersion) _update(profile);
    } on ClubError catch (error) {
      if (version == _sessionVersion && error.status == 401 && name != null) {
        _token = null;
        name = null;
        coins = 0;
        notifyListeners();
      }
    }
  }

  Future<void> login(
    String name,
    String password, {
    required bool create,
  }) async {
    _sessionVersion++;
    final response = await request(create ? 'register' : 'login', {
      'name': name,
      'password': password,
      'native': !kIsWeb,
    });
    _token = response['token'] as String?;
    _update(response);
  }

  Future<void> logout() async {
    _sessionVersion++;
    try {
      await request('logout', {});
    } on ClubError catch (error) {
      if (error.status != 401) rethrow;
    }
    _token = null;
    name = null;
    coins = 0;
    notifyListeners();
  }

  final _random = Random.secure();
  Future<void> rewardStamp() async {
    if (name == null) {
      throw const ClubError(
        'Войдите в аккаунт, чтобы получать монеты за фигуры.',
      );
    }
    final id = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final owner = name;
    try {
      _updateIfCurrent(owner, await request('stamps', {'id': id}));
    } on ClubError catch (error) {
      if (error.status != null || owner != name) rethrow;
      _updateIfCurrent(owner, await request('stamps', {'id': id}));
    }
  }

  void _updateIfCurrent(String? owner, Map<String, dynamic> response) {
    if (owner != name) return;
    final balance = response['coins'] as int;
    if (balance > coins) _update(response);
  }

  Future<String> chessTicket() async {
    final response = await request('chess-ticket', {});
    return response['ticket'] as String;
  }
}

class ClubError implements Exception {
  const ClubError(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

Future<void> showClubAccount(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute<void>(builder: (_) => const _AccountPage()));

class _AccountPage extends StatefulWidget {
  const _AccountPage();

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  final _account = ClubAccount.instance;
  var _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _create = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _switchMode(bool create) {
    if (_busy || create == _create) return;
    setState(() {
      _form = GlobalKey<FormState>();
      _create = create;
      _error = null;
    });
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _account.login(_name.text, _password.text, create: _create);
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.of(context).pop();
    } on ClubError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _account.logout();
      if (!mounted) return;
      _password.clear();
      setState(() => _showPassword = false);
    } on ClubError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _field(String label, {String? hint, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF1F2436),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      );

  Widget _status(BuildContext context) {
    final error = _error;
    if (error == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              error,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginForm(BuildContext context) => AutofillGroup(
    key: ValueKey(_create),
    onDisposeAction: AutofillContextAction.cancel,
    child: Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Вход')),
              ButtonSegment(value: true, label: Text('Регистрация')),
            ],
            selected: {_create},
            onSelectionChanged: _busy
                ? null
                : (value) => _switchMode(value.single),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            enabled: !_busy,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            autofillHints: [
              _create ? AutofillHints.newUsername : AutofillHints.username,
            ],
            decoration: _field(
              'Имя пользователя',
              hint: _create ? 'От 3 до 24 символов' : null,
            ),
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            onChanged: _clearError,
            validator: (value) {
              final name = (value ?? '').trim();
              if (name.isEmpty) return 'Введите имя пользователя';
              if (_create &&
                  !RegExp(
                    r'^[\p{L}\p{N}_-]{3,24}$',
                    unicode: true,
                  ).hasMatch(name)) {
                return '3–24 символа: буквы, цифры, дефис или подчёркивание';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            focusNode: _passwordFocus,
            enabled: !_busy,
            obscureText: !_showPassword,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            autofillHints: [
              _create ? AutofillHints.newPassword : AutofillHints.password,
            ],
            decoration: _field(
              'Пароль',
              hint: _create ? 'От 8 до 128 символов' : null,
              suffix: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _showPassword = !_showPassword),
                child: Text(_showPassword ? 'Скрыть' : 'Показать'),
              ),
            ),
            onFieldSubmitted: (_) => _submit(),
            onChanged: _clearError,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Введите пароль';
              if (_create && (value.length < 8 || value.length > 128)) {
                return 'Пароль должен содержать 8–128 символов';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _status(context),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _busy ? null : _submit,
            child: Text(
              _busy
                  ? 'Подключение…'
                  : _create
                  ? 'Создать аккаунт'
                  : 'Войти',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _profile(BuildContext context, String name) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF25263E),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(
                '${_account.coins} мон.',
                style: const TextStyle(
                  color: Color(0xFFFFD28D),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _status(context),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _busy ? null : _logout,
        child: Text(_busy ? 'Подключение…' : 'Выйти из аккаунта'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _account,
    builder: (context, _) {
      final name = _account.name;
      return PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: const Color(0xFF131725),
          appBar: AppBar(
            backgroundColor: const Color(0xFF131725),
            foregroundColor: const Color(0xFFFFF6EC),
            title: const Text('Общий аккаунт'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Theme(
                    data: ThemeData(
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: const Color(0xFFE3B56E),
                        brightness: Brightness.dark,
                      ),
                      fontFamily: 'Segoe UI',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          name != null
                              ? 'Профиль'
                              : _create
                              ? 'Создай аккаунт'
                              : 'Войди в игровой клуб',
                          style: const TextStyle(
                            color: Color(0xFFFFF6EC),
                            fontSize: 30,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (name == null) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Один профиль для онлайн-игр и монет.',
                            style: TextStyle(color: Color(0xFFBEC2D3)),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (name == null)
                          _loginForm(context)
                        else
                          _profile(context, name),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ClubAccountButton extends StatelessWidget {
  const ClubAccountButton({super.key});
  @override
  Widget build(BuildContext context) {
    final account = ClubAccount.instance;
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) => TextButton.icon(
        onPressed: () => showClubAccount(context),
        icon: const Icon(Icons.account_circle_outlined),
        label: Text(account.name == null ? 'Войти' : '${account.coins} мон.'),
      ),
    );
  }
}
