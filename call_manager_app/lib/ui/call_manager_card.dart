import 'package:flutter/material.dart';

import '../core/call_decision.dart';
import '../sip/sip_service.dart';

/// Carte de démo du call manager : contacts connus, interrupteur
/// "En rendez-vous" (calendrier de démo) et dernière décision du moteur.
class CallManagerCard extends StatelessWidget {
  const CallManagerCard({super.key, required this.sip});

  final SipService sip;

  @override
  Widget build(BuildContext context) {
    final rdv = sip.calendar.appointment;
    final inMeeting = rdv != null && rdv.end.isAfter(DateTime.now());
    final contacts = sip.contacts.byNumber.entries
        .map((e) => '${e.value} (${e.key})')
        .join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call manager',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Contacts connus : $contacts'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('En rendez-vous'),
              subtitle: Text(inMeeting
                  ? "Occupé jusqu'à ${formatHour(rdv!.end)}"
                  : 'Disponible'),
              value: inMeeting,
              onChanged: (on) {
                if (on) {
                  sip.calendar.startMeeting(const Duration(minutes: 30));
                } else {
                  sip.calendar.clearMeeting();
                }
                sip.refresh(); // redessine l'écran
              },
            ),
            const Divider(),
            Text('Dernière décision :',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(sip.lastDecision ?? "Aucun appel reçu pour l'instant"),
          ],
        ),
      ),
    );
  }
}