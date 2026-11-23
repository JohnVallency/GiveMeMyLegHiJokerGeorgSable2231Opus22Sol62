import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'board.dart';
import 'club_account.dart';
import 'dice.dart';
import 'engine.dart';

class OnlineNardyPage extends StatefulWidget {
  const OnlineNardyPage({super.key});
  @override
  State<OnlineNardyPage> createState() => _OnlineNardyPageState();
}

class _OnlineNardyPageState extends State<OnlineNardyPage> {
  final account = ClubAccount.instance;
  final code = TextEditingController();
  Map<String, dynamic>? room;
  Timer? poll;
  bool busy = false;
  bool refreshing = false;
  int? selected;
  String? error;

  @override
  void dispose() {
    poll?.cancel();
    code.dispose();
    super.dispose();
  }

  Future<void> _request(String path, Map<String, dynamic> data) async {
    if (busy) return;
    if (account.name == null) {
      await showClubAccount(context);
      if (!mounted || account.name == null) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await account.request(path, data);
      if (!mounted) return;
      _update(result);
      poll ??= Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    } on ClubError catch (failure) {
      if (mounted) setState(() => error = failure.message);
      if (failure.status == 409) unawaited(_refresh(force: true));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _refresh({bool force = false}) async {
    final id = room?['code'];
    if (id == null || refreshing || (!force && busy)) return;
    refreshing = true;
    try {
      final result = await account.request('rooms/$id');
      if (mounted && room?['code'] == id) {
        _update(result);
        if (error != null) setState(() => error = null);
      }
    } on ClubError catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } finally {
      refreshing = false;
    }
  }

  void _update(Map<String, dynamic> result) {
    final current = room;
    if (current != null &&
        (result['revision'] as int) <= (current['revision'] as int)) {
      return;
    }
    setState(() {
      room = result;
      selected = null;
    });
  }

  void _send(Map<String, dynamic> move) => unawaited(
    _request('rooms/${room!['code']}/move', {
      ...move,
      'revision': room!['revision'],
    }),
  );

  @override
  Widget build(BuildContext context) {
    final match = room;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Нарды онлайн'),
        actions: const [ClubAccountButton()],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final width = math.min(box.maxWidth - 24, 640.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (match == null) ...[
                        const Text(
                          'У каждого игрока должен быть свой общий аккаунт.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => _request('rooms', {'game': 'nardy'}),
                          child: const Text('Создать комнату'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: code,
                          decoration: const InputDecoration(
                            labelText: 'Код комнаты',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () {
                                  final id = code.text.trim().toLowerCase();
                                  if (!RegExp(r'^[a-f0-9]{8}$').hasMatch(id)) {
                                    setState(
                                      () => error =
                                          'Введите код из восьми символов.',
                                    );
                                    return;
                                  }
                                  _request('rooms/$id/join', {'game': 'nardy'});
                                },
                          child: const Text('Войти в комнату'),
                        ),
                      ] else
                        ..._board(match),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(error!),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _board(Map<String, dynamic> match) {
    final raw = match['position'] as Map<String, dynamic>;
    final position = Position(
      List<int>.from(raw['points']),
      List<int>.from(raw['bar']),
      List<int>.from(raw['off']),
    );
    final side = match['color'] == 0 ? 1 : -1;
    final canPlay = match['playable'] == true && !busy;
    final moves = List<Map<String, dynamic>>.from(match['actions']);
    final targets = moves
        .where((move) => move['from'] == selected)
        .map((move) => move['to'] as int)
        .toSet();
    final ending = match['ending'] as List?;
    final dice = match['dice'] as List;
    return [
      Row(
        children: [
          Expanded(child: SelectableText('Код комнаты  ${match['code']}')),
          IconButton(
            tooltip: 'Копировать код',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: match['code'] as String),
              );
            },
          ),
        ],
      ),
      Text(
        ending?.first.toString() ??
            (match['ready'] != true
                ? 'Ждём соперника'
                : canPlay
                ? 'Ваш ход · ${side == 1 ? 'светлые' : 'тёмные'}'
                : 'Ход соперника'),
      ),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: 1.42,
        child: LayoutBuilder(
          builder: (context, box) => GestureDetector(
            onTapUp: canPlay
                ? (event) {
                    final point = BoardPainter.hit(
                      event.localPosition,
                      box.biggest,
                    );
                    if (targets.contains(point)) {
                      _send(
                        moves.firstWhere(
                          (move) =>
                              move['from'] == selected && move['to'] == point,
                        ),
                      );
                    } else {
                      setState(
                        () => selected =
                            moves.any((move) => move['from'] == point)
                            ? point
                            : null,
                      );
                    }
                  }
                : null,
            child: CustomPaint(
              painter: BoardPainter(position, selected, targets, player: side),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          for (final value in match['rolled'] as List)
            DiceFace(value: value as int, size: 30),
          if (dice.isNotEmpty) Text('Осталось ${dice.join(' · ')}'),
          FilledButton(
            onPressed: canPlay && dice.isEmpty
                ? () => _send({'action': 'roll'})
                : null,
            child: const Text('Бросить кости'),
          ),
          OutlinedButton(
            onPressed: canPlay && targets.contains(24)
                ? () => _send(
                    moves.firstWhere(
                      (move) => move['from'] == selected && move['to'] == 24,
                    ),
                  )
                : null,
            child: const Text('Снять шашку'),
          ),
        ],
      ),
    ];
  }
}
