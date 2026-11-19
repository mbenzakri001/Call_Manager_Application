import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';

import '../config/sip_config.dart';
import '../sip/sip_service.dart';

/// Onglet Téléphone : clavier numérique pour passer un appel.
class PhonePage extends StatefulWidget {
  const PhonePage({super.key, required this.sip});
  final SipService sip;

  @override
  State<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends State<PhonePage> {
  String _number = '';

  void _press(String key) => setState(() => _number += key);

  void _erase() {
    if (_number.isEmpty) return;
    setState(() => _number = _number.substring(0, _number.length - 1));
  }

  void _call() {
    if (_number.isEmpty || !widget.sip.isRegistered) return;
    widget.sip.call(_number);
  }

  @override
  Widget build(BuildContext context) {
    final sip = widget.sip;
    final theme = Theme.of(context);
    final contactName = _number.isEmpty ? null : sip.contactNameFor(_number);

    return SafeArea(
      child: Column(
        children: [
          if (!sip.isRegistered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ConnectionCard(sip: sip),
            ),
          // Le clavier rétrécit si l'écran manque de place (grande police,
          // bandeau de connexion affiché…) au lieu de déborder.
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _number.isEmpty ? 'Composez un numéro' : _number,
                      style: _number.isEmpty
                          ? theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            )
                          : theme.textTheme.displaySmall,
                    ),
                    SizedBox(
                      height: 24,
                      child: contactName == null
                          ? (_number == '600'
                                ? const Text("Test d'écho")
                                : null)
                          : Text(
                              contactName,
                              style: theme.textTheme.titleMedium,
                            ),
                    ),
                    const SizedBox(height: 16),
                    for (final row in const [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['*', '0', '#'],
                    ])
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final key in row)
                            _Key(label: key, onTap: () => _press(key)),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 88),
                        FilledButton(
                          onPressed: sip.isRegistered && _number.isNotEmpty
                              ? _call
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(22),
                          ),
                          child: const Icon(Icons.call, size: 32),
                        ),
                        SizedBox(
                          width: 88,
                          child: _number.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Effacer',
                                  onPressed: _erase,
                                  icon: const Icon(Icons.backspace_outlined),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
          ),
          child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
        ),
      ),
    );
  }
}

/// Carte d'état de la connexion au serveur Asterisk.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({super.key, required this.sip});
  final SipService sip;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title) = switch ((
      sip.registrationState,
      sip.transportState,
    )) {
      (RegistrationStateEnum.REGISTERED, _) => (
        Icons.check_circle,
        Colors.green,
        'Connecté — prêt à recevoir des appels',
      ),
      (RegistrationStateEnum.REGISTRATION_FAILED, _) => (
        Icons.error,
        Colors.red,
        "Échec de l'enregistrement",
      ),
      (_, TransportStateEnum.DISCONNECTED) => (
        Icons.cloud_off,
        Colors.red,
        'Serveur injoignable',
      ),
      _ => (Icons.sync, Colors.orange, 'Connexion au serveur…'),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title),
        subtitle: Text(
          '${SipConfig.displayName} · ${SipConfig.user} · ${SipConfig.serverIp}'
          '${sip.lastError != null && !sip.isRegistered ? '\n${sip.lastError}' : ''}',
        ),
      ),
    );
  }
}
