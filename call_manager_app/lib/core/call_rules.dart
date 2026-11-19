// Règles du call manager.
//
// Chaque règle répond à UNE question sur l'appel. Si elle s'applique, elle
// rend une décision ; sinon elle rend null et le moteur passe à la suivante.
// L'ordre de la liste fixe la priorité : la première règle qui décide gagne.
//
// Ajouter un scénario = écrire une classe qui étend CallRule, puis l'insérer
// au bon endroit dans [defaultRules]. Si la règle a besoin d'une nouvelle
// information (liste noire, historique d'appels…), on l'ajoute à CallContext.

import 'call_decision.dart';

/// Tout ce que les règles peuvent savoir sur un appel entrant.
/// Rempli une seule fois par le moteur avant de parcourir les règles.
class CallContext {
  const CallContext({
    required this.callerNumber,
    required this.now,
    required this.mode,
    this.contactName,
    this.appointment,
    this.isBlocked = false,
    this.isFavorite = false,
    this.doNotDisturb = false,
    this.recentCallsFromCaller = 0,
  });

  /// Numéro de l'appelant tel que reçu (ex : "1001").
  final String callerNumber;

  /// Nom du contact, ou null si le numéro est inconnu.
  final String? contactName;

  /// Rendez-vous en cours, ou null si l'utilisateur est disponible.
  final Appointment? appointment;

  /// Heure de l'appel.
  final DateTime now;

  /// Canal utilisé pour prévenir l'appelant en cas de refus.
  final ResponseMode mode;

  /// Le numéro est-il dans la liste noire ?
  final bool isBlocked;

  /// L'appelant est-il un contact favori ?
  final bool isFavorite;

  /// Le mode "Ne pas déranger" est-il activé ?
  final bool doNotDisturb;

  /// Nombre d'appels de ce numéro dans les dernières minutes
  /// ([UrgentRepeatCallRule.window]), sans compter l'appel en cours.
  final int recentCallsFromCaller;

  bool get isKnownContact => contactName != null;
  bool get isInMeeting => appointment != null;
}

/// Une règle du moteur : une condition + l'action à prendre.
abstract class CallRule {
  const CallRule();

  /// Nom court, affiché dans les explications et les tests.
  String get name;

  /// Phrase "condition -> action", affichée dans l'écran Scénarios.
  String get description;

  /// Faux pour une règle qu'on ne peut pas désactiver (règle par défaut).
  bool get canBeDisabled => true;

  /// Décision si la règle s'applique, sinon null.
  CallDecision? evaluate(CallContext call);
}

/// Numéro en liste noire : refus (603), toujours, même pour un contact.
class BlockedCallerRule extends CallRule {
  const BlockedCallerRule();

  @override
  String get name => 'Liste noire';

  @override
  String get description => 'Numéro bloqué → refus (603), sans message';

  @override
  CallDecision? evaluate(CallContext call) => call.isBlocked
      ? RejectBlocked(call.callerNumber, contactName: call.contactName)
      : null;
}

/// Contact favori : sonne toujours, même en rendez-vous ou en
/// "Ne pas déranger" (mais pas s'il est bloqué : la liste noire passe avant).
class FavoriteRule extends CallRule {
  const FavoriteRule();

  @override
  String get name => 'Favori';

  @override
  String get description =>
      'Contact favori → sonnerie, même en rendez-vous ou en Ne pas déranger';

  @override
  CallDecision? evaluate(CallContext call) => call.isFavorite
      ? LetRing(call.callerNumber, call.contactName ?? call.callerNumber)
      : null;
}

/// Un contact qui rappelle vite est sans doute urgent : on le laisse sonner.
class UrgentRepeatCallRule extends CallRule {
  const UrgentRepeatCallRule();

  /// Délai dans lequel un deuxième appel est considéré comme urgent.
  static const Duration window = Duration(seconds: 30);

  @override
  String get name => 'Appel répété';

  @override
  String get description =>
      'Un contact rappelle dans les 30 s → sonnerie (urgence), '
      'même en rendez-vous ou en Ne pas déranger';

  @override
  CallDecision? evaluate(CallContext call) =>
      call.isKnownContact && call.recentCallsFromCaller > 0
      ? LetRing(call.callerNumber, call.contactName!)
      : null;
}

/// Mode "Ne pas déranger" : refus (480) avec un message.
class DoNotDisturbRule extends CallRule {
  const DoNotDisturbRule();

  @override
  String get name => 'Ne pas déranger';

  @override
  String get description => 'Ne pas déranger activé → refus (480) + message';

  @override
  CallDecision? evaluate(CallContext call) => call.doNotDisturb
      ? RejectDoNotDisturb(
          call.callerNumber,
          Messages.doNotDisturb(call.contactName),
          contactName: call.contactName,
        )
      : null;
}

/// Contact connu mais en rendez-vous : refus avec l'heure de fin.
class BusyInMeetingRule extends CallRule {
  const BusyInMeetingRule();

  @override
  String get name => 'En rendez-vous';

  @override
  String get description =>
      'Rendez-vous en cours → refus (486) + heure de fin du rendez-vous';

  @override
  CallDecision? evaluate(CallContext call) {
    final rdv = call.appointment;
    if (rdv == null) return null;
    final name = call.contactName ?? call.callerNumber;
    return RejectBusy(
      call.callerNumber,
      name,
      rdv,
      call.mode,
      Messages.busy(name, rdv.end),
    );
  }
}

/// Règle par défaut, toujours en dernier : on laisse sonner.
class DefaultRingRule extends CallRule {
  const DefaultRingRule();

  @override
  String get name => 'Par défaut';

  @override
  String get description => 'Aucune règle ne s\'applique → sonnerie';

  @override
  bool get canBeDisabled => false;

  @override
  CallDecision? evaluate(CallContext call) =>
      LetRing(call.callerNumber, call.contactName ?? call.callerNumber);
}

/// Règles utilisées par l'app, par ordre de priorité.
/// Les exceptions (favori, appel répété) passent avant les règles qu'elles
/// contournent (Ne pas déranger, rendez-vous).
const List<CallRule> defaultRules = [
  BlockedCallerRule(),
  FavoriteRule(),
  UrgentRepeatCallRule(),
  DoNotDisturbRule(),
  BusyInMeetingRule(),
  DefaultRingRule(),
];
