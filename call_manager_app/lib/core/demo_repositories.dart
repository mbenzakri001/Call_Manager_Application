// Contacts et calendrier "de démo", en mémoire.
// Utilisés dans Chrome (pas d'accès aux vrais contacts) et pendant la démo.
// Ils respectent les mêmes contrats que les futurs vrais contacts/calendrier.

import 'call_decision.dart';
import 'call_decision_engine.dart';
import 'phone_utils.dart';

/// Carnet de contacts de démo : 1001 est connu, 1002 ne l'est pas.
class DemoContacts implements ContactsRepository {
  final Map<String, String> byNumber = {
    '1001': 'Client A',
  };

  @override
  Future<String?> findNameByNumber(String number) async {
    for (final e in byNumber.entries) {
      if (samePhone(e.key, number)) return e.value;
    }
    return null;
  }
}

/// Calendrier de démo : au plus un rendez-vous, qu'on démarre ou arrête.
class DemoCalendar implements CalendarRepository {
  Appointment? appointment;

  /// Démarre un rendez-vous maintenant, pour la durée indiquée.
  void startMeeting(Duration duration) {
    final now = DateTime.now();
    appointment = Appointment(
      title: 'Réunion',
      start: now,
      end: now.add(duration),
    );
  }

  /// Supprime le rendez-vous : on redevient disponible.
  void clearMeeting() => appointment = null;

  @override
  Future<Appointment?> currentAppointment(DateTime at) async {
    final a = appointment;
    if (a == null) return null;
    return (!a.start.isAfter(at) && a.end.isAfter(at)) ? a : null;
  }
}
