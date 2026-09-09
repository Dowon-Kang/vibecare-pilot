import 'dart:convert';
import 'dart:io';
import 'package:vibecare_pilot/algorithm/adaptive_protocol.dart';

Future<void> main() async {
  final input = jsonDecode(await stdin.transform(utf8.decoder).join()) as List;
  stdout.write(jsonEncode(input.map(selectAdaptiveProtocol).toList()));
}
