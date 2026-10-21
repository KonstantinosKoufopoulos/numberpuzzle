import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language choice; [system] follows the device locale.
enum AppLanguage { system, el, en }

/// User settings (wireframe 11), persisted in shared_preferences.
class SettingsController extends ChangeNotifier {
  static const String kLanguage = 'settings_language';
  static const String kTheme = 'settings_theme';
  static const String kSound = 'settings_sound';
  static const String kHaptics = 'settings_haptics';

  AppLanguage language = AppLanguage.system;
  ThemeMode themeMode = ThemeMode.system;
  bool sound = true;
  bool haptics = true;
  bool isLoaded = false;

  /// Locale for MaterialApp; null = system.
  Locale? get locale => switch (language) {
    AppLanguage.system => null,
    AppLanguage.el => const Locale('el'),
    AppLanguage.en => const Locale('en'),
  };

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    language = AppLanguage.values.asNameMap()[p.getString(kLanguage)] ?? AppLanguage.system;
    themeMode = ThemeMode.values.asNameMap()[p.getString(kTheme)] ?? ThemeMode.system;
    sound = p.getBool(kSound) ?? true;
    haptics = p.getBool(kHaptics) ?? true;
    isLoaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage v) async {
    language = v;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(kLanguage, v.name);
  }

  Future<void> setThemeMode(ThemeMode v) async {
    themeMode = v;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(kTheme, v.name);
  }

  Future<void> setSound(bool v) async {
    sound = v;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(kSound, v);
  }

  Future<void> setHaptics(bool v) async {
    haptics = v;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(kHaptics, v);
  }
}

/// Makes the [SettingsController] available below the app.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({super.key, required SettingsController controller, required super.child})
    : super(notifier: controller);

  static SettingsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;

  /// Non-listening lookup (for callbacks).
  static SettingsController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}
