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
  testWidgets('Contacts : ajouter 1002 -> il n\'est plus refusé',
      (tester) async {
    final sip = await pump(tester, (s) => ContactsPage(sip: s));
    expect(await sip.engine.decide('1002', sip.responseMode),
        isA<RejectUnknown>());

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Client B');
    await tester.enterText(find.byType(TextField).at(1), '1002');
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Client B'), findsOneWidget);
    expect(await sip.engine.decide('1002', sip.responseMode), isA<LetRing>());

    await tester.tap(find.byTooltip('Supprimer').last);
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

  testWidgets('Réglages : désactiver "Numéro inconnu" -> l\'inconnu sonne',
      (tester) async {
    final sip = await pump(tester, (s) => SettingsPage(sip: s));

    final ruleSwitch = find.descendant(
      of: find.ancestor(
          of: find.text('Numéro inconnu'), matching: find.byType(ListTile)),
      matching: find.byType(Switch),
    );
    await tester.tap(ruleSwitch);
    await tester.pumpAndSettle();

    expect(await sip.engine.decide('1002', sip.responseMode), isA<LetRing>());
  });
}
