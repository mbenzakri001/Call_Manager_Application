import 'package:flutter/material.dart';

import '../config/sip_config.dart';
import '../core/call_rules.dart';
import '../sip/sip_service.dart';
import 'phone_page.dart';

/// Onglet Réglages : connexion au serveur et règles du call manager.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.sip});
  final SipService sip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            secondary: Icon(
              Icons.do_not_disturb_on,
              color: sip.doNotDisturbOn ? Colors.deepPurple : null,
            ),
            title: const Text('Ne pas déranger'),
            subtitle: const Text(
              'Refuse les appels (480), sauf favoris et appels répétés',
            ),
            value: sip.doNotDisturbOn,
            onChanged: (on) => sip.doNotDisturbOn = on,
          ),
        ),
        const SizedBox(height: 24),
        Text('Filtrage des appels', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          "Les règles s'appliquent dans l'ordre : la première règle active "
          "qui correspond à l'appel décide.",
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final (i, rule) in defaultRules.indexed)
                _RuleTile(
                  index: i + 1,
                  rule: rule,
                  enabled: sip.isRuleEnabled(rule),
                  onChanged: (on) => sip.setRuleEnabled(rule, on),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Compte SIP', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ConnectionCard(sip: sip),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.dns),
                title: const Text('Serveur'),
                subtitle: Text(SipConfig.webSocketUrl),
              ),
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('Compte'),
                subtitle: Text('${SipConfig.displayName} (${SipConfig.user})'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.index,
    required this.rule,
    required this.enabled,
    required this.onChanged,
  });

  final int index;
  final CallRule rule;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(radius: 14, child: Text('$index')),
      title: Text(rule.name),
      subtitle: Text(rule.description),
      trailing: rule.canBeDisabled
          ? Switch(value: enabled, onChanged: onChanged)
          : const Tooltip(
              message: 'Toujours active',
              child: Icon(Icons.lock_outline),
            ),
    );
  }
}
