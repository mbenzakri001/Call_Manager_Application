import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';

import '../sip/sip_service.dart';

/// Écran plein affiché pendant un appel (entrant ou sortant).
class CallView extends StatefulWidget {
  const CallView({super.key, required this.sip});
  final SipService sip;

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> {
  /// Clavier affiché (pour piloter la messagerie vocale, un serveur vocal…).
  bool _showKeypad = false;

  /// Touches déjà envoyées pendant cet appel.
  String _typed = '';

  void _press(String key) {
    widget.sip.sendDtmf(key);
    setState(() => _typed += key);
  }

  @override
  Widget build(BuildContext context) {
    final sip = widget.sip;
    final call = sip.currentCall!;
    final theme = Theme.of(context);
    final incoming = call.direction == Direction.incoming;
    final name = call.remote_display_name ?? '';
    final number = call.remote_identity ?? '';

    final status = sip.isRinging
        ? 'Appel entrant…'
        : switch (sip.callState) {
            CallStateEnum.CONFIRMED || CallStateEnum.ACCEPTED => 'En ligne',
            _ when incoming => 'Connexion…',
            _ => 'Appel en cours…',
          };

    final inCall = !sip.isRinging;
    final keypad = inCall && _showKeypad;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            if (keypad)
              Expanded(
                child: _Keypad(typed: _typed, onPress: _press),
              )
            else ...[
              const Spacer(),
              CircleAvatar(
                radius: 48,
                child: Text(
                  (name.isNotEmpty ? name : number).characters.firstOrNull ??
                      '?',
                  style: theme.textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                name.isNotEmpty ? name : number,
                style: theme.textTheme.headlineMedium,
              ),
              if (name.isNotEmpty)
                Text(number, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(status, style: theme.textTheme.bodyLarge),
              const Spacer(flex: 2),
            ],
            if (sip.isRinging)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundButton(
                    color: Colors.red,
                    icon: Icons.call_end,
                    label: 'Refuser',
                    // 486 Busy Here : l'appelant tombe sur la messagerie
                    // vocale (603 est réservé à la liste noire).
                    onPressed: () => sip.hangup(statusCode: 486),
                  ),
                  _RoundButton(
                    color: Colors.green,
                    icon: Icons.call,
                    label: 'Décrocher',
                    onPressed: sip.answer,
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundButton(
                    color: _showKeypad
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    icon: Icons.dialpad,
                    label: 'Clavier',
                    onPressed: () => setState(() => _showKeypad = !_showKeypad),
                  ),
                  _RoundButton(
                    color: sip.speakerOn
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    icon: sip.speakerOn ? Icons.volume_up : Icons.volume_down,
                    label: 'Haut-parleur',
                    onPressed: sip.toggleSpeaker,
                  ),
                  _RoundButton(
                    color: Colors.red,
                    icon: Icons.call_end,
                    label: 'Raccrocher',
                    onPressed: sip.hangup,
                  ),
                ],
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Clavier de tonalités (DTMF) pendant un appel.
class _Keypad extends StatelessWidget {
  const _Keypad({required this.typed, required this.onPress});
  final String typed;
  final ValueChanged<String> onPress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: Text(
                typed,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['*', '0', '#'],
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final key in row)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: FilledButton.tonal(
                          onPressed: () => onPress(key),
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            key,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(22),
          ),
          child: Icon(icon, size: 32),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
