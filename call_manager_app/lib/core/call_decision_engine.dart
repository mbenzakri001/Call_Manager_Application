// Moteur de décision : rassemble les informations sur l'appel (contacts,
// calendrier, heure), puis applique la liste de règles de call_rules.dart.
// La première règle qui s'applique décide.

import 'call_decision.dart';
import 'call_rules.dart';

/// Source des contacts (vrais contacts du téléphone, ou faux en test/démo).
abstract class ContactsRepository {
  /// Nom du contact correspondant au numéro, ou null s'il est inconnu.
  Future<String?> findNameByNumber(String number);
}

/// Source du calendrier.
abstract class CalendarRepository {
  /// Rendez-vous en cours à l'instant [at], ou null si libre.
  Future<Appointment?> currentAppointment(DateTime at);
}

class CallDecisionEngine {
  CallDecisionEngine({
    required this.contacts,
    required this.calendar,
    this.rules = defaultRules,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ContactsRepository contacts;
  final CalendarRepository calendar;

  /// Règles appliquées dans l'ordre (la première qui décide gagne).
  /// Modifiable : l'écran Scénarios active ou désactive des règles.
  List<CallRule> rules;

  final DateTime Function() _clock;

  /// Rassemble les informations nécessaires aux règles.
  Future<CallContext> buildContext(
      String callerNumber, ResponseMode mode) async {
    final now = _clock();
    return CallContext(
      callerNumber: callerNumber,
      now: now,
      mode: mode,
      contactName: await contacts.findNameByNumber(callerNumber),
      appointment: await calendar.currentAppointment(now),
    );
  }

  Future<CallDecision> decide(String callerNumber, ResponseMode mode) async =>
      (await decideWithRule(callerNumber, mode)).decision;

  /// Comme [decide], mais indique aussi quelle règle a décidé.
  Future<({CallDecision decision, CallRule rule})> decideWithRule(
      String callerNumber, ResponseMode mode) async {
    final call = await buildContext(callerNumber, mode);
    for (final rule in rules) {
      final decision = rule.evaluate(call);
      if (decision != null) return (decision: decision, rule: rule);
    }
    // Filet de sécurité si la liste ne finit pas par DefaultRingRule.
    const fallback = DefaultRingRule();
    return (decision: fallback.evaluate(call)!, rule: fallback);
  }
}
