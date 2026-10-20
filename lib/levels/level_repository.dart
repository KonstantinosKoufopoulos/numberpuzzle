import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../engine/level.dart';

/// Loads the bundled level pack from assets/levels/levels.json.
class LevelRepository {
  static const String assetPath = 'assets/levels/levels.json';

  Future<LevelPack> load() async {
    final s = await rootBundle.loadString(assetPath);
    final pack = LevelPack.fromJson(jsonDecode(s) as Map<String, dynamic>);
    final errors = pack.validate();
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    return pack;
  }
}
