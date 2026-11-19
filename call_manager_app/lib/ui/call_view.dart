import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';

import '../sip/sip_service.dart';

/// Écran plein affiché pendant un appel (entrant ou sortant).
class CallView extends StatelessWidget {
  const CallView({super.key, required this.sip});
  final SipService sip;

  @override
  Widget build(BuildContext context) {
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 48,
              child: Text(
                (name.isNotEmpty ? name : number).characters.firstOrNull ?? '?',
                style: theme.textTheme.headlineLarge,
              ),
            ),
            const SizedBox(height: 24),
            Text(name.isNotEmpty ? name : number,
                style: theme.textTheme.headlineMedium),
            if (name.isNotEmpty) Text(number, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(status, style: theme.textTheme.bodyLarge),
            const Spacer(flex: 2),
            if (sip.isRinging)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundButton(
                    color: Colors.red,
                    icon: Icons.call_end,
                    label: 'Refuser',
                    // 603 Decline : l'appelant voit un refus explicite.
                    onPressed: () => sip.hangup(statusCode: 603),
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
