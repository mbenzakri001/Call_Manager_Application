// Moteur de règles
//   1. Numéro absent des contacts = refus + "laissez-moi un SMS"
//   2. Contact connu, en rendez-vous = refus + "en rdv jusqu'à HHhMM"
//   3. Contact connu, disponible = on laisse sonner

import 'call_decision.dart';

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
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ContactsRepository contacts;
  final CalendarRepository calendar;
  final DateTime Function() _clock;

  Future<CallDecision> decide(String callerNumber, ResponseMode mode) async {
    // Scénario 1 : présence dans les contacts
    final name = await contacts.findNameByNumber(callerNumber);
    if (name == null) {
      return RejectUnknown(callerNumber, mode, Messages.unknownCaller());
    }

    // Scénario 2 : disponibilité dans le calendrier
    final rdv = await calendar.currentAppointment(_clock());
    if (rdv != null) {
      return RejectBusy(
          callerNumber, name, rdv, mode, Messages.busy(name, rdv.end));
    }

    // Scénario 3 : connu et disponible
    return LetRing(callerNumber, name);
  }
}