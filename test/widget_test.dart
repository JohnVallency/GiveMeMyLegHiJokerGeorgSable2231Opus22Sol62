import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nardy/engine.dart';
import 'package:nardy/board.dart';
import 'package:nardy/main.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets('Local play and layout at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const RepaintBoundary(
          key: ValueKey('screen'),
          child: MaterialApp(home: GamePage(local: true)),
        ),
      );
      expect(find.text('Светлые'), findsOneWidget);
      expect(find.text('Тёмные'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Первый бросок'));
      for (var i = 0; i < 35; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Первый бросок'), findsNothing);
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('screen')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('previews').create(recursive: true);
        await File('previews/game_${size.width.toInt()}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
      final dynamic state = tester.state(find.byType(GamePage));
      final before = state.turn;
      while (state.turn == before) {
        final choices = state.legal as List<Move>;
        if (choices.isEmpty) break;
        state.tap(choices.first.from);
        final beforePosition = state.p;
        state.tap(choices.first.to);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(state.moving, isNotNull);
        expect(identical(state.beforeMove, beforePosition), true);
        final during = state.p;
        state.tap(choices.first.from);
        state.tap(choices.first.to);
        expect(identical(state.p, during), true);
        await tester.pumpAndSettle();
        expect(state.moving, isNull);
      }
      expect(state.turn, -before);
      if (size.width == 390) {
        final position = state.p;
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        expect(identical(tester.state(find.byType(GamePage)), state), true);
        expect(identical(state.p, position), true);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final winner in [1, -1]) {
    testWidgets('Local stake and payout for winner $winner', (tester) async {
      Map<String, dynamic> saved = {};
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ClubHome(
            load: () async => {'bank': 1000, 'friendBank': 1000},
            save: (d) async {
              saved = {...d};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Играть'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('С другом'));
      await tester.tap(find.text('С другом'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Начать партию'));
      await tester.tap(find.text('Начать партию'));
      await tester.pumpAndSettle();
      expect(saved['bank'], 950);
      expect(saved['friendBank'], 950);
      expect(saved['pending'], true);
      final dynamic state = tester.state(find.byType(GamePage));
      state.p = Position(List.filled(24, 0), [
        0,
        0,
      ], winner == 1 ? [15, 0] : [0, 15]);
      state.endTurn();
      await tester.pumpAndSettle();
      await tester.tap(find.text('В главное меню'));
      await tester.pumpAndSettle();
      expect(saved['bank'], winner == 1 ? 1050 : 950);
      expect(saved['friendBank'], winner == 1 ? 950 : 1050);
      expect(saved['pending'], false);
      expect(find.text('Сбросить количество очков'), findsNothing);
    });
  }
  testWidgets('Unfinished local game settles only once on reload', (
    tester,
  ) async {
    Map<String, dynamic> saved = {
      'bank': 950,
      'friendBank': 950,
      'stake': 50,
      'local': true,
      'pending': true,
    };
    Future<Map<String, dynamic>> load() async => {...saved};
    Future<void> save(Map<String, dynamic> data) async {
      saved = {...data};
    }

    await tester.pumpWidget(
      MaterialApp(
        home: ClubHome(load: load, save: save),
      ),
    );
    await tester.pumpAndSettle();
    expect(saved['bank'], 950);
    expect(saved['friendBank'], 1050);
    expect(saved['losses'], 1);
    expect(saved['pending'], false);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: ClubHome(load: load, save: save),
      ),
    );
    await tester.pumpAndSettle();
    expect(saved['friendBank'], 1050);
    expect(saved['losses'], 1);
  });
  for (final kind in ['capture', 'bar', 'off']) {
    testWidgets('Checker animation supports $kind', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GamePage(local: true)));
      final dynamic state = tester.state(find.byType(GamePage));
      final points = List.filled(24, 0);
      final from = kind == 'bar'
          ? -1
          : kind == 'off'
          ? 2
          : 6;
      final to = kind == 'bar'
          ? 21
          : kind == 'off'
          ? 24
          : 3;
      if (kind == 'capture') {
        points[6] = 1;
        points[3] = -1;
      }
      if (kind == 'off') {
        points[2] = 2;
      }
      state.p = Position(
        points,
        kind == 'bar' ? [1, 0] : [0, 0],
        kind == 'off' ? [13, 0] : [0, 0],
      );
      state.turn = 1;
      state.dice = [3];
      state.tap(from);
      await tester.pump();
      state.tap(to);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.moving, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(state.moving, isNull);
      expect(tester.takeException(), isNull);
      if (kind == 'capture') expect(state.p.bar[1], 1);
      if (kind == 'bar') expect(state.p.points[21], 1);
      if (kind == 'off') expect(state.p.off[0], 14);
    });
  }
  test('Ghosts occupy actual empty and stacked checker slots', () {
    final p = Position.initial();
    for (final size in [const Size(390, 330), const Size(520, 366)]) {
      final white = BoardPainter(p, 5, {4, 5}, player: 1);
      expect(white.ghostCenter(4, size), BoardPainter.slot(4, size, 0, 1));
      expect(white.ghostCenter(5, size), BoardPainter.slot(5, size, 5, 6));
      expect(
        white.ghostCenter(4, size).dy,
        greaterThan(BoardPainter.cell(4, size).center.dy),
      );
      final black = BoardPainter(p, 18, {19}, player: -1);
      expect(
        black.ghostCenter(19, size).dy,
        lessThan(BoardPainter.cell(19, size).center.dy),
      );
    }
  });
  test('Initial position has 15 checkers per player and 167 pips', () {
    final p = Position.initial();
    expect(p.pip(1), 167);
    expect(p.pip(-1), 167);
    expect(p.points.where((x) => x > 0).fold(0, (a, b) => a + b), 15);
  });
  test('Bar entry is mandatory and blocked by two opponents', () {
    final p = Position(List.filled(24, 0), [1, 0], [0, 0]);
    p.points[23] = -2;
    p.points[5] = 14;
    expect(p.moves(1, 1), isEmpty);
    expect(p.moves(1, 2).single.from, -1);
  });
  test('Hitting sends a checker to the bar', () {
    final p = Position(List.filled(24, 0), [0, 0], [0, 0]);
    p.points[6] = 1;
    p.points[3] = -1;
    final next = p.play(1, const Move(6, 3, 3));
    expect(next.bar[1], 1);
    expect(next.points[3], 1);
  });
  test('Oversized bearing off only allowed for farthest checker', () {
    final p = Position(List.filled(24, 0), [0, 0], [13, 0]);
    p.points[0] = 1;
    p.points[3] = 1;
    expect(p.moves(1, 6).map((m) => m.from), [3]);
  });
  test('Must play higher die when only one can be used', () {
    final p = Position(List.filled(24, 0), [0, 0], [14, 0]);
    p.points[0] = 1;
    expect(p.sequences(1, [1, 6]).single.single.die, 6);
  });
  test('A complete bot game preserves checkers and terminates', () {
    var p = Position.initial();
    final rng = Random(42);
    final bot = LocalBot(rng);
    var player = 1;
    for (var turn = 0; turn < 1500 && !p.off.contains(15); turn++) {
      final a = rng.nextInt(6) + 1, b = rng.nextInt(6) + 1;
      final dice = a == b ? [a, a, a, a] : [a, b];
      for (final m in bot.choose(p, player, dice, 1)) {
        p = p.play(player, m);
      }
      for (final side in [1, -1]) {
        expect(
          p.points.where((v) => v * side > 0).fold(0, (a, b) => a + b.abs()) +
              p.bar[p.index(side)] +
              p.off[p.index(side)],
          15,
        );
      }
      player = -player;
    }
    expect(p.off.contains(15), true);
  });
}
