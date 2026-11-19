// Contacts et calendrier propres à l'app, en mémoire.
// Ils respectent les mêmes contrats que de futurs vrais contacts/calendrier
// du téléphone (ContactsRepository, CalendarRepository).

import 'call_decision.dart';
import 'call_decision_engine.dart';
import 'phone_utils.dart';

/// Carnet de contacts : 1001 est connu, 1002 ne l'est pas.
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

/// Calendrier : une liste de rendez-vous.
class DemoCalendar implements CalendarRepository {
  final List<Appointment> appointments = [];

  /// Rendez-vous en cours à l'instant [at], ou null si libre.
  Appointment? appointmentAt(DateTime at) {
    for (final a in appointments) {
      if (!a.start.isAfter(at) && a.end.isAfter(at)) return a;
    }
    return null;
  }

  void add(Appointment appointment) {
    appointments
      ..add(appointment)
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  void remove(Appointment appointment) => appointments.remove(appointment);

  /// Démarre un rendez-vous maintenant, pour la durée indiquée.
  void startMeeting(Duration duration, {String title = 'Réunion'}) {
    final now = DateTime.now();
    add(Appointment(title: title, start: now, end: now.add(duration)));
  }

  /// Termine maintenant le rendez-vous en cours : on redevient disponible.
  void endCurrentMeeting() {
    final now = DateTime.now();
    final current = appointmentAt(now);
    if (current == null) return;
    final i = appointments.indexOf(current);
    appointments[i] =
        Appointment(title: current.title, start: current.start, end: now);
  }

  @override
  Future<Appointment?> currentAppointment(DateTime at) async =>
      appointmentAt(at);
}
