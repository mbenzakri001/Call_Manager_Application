import 'package:flutter/material.dart';

import '../core/call_decision.dart';
import '../core/decision_log.dart';

/// Icône et couleur associées à une décision.
({IconData icon, Color color}) decisionStyle(CallDecision decision) =>
    switch (decision) {
      LetRing() => (icon: Icons.ring_volume, color: Colors.green),
      RejectBusy() => (icon: Icons.event_busy, color: Colors.orange),
      RejectBlocked() => (icon: Icons.block, color: Colors.red),
      RejectDoNotDisturb() => (
        icon: Icons.do_not_disturb_on,
        color: Colors.deepPurple,
      ),
    };

/// Affiche une décision du moteur : qui appelait, ce qui a été décidé,
/// par quelle règle, et le message prévu pour l'appelant.
class DecisionTile extends StatelessWidget {
  const DecisionTile({super.key, required this.entry, this.action});

  final DecisionLogEntry entry;

  /// Bouton facultatif à droite (ex : bloquer / débloquer l'appelant).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = decisionStyle(entry.decision);
    final code = sipRejectCode(entry.decision);
    final message = callerMessage(entry.decision);
    final name = entry.contactName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: style.color.withValues(alpha: 0.15),
              foregroundColor: style.color,
              child: Icon(style.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name == null
                              ? entry.callerNumber
                              : '$name (${entry.callerNumber})',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        formatHour(entry.time),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    decisionSummary(entry.decision) +
                        (code == null ? '' : ' · SIP $code'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: style.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Tag('Règle : ${entry.ruleName}'),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '« $message »',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
