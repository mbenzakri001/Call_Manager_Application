import 'package:call_manager/core/call_decision.dart';
import 'package:call_manager/sip/sip_service.dart';
import 'package:call_manager/ui/calendar_page.dart';
import 'package:call_manager/ui/contacts_page.dart';
import 'package:call_manager/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Pas de connexion au serveur : on n'appelle jamais sip.start().
// Chaque test agit sur un onglet, puis vérifie la décision du moteur.
Future<SipService> pump(
    WidgetTester tester, Widget Function(SipService) page) async {
  final sip = SipService();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ListenableBuilder(listenable: sip, builder: (_, _) => page(sip)),
    ),
  ));
  return sip;
}

void main() {
  testWidgets('Contacts : ajouter puis supprimer 1002', (tester) async {
    final sip = await pump(tester, (s) => ContactsPage(sip: s));
    expect(sip.contactNameFor('1002'), isNull);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Client B');
    await tester.enterText(find.byType(TextField).at(1), '1002');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Client B'), findsOneWidget);
    expect(sip.contactNameFor('1002'), 'Client B');

    // Client B est le dernier de la liste : menu "Plus" -> Supprimer.
    await tester.tap(find.byTooltip('Plus').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Client B'), findsNothing);
  });

  testWidgets('Calendrier : réunion maintenant -> refus 486', (tester) async {
    final sip = await pump(tester, (s) => CalendarPage(sip: s));
    expect(find.text('Disponible'), findsOneWidget);

    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();
    expect(sip.inMeeting, isTrue);
    expect(find.textContaining("jusqu'à"), findsOneWidget);
    expect(await sip.engine.decide('1001', sip.responseMode),
        isA<RejectBusy>());

    await tester.tap(find.text('Terminer maintenant'));
    await tester.pumpAndSettle();
    expect(sip.inMeeting, isFalse);
    expect(await sip.engine.decide('1001', sip.responseMode), isA<LetRing>());
  });

  testWidgets('Réglages : désactiver "En rendez-vous" -> ça sonne',
      (tester) async {
    final sip = await pump(tester, (s) => SettingsPage(sip: s));
    sip.startMeeting(const Duration(minutes: 30));
    expect(await sip.engine.decide('1001', sip.responseMode),
        isA<RejectBusy>());

    final ruleSwitch = find.descendant(
      of: find.ancestor(
          of: find.text('En rendez-vous'), matching: find.byType(ListTile)),
      matching: find.byType(Switch),
    );
    await tester.scrollUntilVisible(ruleSwitch, 200);
    await tester.tap(ruleSwitch);
    await tester.pumpAndSettle();

    expect(await sip.engine.decide('1001', sip.responseMode), isA<LetRing>());
  });

  testWidgets('Réglages : Ne pas déranger -> refus 480', (tester) async {
    final sip = await pump(tester, (s) => SettingsPage(sip: s));
    await tester.tap(find.text('Ne pas déranger').first);
    await tester.pumpAndSettle();
    expect(sip.doNotDisturbOn, isTrue);
    expect(await sip.engine.decide('1001', sip.responseMode),
        isA<RejectDoNotDisturb>());
  });

  testWidgets('Contacts : favori puis blocage', (tester) async {
    final sip = await pump(tester, (s) => ContactsPage(sip: s));

    // Étoile : 1001 devient favori, il sonne même en Ne pas déranger.
    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await tester.pumpAndSettle();
    sip.doNotDisturbOn = true;
    expect(await sip.engine.decide('1001', sip.responseMode), isA<LetRing>());

    // Menu "Plus" -> Bloquer : la liste noire passe avant les favoris.
    await tester.tap(find.byTooltip('Plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquer'));
    await tester.pumpAndSettle();
    expect(find.text('Débloquer'), findsOneWidget);
    expect(await sip.engine.decide('1001', sip.responseMode),
        isA<RejectBlocked>());

    await tester.tap(find.text('Débloquer'));
    await tester.pumpAndSettle();
    expect(sip.isBlocked('1001'), isFalse);
  });
}
