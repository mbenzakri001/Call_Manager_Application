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

/// Liste noire et favoris.
abstract class CallerListsRepository {
  Future<bool> isBlocked(String number);
  Future<bool> isFavorite(String number);
}

/// Appels déjà reçus (pour repérer un appel répété).
abstract class CallHistoryRepository {
  /// Nombre d'appels reçus de [number] depuis [since].
  Future<int> countCallsFrom(String number, DateTime since);
}

/// Réglages de l'utilisateur.
abstract class UserSettingsRepository {
  Future<bool> doNotDisturb();
}

class CallDecisionEngine {
  CallDecisionEngine({
    required this.contacts,
    required this.calendar,
    this.lists,
    this.history,
    this.settings,
    this.rules = defaultRules,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ContactsRepository contacts;
  final CalendarRepository calendar;

  /// Sources facultatives : absentes, les règles correspondantes ne
  /// s'appliquent jamais (personne n'est bloqué, ni favori…).
  final CallerListsRepository? lists;
  final CallHistoryRepository? history;
  final UserSettingsRepository? settings;

  /// Règles appliquées dans l'ordre (la première qui décide gagne).
  /// Modifiable : l'onglet Réglages active ou désactive des règles.
  List<CallRule> rules;

  final DateTime Function() _clock;

  /// Rassemble les informations nécessaires aux règles.
  Future<CallContext> buildContext(
    String callerNumber,
    ResponseMode mode,
  ) async {
    final now = _clock();
    return CallContext(
      callerNumber: callerNumber,
      now: now,
      mode: mode,
      contactName: await contacts.findNameByNumber(callerNumber),
      appointment: await calendar.currentAppointment(now),
      isBlocked: await lists?.isBlocked(callerNumber) ?? false,
      isFavorite: await lists?.isFavorite(callerNumber) ?? false,
      doNotDisturb: await settings?.doNotDisturb() ?? false,
      recentCallsFromCaller:
          await history?.countCallsFrom(
            callerNumber,
            now.subtract(UrgentRepeatCallRule.window),
          ) ??
          0,
    );
  }

  Future<CallDecision> decide(String callerNumber, ResponseMode mode) async =>
      (await decideWithRule(callerNumber, mode)).decision;

  /// Comme [decide], mais indique aussi quelle règle a décidé.
  Future<({CallDecision decision, CallRule rule})> decideWithRule(
    String callerNumber,
    ResponseMode mode,
  ) async {
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
