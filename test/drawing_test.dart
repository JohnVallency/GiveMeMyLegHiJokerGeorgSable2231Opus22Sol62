import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nardy/arcade_home.dart';
import 'package:nardy/drawing_page.dart';

void main() {
  testWidgets('Eraser size is independent and clearing is reversible', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DrawingPage()));
    await tester.tap(find.byTooltip('Фон'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Мятный'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFFD8F2E9),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Толщина кисти'));
    await tester.pumpAndSettle();
    final slider = find.byType(Slider);
    tester.widget<Slider>(slider).onChanged!(12);
    Navigator.of(tester.element(slider)).pop();
    await tester.pumpAndSettle();

    final canvas = find.byKey(const ValueKey('drawing-canvas'));
    await tester.drag(canvas, const Offset(70, 30));
    await tester.tap(find.byTooltip('Ластик'));
    await tester.pump();
    await tester.tap(find.byTooltip('Толщина ластика'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value, 24);
    Navigator.of(tester.element(slider)).pop();
    await tester.pumpAndSettle();
    await tester.drag(canvas, const Offset(15, 30));
    await tester.pump();

    final clear = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Очистить холст',
    );
    await tester.tap(clear);
    await tester.pump();
    expect(tester.widget<IconButton>(clear).onPressed, isNull);
    await tester.tap(find.byTooltip('Отменить'));
    await tester.pump();
    expect(tester.widget<IconButton>(clear).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Drawing mode accepts stamp taps and drags from the menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ArcadeHome()));
    final mode = find.text('Рисовалка Не пенисов');
    await tester.ensureVisible(mode);
    await tester.tap(mode);
    await tester.pumpAndSettle();

    final canvas = find.byKey(const ValueKey('drawing-canvas'));
    final center = tester.getCenter(canvas);
    expect(tester.getSize(canvas).height, greaterThan(450));
    for (final label in [
      'Кисть',
      'Ластик',
      'Цвет',
      'Фон',
      'Толщина',
      'Очистить',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Цвет'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Красный'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Фигура пениса'));
    await tester.pump();
    await tester.tapAt(center);
    await tester.dragFrom(center, const Offset(50, -100));
    await tester.pump();

    final undo = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Отменить',
    );
    for (var i = 0; i < 2; i++) {
      expect(tester.widget<IconButton>(undo).onPressed, isNotNull);
      await tester.tap(undo);
      await tester.pump();
    }
    expect(tester.widget<IconButton>(undo).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
