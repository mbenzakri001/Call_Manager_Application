import 'package:flutter/material.dart';

import '../sip/sip_service.dart';
import 'decision_tile.dart';

/// Onglet Historique : toutes les décisions du moteur, la plus récente en haut.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.sip});
  final SipService sip;

  @override
  Widget build(BuildContext context) {
    if (sip.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              const Text(
                "Aucun appel reçu pour l'instant.\nChaque appel entrant et la "
                'décision prise apparaîtront ici.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${sip.history.length} appel(s) reçu(s)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: sip.clearHistory,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Effacer'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final entry in sip.history)
          DecisionTile(
            entry: entry,
            action: IconButton(
              tooltip: sip.isBlocked(entry.callerNumber)
                  ? 'Débloquer ce numéro'
                  : 'Bloquer ce numéro',
              icon: Icon(
                Icons.block,
                color: sip.isBlocked(entry.callerNumber) ? Colors.red : null,
              ),
              onPressed: () => sip.setBlocked(
                entry.callerNumber,
                !sip.isBlocked(entry.callerNumber),
              ),
            ),
          ),
      ],
    );
  }
}
