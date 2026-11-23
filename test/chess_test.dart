import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nardy/arcade_home.dart';

void main() {
  testWidgets('Chess card opens native game channel', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var calls = 0;
    const channel = MethodChannel('club/chess2');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'open');
      calls++;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: ArcadeHome()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Шахматы 2'));
    await tester.tap(find.text('Шахматы 2'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
      find.text('Режим в разработке. Здесь скоро появится новая игра.'),
      findsNothing,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
