import 'dart:js_interop';
import 'dart:convert';

@JS('localStorage')
external BrowserStorage get browserStorage;

@JS()
extension type BrowserStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
}

Future<Map<String, dynamic>> loadBank() async {
  try {
    return jsonDecode(
      browserStorage.getItem('nardy.bank.v2'.toJS)?.toDart ?? '{}',
    ) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

Future<void> saveBank(Map<String, dynamic> data) async {
  browserStorage.setItem('nardy.bank.v2'.toJS, jsonEncode(data).toJS);
}
