import 'dart:io';
import 'dart:convert';

Future<Map<String, dynamic>> loadBank() async {
  try {
    return jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

File get _file {
  final root = Platform.isAndroid
      ? '${Directory.systemTemp.parent.path}/files'
      : '${Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? Directory.systemTemp.path}/NardyClub';
  return File('$root/bank.json');
}

Future<void> saveBank(Map<String, dynamic> data) async {
  await _file.parent.create(recursive: true);
  await _file.writeAsString(jsonEncode(data), flush: true);
}
