import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../l10n/app_localizations.dart';
import '../settings/settings_controller.dart';
import '../storage/game_save_store.dart';
import 'privacy_options_entry.dart';
import 'theme.dart';
import 'tokens.dart';

/// Settings (wireframe 11): language, theme, sound, haptics, tutorial replay.
/// Privacy & ads (UMP options, m3-ads) is last; export/import is m3-ads work.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings, this.ads, this.saves});

  final SettingsController settings;
  final GameSaveStore? saves;

  /// For the UMP privacy-options entry (shown only when UMP requires it).
  final AdService? ads;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(t.settingsTitle), centerTitle: true),
        body: ListView(
          padding: const EdgeInsets.all(Tk.l),
          children: [
            _Row(
              title: t.settingsLanguage,
              child: SegmentedButton<AppLanguage>(
                key: const Key('settingsLanguage'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: AppLanguage.el, label: Text(t.languageGreek)),
                  ButtonSegment(value: AppLanguage.en, label: Text(t.languageEnglish)),
                  ButtonSegment(value: AppLanguage.system, label: Text(t.optionSystem)),
                ],
                selected: {settings.language},
                onSelectionChanged: (s) => settings.setLanguage(s.first),
              ),
            ),
            _Row(
              title: t.settingsTheme,
              child: SegmentedButton<ThemeMode>(
                key: const Key('settingsTheme'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: ThemeMode.light, label: Text(t.themeLight)),
                  ButtonSegment(value: ThemeMode.dark, label: Text(t.themeDark)),
                  ButtonSegment(value: ThemeMode.system, label: Text(t.optionSystem)),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => settings.setThemeMode(s.first),
              ),
            ),
            _Row(
              title: t.settingsSound,
              child: Switch(key: const Key('settingsSound'), value: settings.sound, onChanged: settings.setSound),
            ),
            _Row(
              title: t.settingsHaptics,
              child: Switch(key: const Key('settingsHaptics'), value: settings.haptics, onChanged: settings.setHaptics),
            ),
            _Row(
              title: t.settingsTutorial,
              child: TextButton(
                key: const Key('settingsTutorial'),
                onPressed: () async {
                  await (saves ?? GameSaveStore()).resetTutorial();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.settingsTutorialDone)));
                  }
                },
                child: Text('${t.settingsTutorialReplay} →'),
              ),
            ),
            if (ads != null) PrivacyOptionsEntry(ads: ads!, label: t.settingsPrivacy),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.extension<GamePalette>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: Tk.m),
      padding: const EdgeInsets.symmetric(horizontal: Tk.l, vertical: Tk.m),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Tk.rCard),
        border: Border.all(color: ink.cellBorder, width: 1.5),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: Tk.s,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          child,
        ],
      ),
    );
  }
}
