import 'package:call_manager/core/call_decision.dart';
import 'package:call_manager/core/call_decision_engine.dart';
import 'package:call_manager/core/call_rules.dart';
import 'package:flutter_test/flutter_test.dart';

class _Contacts implements ContactsRepository {
  @override
  Future<String?> findNameByNumber(String number) async =>
      number == '1001' ? 'Client A' : null;
}

class _Calendar implements CalendarRepository {
  _Calendar(this.appointment);
  final Appointment? appointment;

  @override
  Future<Appointment?> currentAppointment(DateTime at) async => appointment;
}

void main() {
  final now = DateTime(2026, 11, 19, 14, 0);
  final rdv = Appointment(
    title: 'Réunion',
    start: DateTime(2026, 11, 19, 13, 30),
    end: DateTime(2026, 11, 19, 14, 30),
  );

  CallContext ctx({String? name, Appointment? appointment}) => CallContext(
        callerNumber: name == null ? '1002' : '1001',
        contactName: name,
        appointment: appointment,
        now: now,
        mode: ResponseMode.sms,
      );

  group('Chaque règle, testée seule', () {
    test('BusyInMeetingRule : ne décide que pendant un rendez-vous', () {
      const rule = BusyInMeetingRule();
      expect(rule.evaluate(ctx(name: 'Client A', appointment: rdv)),
          isA<RejectBusy>());
      expect(rule.evaluate(ctx(name: 'Client A')), isNull);
    });

    test('DefaultRingRule : décide toujours (sonnerie)', () {
      const rule = DefaultRingRule();
      expect(rule.evaluate(ctx()), isA<LetRing>());
      expect(rule.evaluate(ctx(name: 'Client A')), isA<LetRing>());
    });
  });

  group('Ordre des règles', () {
    CallDecisionEngine engine(List<CallRule> rules) => CallDecisionEngine(
          contacts: _Contacts(),
          calendar: _Calendar(rdv),
          rules: rules,
          clock: () => now,
        );

    test('La première règle qui s\'applique gagne', () async {
      // Rendez-vous en cours : refus, sauf si une règle placée avant
      // laisse sonner (ici la règle par défaut mise en tête).
      final meetingFirst = await engine(defaultRules)
          .decide('1002', ResponseMode.sms);
      expect(meetingFirst, isA<RejectBusy>());

      final ringFirst = await engine(const [
        DefaultRingRule(),
        BusyInMeetingRule(),
      ]).decide('1002', ResponseMode.sms);
      expect(ringFirst, isA<LetRing>());
    });

    test('Sans règle applicable, on laisse sonner', () async {
      final d = await engine(const []).decide('1001', ResponseMode.sms);
      expect(d, isA<LetRing>());
    });
  });
}
