import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

@JS('document.createElement')
external JSObject createElement(JSString tag);

@JS()
extension type ChessFrame(JSObject _) implements JSObject {
  external set src(JSString v);
  external void setAttribute(JSString name, JSString value);
}

bool registered = false;
Future<void> openChess(BuildContext context) async {
  if (!registered) {
    ui.platformViewRegistry.registerViewFactory('chess2-game', (_) {
      final frame = ChessFrame(createElement('iframe'.toJS));
      frame.src = 'assets/assets/chess2/index.html'.toJS;
      frame.setAttribute(
        'style'.toJS,
        'width:100%;height:100%;border:0;background:#101c1b'.toJS,
      );
      frame.setAttribute('title'.toJS, 'Шахматы 2'.toJS);
      return frame;
    });
    registered = true;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Шахматы 2'),
          leading: IconButton(
            tooltip: 'Все игры',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const HtmlElementView(viewType: 'chess2-game'),
      ),
    ),
  );
}
