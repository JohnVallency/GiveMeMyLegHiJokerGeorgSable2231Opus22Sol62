import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'club_account.dart';

Future<void> openChess(BuildContext context) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Шахматы 2 доступны в Android-приложении и веб-предпросмотре.',
        ),
      ),
    );
    return;
  }
  try {
    final account = ClubAccount.instance;
    final base = Uri.tryParse(ClubAccount.base);
    Map<String, String>? entry;
    if (account.name != null && base?.scheme == 'https') {
      final ticket = await account.chessTicket();
      if (!context.mounted) return;
      entry = {'origin': base!.origin, 'ticket': ticket};
    }
    await const MethodChannel('club/chess2').invokeMethod<void>('open', entry);
  } on ClubError catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  } on PlatformException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть Шахматы 2. Попробуйте ещё раз.'),
        ),
      );
    }
  }
}
