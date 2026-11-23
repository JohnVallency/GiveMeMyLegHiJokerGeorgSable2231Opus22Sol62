import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nardy/club_account.dart';

void main() {
  testWidgets(
    'Account form supports keyboard, validation and switching modes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showClubAccount(context),
                child: const Text('Аккаунт'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Аккаунт'));
      await tester.pumpAndSettle();
      final name = find.byType(TextFormField).first;
      final password = find.byType(TextFormField).last;
      await tester.enterText(name, 'tester');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        true,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Введите пароль'), findsOneWidget);
      await tester.tap(find.text('Регистрация'));
      await tester.pumpAndSettle();
      expect(find.text('tester'), findsOneWidget);
      await tester.enterText(password, 'short');
      await tester.ensureVisible(find.text('Показать'));
      await tester.tap(find.text('Показать'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        false,
      );
      await tester.ensureVisible(find.text('Создать аккаунт'));
      await tester.tap(find.text('Создать аккаунт'));
      await tester.pumpAndSettle();
      expect(
        find.text('Пароль должен содержать 8–128 символов'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
