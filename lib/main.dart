import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'engine.dart';
import 'board.dart';
import 'storage.dart';
import 'dice.dart';
import 'arcade_home.dart';
import 'club_account.dart';
import 'online_nardy.dart';

const cream = Color(0xFFF2E3C5),
    amber = Color(0xFFE3B56E),
    dark = Color(0xFF211A16);
void main() {
  runApp(const NardyApp());
  unawaited(ClubAccount.instance.restore());
}

class NardyApp extends StatelessWidget {
  const NardyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Нарды • Клуб',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: amber,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Segoe UI',
      useMaterial3: true,
    ),
    home: const ArcadeHome(),
  );
}

class ClubHome extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() load;
  final Future<void> Function(Map<String, dynamic>) save;
  const ClubHome({super.key, this.load = loadBank, this.save = saveBank});
  @override
  State<ClubHome> createState() => _ClubHomeState();
}

class _ClubHomeState extends State<ClubHome> {
  int bank = 1000,
      friendBank = 1000,
      stake = 50,
      level = 1,
      wins = 0,
      losses = 0;
  bool local = false, loading = true;
  String page = 'home', notice = '';
  Future<void> writes = Future.value();
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    final d = await widget.load();
    if (!mounted) return;
    setState(() {
      bank = (d['bank'] as int?) ?? 1000;
      friendBank = (d['friendBank'] as int?) ?? 1000;
      wins = (d['wins'] as int?) ?? 0;
      losses = (d['losses'] as int?) ?? 0;
      if (d['pending'] == true) {
        if (d['local'] == true) friendBank += 2 * ((d['stake'] as int?) ?? 50);
        losses++;
        notice =
            'Прошлая незавершённая партия засчитана как поражение светлых.';
      }
      loading = false;
    });
    persist();
  }

  Future<void> persist({bool pending = false}) {
    final data = <String, dynamic>{
      'bank': bank,
      'friendBank': friendBank,
      'wins': wins,
      'losses': losses,
      'pending': pending,
      'local': local,
      'stake': stake,
    };
    writes = writes.catchError((Object _) {}).then((_) => widget.save(data));
    return writes;
  }

  Future<void> start() async {
    if (bank < stake || (local && friendBank < stake)) return;
    setState(() {
      loading = true;
      bank -= stake;
      if (local) friendBank -= stake;
    });
    try {
      await persist(pending: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        bank += stake;
        if (local) friendBank += stake;
        loading = false;
        notice = 'Не удалось сохранить банк. Проверьте доступ к хранилищу.';
      });
      return;
    }
    if (!mounted) return;
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(local: local, level: level, stake: stake),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (result == 1) {
        bank += stake * 2;
        wins++;
      } else {
        if (local) friendBank += stake * 2;
        losses++;
      }
      loading = false;
      page = 'home';
      notice = result == 1
          ? 'Светлые победили! +$stake очков к банку.'
          : 'Тёмные победили. Светлые потеряли $stake очков.';
    });
    await persist();
  }

  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF30251F),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: amber.withValues(alpha: .22)),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 12)),
      ],
    ),
    child: child,
  );
  Widget menuButton(
    String title,
    String sub,
    IconData icon,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: const Color(0xFF49362A),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Row(
            children: [
              Icon(icon, color: amber, size: 28),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        color: cream,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: amber),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/background.png'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          colorFilter: ColorFilter.mode(Color(0x88000000), BlendMode.darken),
        ),
      ),
      child: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 660),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            if (page != 'home')
                              IconButton(
                                tooltip: 'Назад',
                                onPressed: () => setState(() => page = 'home'),
                                icon: const Icon(Icons.arrow_back),
                              ),
                            const Icon(Icons.casino_outlined, color: amber),
                            const SizedBox(width: 10),
                            const Text(
                              'НАРДЫ / КЛУБ',
                              style: TextStyle(letterSpacing: 3, color: cream),
                            ),
                            const Spacer(),
                            const Icon(Icons.toll, color: amber, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '$bank',
                              style: const TextStyle(
                                color: amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        Text(
                          page == 'home'
                              ? 'Время хорошей\nпартии.'
                              : page == 'lobby'
                              ? 'Ваш игровой стол'
                              : 'Правила игры',
                          style: const TextStyle(
                            color: cream,
                            fontSize: 38,
                            height: 1.1,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'КОРОТКИЕ НАРДЫ  •  БЕЗ ИНТЕРНЕТА',
                          style: TextStyle(
                            color: amber,
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (notice.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              notice,
                              style: const TextStyle(color: amber),
                            ),
                          ),
                        if (page == 'home') ...[
                          panel(
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 32,
                                  color: amber,
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Локальные очки',
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                      Text(
                                        '$bank очков',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          color: cream,
                                        ),
                                      ),
                                      Text(
                                        '$wins побед  ·  $losses поражений',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          menuButton(
                            'Играть',
                            'Бот или друг за одним экраном',
                            Icons.play_arrow_rounded,
                            () => setState(() => page = 'lobby'),
                          ),
                          menuButton(
                            'Нарды онлайн',
                            'Создать комнату или войти по коду',
                            Icons.wifi,
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const OnlineNardyPage(),
                              ),
                            ),
                          ),
                          menuButton(
                            'Правила',
                            'Как ходить, снимать и побеждать',
                            Icons.menu_book_outlined,
                            () => setState(() => page = 'rules'),
                          ),
                          const SizedBox(height: 18),
                          const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DiceFace(value: 5, size: 48),
                                SizedBox(width: 14),
                                DiceFace(value: 3, size: 48),
                              ],
                            ),
                          ),
                        ],
                        if (page == 'lobby')
                          panel(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'С кем играем?',
                                  style: TextStyle(fontSize: 22, color: cream),
                                ),
                                const SizedBox(height: 18),
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(
                                      value: false,
                                      label: Text('С ботом'),
                                      icon: Icon(Icons.smart_toy_outlined),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text('С другом'),
                                      icon: Icon(Icons.people_outline),
                                    ),
                                  ],
                                  selected: {local},
                                  onSelectionChanged: (v) =>
                                      setState(() => local = v.first),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  local
                                      ? 'Светлые и тёмные ходят по очереди на одном устройстве.'
                                      : 'Бот играет тёмными. Вы — светлыми.',
                                  style: const TextStyle(color: Colors.white54),
                                ),
                                const SizedBox(height: 20),
                                if (!local)
                                  DropdownButtonFormField<int>(
                                    initialValue: level,
                                    decoration: const InputDecoration(
                                      labelText: 'Сложность бота',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 0,
                                        child: Text('Новичок'),
                                      ),
                                      DropdownMenuItem(
                                        value: 1,
                                        child: Text('Тактик'),
                                      ),
                                      DropdownMenuItem(
                                        value: 2,
                                        child: Text('Стратег'),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => level = v!),
                                  ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Ставка на партию',
                                  style: TextStyle(color: cream, fontSize: 17),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  children: [
                                    for (final v in [25, 50, 100, 250])
                                      ChoiceChip(
                                        label: Text('$v'),
                                        selected: stake == v,
                                        onSelected: (_) =>
                                            setState(() => stake = v),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Победа +$stake / поражение −$stake\n${local ? 'Банк светлых: $bank · тёмных: $friendBank' : 'В банке: $bank'}',
                                  style: const TextStyle(
                                    color: amber,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed:
                                      bank >= stake &&
                                          (!local || friendBank >= stake)
                                      ? start
                                      : null,
                                  icon: const Icon(Icons.casino),
                                  label: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('Начать партию'),
                                  ),
                                ),
                                if (bank < stake ||
                                    (local && friendBank < stake))
                                  const Text(
                                    'Недостаточно очков. Выберите меньшую ставку.',
                                    style: TextStyle(color: amber),
                                  ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Очки условные, без покупки и вывода. Ставка резервируется при старте. Выход или закрытие игры — поражение светлых.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (page == 'rules')
                          panel(
                            const Text(
                              'Цель — снять все 15 шашек. Светлые идут от 24 к 1, тёмные — от 1 к 24.\n\nПервый бросок определяет начинающего: у кого больше, тот использует обе кости. При равенстве — переброс.\n\nВыберите шашку, затем отмеченный пункт. Две и более чужих шашки закрывают пункт. Одиночная отправляется на бар. Вход с бара обязателен до остальных ходов.\n\nИспользуйте максимум костей; если доступна одна из двух — старшую. Дубль даёт четыре хода. Снять шашки можно, собрав их в доме. Выберите шашку и нажмите «Снять».\n\nКаждый участник ставит одинаковое число очков. Победитель забирает банк партии. В игре с ботом его ставку предоставляет игра. Марс и куб удвоения не умножают ставку.\n\nВ режиме с другом передавайте устройство после смены хода. Выход из партии считается поражением светлых.',
                              style: TextStyle(height: 1.7, color: cream),
                            ),
                          ),
                        const SizedBox(height: 32),
                        const Center(
                          child: Text(
                            'БРОСАЙТЕ КОСТИ. ВЫБИРАЙТЕ СВОЙ ХОД.',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 2,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}

class GamePage extends StatefulWidget {
  final bool local;
  final int level, stake;
  const GamePage({
    super.key,
    this.local = false,
    this.level = 1,
    this.stake = 50,
  });
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  final rng = Random();
  Position p = Position.initial();
  Position? beforeMove;
  Move? moving;
  int movingSide = 1;
  late final AnimationController checkerAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  Future<void> moveChecker(int side, Move move) async {
    setState(() {
      beforeMove = p;
      moving = move;
      movingSide = side;
      selected = null;
      p = p.play(side, move);
    });
    try {
      await checkerAnimation.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) {
      setState(() {
        moving = null;
        beforeMove = null;
      });
    }
  }

  List<int> dice = [], rolled = [1, 1];
  int turn = 1;
  int? selected;
  bool busy = false, started = false, settled = false, rolling = false;
  String message = 'Бросьте кости — определим первый ход';
  final history = <String>[];
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  List<Move> get legal => dice.isEmpty
      ? []
      : p
            .sequences(turn, dice)
            .where((s) => s.isNotEmpty)
            .map((s) => s.first)
            .toList();
  bool get won => p.off.contains(15);
  String name(int side) => side == 1
      ? (widget.local ? 'Светлые' : 'Вы')
      : (widget.local ? 'Тёмные' : 'Бот');
  String label(int i) => i == -1
      ? 'бар'
      : i == 24
      ? 'дом'
      : '${i + 1}';
  @override
  void dispose() {
    checkerAnimation.dispose();
    animation.dispose();
    super.dispose();
  }

  void log(String s) {
    history.insert(0, s);
    if (history.length > 12) history.removeLast();
  }

  Future<void> shake() async {
    setState(() => rolling = true);
    animation.forward(from: 0);
    for (var i = 0; i < 9; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 90));
      if (!mounted) return;
      setState(() => rolled = [rng.nextInt(6) + 1, rng.nextInt(6) + 1]);
    }
    if (mounted) setState(() => rolling = false);
  }

  Future<void> roll() async {
    if (busy || won || dice.isNotEmpty) return;
    setState(() => busy = true);
    await shake();
    if (!mounted) return;
    if (!started) {
      while (rolled[0] == rolled[1]) {
        setState(() => message = 'Поровну! Повторный бросок');
        await shake();
        if (!mounted) return;
      }
      turn = rolled[0] > rolled[1] ? 1 : -1;
      started = true;
      dice = [...rolled];
      log('Первый ход: ${name(turn)}');
    } else {
      dice = rolled[0] == rolled[1] ? List.filled(4, rolled[0]) : [...rolled];
    }
    setState(() {
      busy = false;
      message = '${name(turn)}: выберите шашку';
      log('${name(turn)}: ${rolled.join(' · ')}');
    });
    if (!widget.local && turn == -1) {
      bot(opening: true);
    } else {
      endTurn();
    }
  }

  void finish() {
    if (settled) return;
    settled = true;
    final winner = p.off[0] == 15 ? 1 : -1;
    setState(() {
      dice = [];
      message = '${name(winner)} побеждают!';
    });
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.emoji_events, color: amber, size: 52),
          title: Text('${name(winner)} — победа!'),
          content: Text(
            'Банк партии: ${widget.stake * 2} очков\n${winner == 1 ? 'Светлые' : 'Тёмные'} получают +${widget.stake} к исходному банку.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.pop(context, winner);
              },
              child: const Text('В главное меню'),
            ),
          ],
        ),
      ),
    );
  }

  void endTurn() {
    if (won) {
      finish();
      return;
    }
    if (dice.isNotEmpty && legal.isNotEmpty) return;
    final blocked = dice.isNotEmpty;
    setState(() {
      dice = [];
      selected = null;
      turn = -turn;
      message = '${blocked ? 'Нет ходов. ' : ''}${name(turn)}: бросайте кости';
    });
    if (!widget.local && turn == -1) bot();
  }

  Future<void> bot({bool opening = false}) async {
    setState(() {
      busy = true;
      message = 'Бот обдумывает ход…';
    });
    if (!opening) {
      await shake();
      if (!mounted) return;
      setState(() {
        dice = rolled[0] == rolled[1] ? List.filled(4, rolled[0]) : [...rolled];
        log('Бот: ${rolled.join(' · ')}');
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final path = LocalBot(rng).choose(p, -1, dice, widget.level);
    for (final m in path) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await moveChecker(-1, m);
      if (!mounted) return;
      setState(() {
        dice.remove(m.die);
        log('Бот: ${label(m.from)} → ${label(m.to)}');
      });
    }
    if (!mounted) return;
    setState(() => busy = false);
    dice = [];
    endTurn();
  }

  Future<void> tap(int point) async {
    if (busy || moving != null || won || (!widget.local && turn == -1)) return;
    final moves = legal
        .where((m) => m.from == selected && m.to == point)
        .toList();
    if (moves.isNotEmpty) {
      final m = moves.first;
      await moveChecker(turn, m);
      if (!mounted) return;
      setState(() {
        dice.remove(m.die);
        selected = null;
        log('${name(turn)}: ${label(m.from)} → ${label(m.to)}');
      });
      endTurn();
    } else if (legal.any((m) => m.from == point)) {
      setState(() => selected = point);
    }
  }

  Future<void> leave() async {
    if (settled) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Завершить партию?'),
        content: Text(
          'Светлые потеряют ${widget.stake} очков.${widget.local ? ' Банк партии получат тёмные.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Продолжить'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Сдаться'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      Navigator.pop(context, -1);
    }
  }

  Widget player(int side, {bool compact = false}) => Container(
    padding: EdgeInsets.all(compact ? 10 : 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: turn == side
            ? [const Color(0xFF60452D), const Color(0xFF35271E)]
            : [const Color(0xFF302923), const Color(0xFF241F1B)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: turn == side ? amber : Colors.white12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: compact ? 15 : 20,
          backgroundColor: side == 1 ? cream : const Color(0xFF24272A),
          child: Icon(
            side == -1 && !widget.local
                ? Icons.smart_toy_outlined
                : Icons.person,
            size: compact ? 18 : 24,
            color: side == 1 ? dark : cream,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name(side),
                style: const TextStyle(
                  color: cream,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${p.pip(side)} пипс · ${p.off[side == 1 ? 0 : 1]}/15',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        if (turn == side) const Icon(Icons.circle, color: amber, size: 8),
      ],
    ),
  );
  Widget controls({bool compact = false}) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 6,
    children: [
      FilledButton.icon(
        onPressed: busy || won || dice.isNotEmpty ? null : roll,
        icon: const Icon(Icons.casino_outlined),
        label: Text(!started ? 'Первый бросок' : 'Бросить'),
      ),
      OutlinedButton(
        onPressed: !busy && legal.any((m) => m.from == selected && m.to == 24)
            ? () => tap(24)
            : null,
        child: const Text('Снять'),
      ),
      IconButton(
        tooltip: 'Подсказка',
        onPressed: !busy && moving == null && legal.isNotEmpty
            ? () {
                final m = LocalBot(rng).choose(p, turn, dice, 2).first;
                setState(() {
                  selected = m.from;
                  message = 'Совет: ${label(m.from)} → ${label(m.to)}';
                });
              }
            : null,
        icon: const Icon(Icons.lightbulb_outline, color: amber),
      ),
      IconButton(
        tooltip: 'Ходы',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Последние ходы'),
            content: Text(
              history.isEmpty
                  ? 'Партия только начинается'
                  : history.take(10).join('\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.history, color: amber),
      ),
    ],
  );
  Widget board() => LayoutBuilder(
    builder: (context, b) {
      final targets = legal
          .where((m) => m.from == selected)
          .map((m) => m.to)
          .toSet();
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: GestureDetector(
                  onTapUp: (e) {
                    final i = BoardPainter.hit(e.localPosition, b.biggest);
                    if (i != null) tap(i);
                  },
                  child: AnimatedBuilder(
                    animation: checkerAnimation,
                    builder: (context, _) => CustomPaint(
                      painter: BoardPainter(
                        p,
                        selected,
                        moving == null ? targets : {},
                        player: turn,
                        before: beforeMove,
                        move: moving,
                        movingSide: movingSide,
                        progress: checkerAnimation.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 2; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: Transform.translate(
                        offset: rolling
                            ? Offset(
                                sin(animation.value * pi * 6 + i) * 18,
                                -sin(animation.value * pi) * 28,
                              )
                            : Offset.zero,
                        child: Transform.rotate(
                          angle: rolling
                              ? sin(animation.value * pi * 7 + i) * .7
                              : (i == 0 ? -.1 : .12),
                          child: DiceFace(
                            value: rolled[i],
                            size: min(49, b.maxWidth * .075).toDouble(),
                            dark: i == 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave();
    },
    child: Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            colorFilter: ColorFilter.mode(Color(0x88000000), BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final landscape = c.maxWidth > c.maxHeight;
              if (landscape) {
                final boardWidth = min(
                  c.maxWidth - 300,
                  (c.maxHeight - 20) * 1.42,
                ).toDouble();
                return Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'В меню',
                                  onPressed: leave,
                                  icon: const Icon(Icons.arrow_back),
                                ),
                                const Text(
                                  'НАРДЫ',
                                  style: TextStyle(color: cream, fontSize: 12),
                                ),
                              ],
                            ),
                            player(-1, compact: true),
                            Text(
                              'Банк: ${widget.stake * 2}',
                              style: const TextStyle(color: amber),
                            ),
                            player(1, compact: true),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: boardWidth,
                          height: boardWidth / 1.42,
                          child: board(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: amber,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            controls(compact: true),
                            const SizedBox(height: 12),
                            Text(
                              dice.isEmpty
                                  ? 'Ставка: ${widget.stake}'
                                  : 'Осталось ходов: ${dice.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              final width = min(c.maxWidth - 24, 520.0),
                  height = min(width / 1.12, c.maxHeight * .49);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'В меню',
                          onPressed: leave,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Text(
                          'НАРДЫ',
                          style: TextStyle(color: cream, letterSpacing: 3),
                        ),
                        const Spacer(),
                        const Icon(Icons.toll, size: 16, color: amber),
                        Text(
                          ' ${widget.stake * 2}',
                          style: const TextStyle(color: amber),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: player(-1, compact: true),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: board(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: player(1, compact: true),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: amber, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dice.isEmpty
                        ? 'Ставка: ${widget.stake} очков'
                        : 'Осталось ходов: ${dice.length}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const Spacer(),
                  controls(),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
