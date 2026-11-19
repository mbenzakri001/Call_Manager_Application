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

/// Numéro absent des contacts : refus + demande de SMS.
class UnknownCallerRule extends CallRule {
  const UnknownCallerRule();

  @override
  String get name => 'Numéro inconnu';

  @override
  String get description =>
      'Numéro absent des contacts → refus (603) + demande de SMS';

  @override
  CallDecision? evaluate(CallContext call) {
    if (call.isKnownContact) return null;
    return RejectUnknown(call.callerNumber, call.mode, Messages.unknownCaller());
  }
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
        call.callerNumber, name, rdv, call.mode, Messages.busy(name, rdv.end));
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
const List<CallRule> defaultRules = [
  UnknownCallerRule(),
  BusyInMeetingRule(),
  DefaultRingRule(),
];
