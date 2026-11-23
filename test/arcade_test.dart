import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nardy/arcade_home.dart';
import 'package:nardy/main.dart';

void main() {
  for (final size in [const Size(360, 780), const Size(844, 390)]) {
    testWidgets('Four mode home at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: ArcadeHome()));
      await tester.pumpAndSettle();
      for (final title in [
        'Шутер',
        'Шахматы 2',
        'Нарды',
        'Рисовалка Не пенисов',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Шутер'));
      await tester.tap(find.text('Шутер'));
      await tester.pumpAndSettle();
      expect(
        find.text('Режим в разработке. Здесь скоро появится новая игра.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('На главный экран'));
      await tester.tap(find.text('На главный экран'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Нарды'));
      await tester.tap(find.text('Нарды'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ClubHome), findsOneWidget);
      expect(find.text('Все игры'), findsOneWidget);
      await tester.tap(find.text('Все игры'));
      await tester.pumpAndSettle();
      expect(find.byType(ArcadeHome), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
