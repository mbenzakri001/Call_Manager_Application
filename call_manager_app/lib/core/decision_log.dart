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
    RejectBlocked(:final contactName) => contactName,
    RejectDoNotDisturb(:final contactName) => contactName,
  };
}

/// Code SIP envoyé à l'appelant pour un refus, ou null si on laisse sonner.
int? sipRejectCode(CallDecision decision) => switch (decision) {
  LetRing() => null,
  RejectBusy() => 486, // Busy Here
  RejectBlocked() => 603, // Decline
  RejectDoNotDisturb() => 480, // Temporarily Unavailable
};

/// Résumé court de la décision ("Sonnerie", "Refusé : numéro bloqué"…).
String decisionSummary(CallDecision decision) => switch (decision) {
  LetRing() => 'Sonnerie',
  RejectBusy(:final appointment) =>
    "Refusé : en rendez-vous jusqu'à ${formatHour(appointment.end)}",
  RejectBlocked() => 'Refusé : numéro bloqué',
  RejectDoNotDisturb() => 'Refusé : ne pas déranger',
};

/// Message destiné à l'appelant, ou null si on laisse sonner.
String? callerMessage(CallDecision decision) => switch (decision) {
  LetRing() => null,
  RejectBusy(:final message) => message,
  RejectBlocked() => null,
  RejectDoNotDisturb(:final message) => message,
};
