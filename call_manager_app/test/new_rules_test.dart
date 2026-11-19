import 'package:call_manager/core/call_decision.dart';
import 'package:call_manager/core/call_decision_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// Situation de test : 1001 (Client A) et 1004 (Chef) sont des contacts,
// 1002 est inconnu. Tout est réglable test par test.
class _Contacts implements ContactsRepository {
  @override
  Future<String?> findNameByNumber(String n) async =>
      {'1001': 'Client A', '1004': 'Chef'}[n];
}

class _Calendar implements CalendarRepository {
  Appointment? rdv;
  @override
  Future<Appointment?> currentAppointment(DateTime at) async => rdv;
}

class _Lists implements CallerListsRepository {
  final Set<String> blocked = {}, favorites = {};
  @override
  Future<bool> isBlocked(String n) async => blocked.contains(n);
  @override
  Future<bool> isFavorite(String n) async => favorites.contains(n);
}

class _History implements CallHistoryRepository {
  final List<(String, DateTime)> calls = [];
  @override
  Future<int> countCallsFrom(String n, DateTime since) async =>
      calls.where((c) => c.$1 == n && c.$2.isAfter(since)).length;
}

class _Settings implements UserSettingsRepository {
  bool dnd = false;
  @override
  Future<bool> doNotDisturb() async => dnd;
}

void main() {
  final now = DateTime(2026, 11, 19, 14, 0);
  late _Calendar calendar;
  late _Lists lists;
  late _History history;
  late _Settings settings;
  late CallDecisionEngine engine;

  setUp(() {
    calendar = _Calendar();
    lists = _Lists();
    history = _History();
    settings = _Settings();
    engine = CallDecisionEngine(
      contacts: _Contacts(),
      calendar: calendar,
      lists: lists,
      history: history,
      settings: settings,
      clock: () => now,
    );
  });

  Future<(CallDecision, String)> call(String n) async {
    final r = await engine.decideWithRule(n, ResponseMode.sms);
    return (r.decision, r.rule.name);
  }

  void inMeeting() => calendar.rdv = Appointment(
      title: 'Réunion',
      start: now.subtract(const Duration(minutes: 30)),
      end: now.add(const Duration(minutes: 30)));

  group('Liste noire', () {
    test('un numéro bloqué est refusé (603)', () async {
      lists.blocked.add('1002');
      final (d, rule) = await call('1002');
      expect(d, isA<RejectBlocked>());
      expect(rule, 'Liste noire');
    });

    test('passe avant tout : même un contact favori est refusé', () async {
      lists
        ..blocked.add('1001')
        ..favorites.add('1001');
      expect((await call('1001')).$1, isA<RejectBlocked>());
    });
  });

  group('Ne pas déranger', () {
    test('un contact est refusé (480) avec un message', () async {
      settings.dnd = true;
      final (d, rule) = await call('1001');
      expect(d, isA<RejectDoNotDisturb>());
      expect(rule, 'Ne pas déranger');
      expect((d as RejectDoNotDisturb).message, contains('Client'));
    });

    test('un inconnu est aussi refusé (480)', () async {
      settings.dnd = true;
      expect((await call('1002')).$1, isA<RejectDoNotDisturb>());
    });
  });

  group('Favoris', () {
    test('un favori sonne en Ne pas déranger', () async {
      settings.dnd = true;
      lists.favorites.add('1004');
      final (d, rule) = await call('1004');
      expect(d, isA<LetRing>());
      expect(rule, 'Favori');
    });

    test('un favori sonne en rendez-vous', () async {
      inMeeting();
      lists.favorites.add('1004');
      expect((await call('1004')).$1, isA<LetRing>());
    });

    test('un non-favori est refusé en rendez-vous', () async {
      inMeeting();
      lists.favorites.add('1004');
      expect((await call('1001')).$1, isA<RejectBusy>());
    });
  });

  group('Appel répété', () {
    test('un contact qui rappelle en moins de 30 s sonne en rendez-vous',
        () async {
      inMeeting();
      expect((await call('1001')).$1, isA<RejectBusy>()); // 1er appel
      history.calls.add(('1001', now.subtract(const Duration(seconds: 20))));
      final (d, rule) = await call('1001'); // 2e appel
      expect(d, isA<LetRing>());
      expect(rule, 'Appel répété');
    });

    test('passe aussi le Ne pas déranger', () async {
      settings.dnd = true;
      history.calls.add(('1001', now.subtract(const Duration(seconds: 10))));
      expect((await call('1001')).$1, isA<LetRing>());
    });

    test('au-delà de 30 s, ce n\'est plus une urgence', () async {
      inMeeting();
      history.calls.add(('1001', now.subtract(const Duration(seconds: 40))));
      expect((await call('1001')).$1, isA<RejectBusy>());
    });

    test('ne s\'applique pas aux inconnus', () async {
      inMeeting();
      history.calls.add(('1002', now.subtract(const Duration(seconds: 20))));
      expect((await call('1002')).$1, isA<RejectBusy>());
    });
  });

  test('Sans les nouvelles sources, le moteur se comporte comme avant',
      () async {
    final old = CallDecisionEngine(
        contacts: _Contacts(), calendar: calendar, clock: () => now);
    expect(await old.decide('1001', ResponseMode.sms), isA<LetRing>());
    expect(await old.decide('1002', ResponseMode.sms), isA<LetRing>());
  });
}
