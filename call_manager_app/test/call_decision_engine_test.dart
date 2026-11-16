import 'package:call_manager/core/call_decision.dart';
import 'package:call_manager/core/call_decision_engine.dart';
import 'package:call_manager/core/phone_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faux carnet de contacts : un simple dictionnaire numéro -> nom.
class FakeContacts implements ContactsRepository {
  FakeContacts(this.byNumber);
  final Map<String, String> byNumber;

  @override
  Future<String?> findNameByNumber(String number) async {
    for (final e in byNumber.entries) {
      if (samePhone(e.key, number)) return e.value;
    }
    return null;
  }
}

/// Faux calendrier : au plus un rendez-vous.
class FakeCalendar implements CalendarRepository {
  FakeCalendar([this.appointment]);
  final Appointment? appointment;

  @override
  Future<Appointment?> currentAppointment(DateTime at) async {
    final a = appointment;
    if (a == null) return null;
    return (!a.start.isAfter(at) && a.end.isAfter(at)) ? a : null;
  }
}

void main() {
  final now = DateTime(2026, 11, 16, 14, 0); // on fige l'heure : 14h00
  final contacts = FakeContacts({
    '1001': 'Client A',
    '06 12 34 56 78': 'Sara Benali',
  });
  final rdv = Appointment(
    title: 'Réunion projet',
    start: DateTime(2026, 11, 16, 13, 30),
    end: DateTime(2026, 11, 16, 14, 30),
  );

  CallDecisionEngine engine(Appointment? a) => CallDecisionEngine(
        contacts: contacts,
        calendar: FakeCalendar(a),
        clock: () => now,
      );

  test('Scénario 1 : numéro inconnu -> refus avec demande de SMS', () async {
    final d = await engine(null).decide('1002', ResponseMode.sms);
    expect(d, isA<RejectUnknown>());
    expect((d as RejectUnknown).message, contains('SMS'));
  });

  test('Scénario 2 : contact en rendez-vous -> refus avec heure de fin', () async {
    final d = await engine(rdv).decide('+33612345678', ResponseMode.sms);
    expect(d, isA<RejectBusy>());
    expect((d as RejectBusy).message, contains('Sara'));
    expect(d.message, contains('14h30'));
  });

  test('Scénario 3 : contact disponible -> sonnerie', () async {
    final d = await engine(null).decide('1001', ResponseMode.sms);
    expect(d, isA<LetRing>());
    expect((d as LetRing).contactName, 'Client A');
  });

  test('Normalisation des numéros', () {
    expect(normalizePhone('+33 6 12 34 56 78'), '0612345678');
    expect(normalizePhone('sip:1001@192.168.60.139'), '1001');
    expect(samePhone('06.12.34.56.78', '+33612345678'), isTrue);
    expect(samePhone('1001', '1002'), isFalse);
  });
}