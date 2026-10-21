import 'package:flutter/material.dart';

import '../ads/ad_service.dart';

/// Placeholder settings hook (M3): drop into the settings screen. Visible
/// only when UMP requires a privacy-options entry point; tapping re-opens
/// the consent / privacy options form. [label] comes from l10n.
class PrivacyOptionsEntry extends StatelessWidget {
  const PrivacyOptionsEntry({super.key, required this.ads, required this.label});
  final AdService ads;
  final String label;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: ads.privacyOptionsRequired,
        builder: (context, required, _) => !required
            ? const SizedBox.shrink()
            : ListTile(
                key: const Key('privacyOptions'),
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(label),
                onTap: ads.showPrivacyOptions,
              ),
      );
}
