// Journal des décisions du moteur sur les appels entrants, et petites
// fonctions qui traduisent une décision en code SIP ou en texte.

import 'call_decision.dart';

/// Une décision prise par le moteur, gardée pour l'écran Historique.
class DecisionLogEntry {
  const DecisionLogEntry({
    required this.time,
    required this.callerNumber,
    required this.decision,
    required this.ruleName,
  });

  final DateTime time;
  final String callerNumber;
  final CallDecision decision;

  /// Nom de la règle qui a décidé.
  final String ruleName;

  /// Nom du contact, ou null si l'appelant est inconnu.
  String? get contactName => switch (decision) {
        LetRing(:final contactName) =>
          contactName == callerNumber ? null : contactName,
        RejectBusy(:final contactName) =>
          contactName == callerNumber ? null : contactName,
        RejectUnknown() => null,
      };
}

/// Code SIP envoyé à l'appelant pour un refus, ou null si on laisse sonner.
int? sipRejectCode(CallDecision decision) => switch (decision) {
      LetRing() => null,
      RejectUnknown() => 603, // Decline
      RejectBusy() => 486, // Busy Here
    };

/// Résumé court de la décision ("Sonnerie", "Refusé : numéro inconnu"…).
String decisionSummary(CallDecision decision) => switch (decision) {
      LetRing() => 'Sonnerie',
      RejectUnknown() => 'Refusé : numéro inconnu',
      RejectBusy(:final appointment) =>
        "Refusé : en rendez-vous jusqu'à ${formatHour(appointment.end)}",
    };

/// Message destiné à l'appelant, ou null si on laisse sonner.
String? callerMessage(CallDecision decision) => switch (decision) {
      LetRing() => null,
      RejectUnknown(:final message) => message,
      RejectBusy(:final message) => message,
    };
