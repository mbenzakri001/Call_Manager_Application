import 'package:call_manager/core/chat.dart';
import 'package:call_manager/sip/sip_service.dart';
import 'package:call_manager/ui/messages_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lecture des messages reçus', () {
    test('texte simple', () {
      expect(extractMessageText('text/plain', 'Bonjour'), 'Bonjour');
      expect(extractMessageText(null, ' Salut '), 'Salut');
    });

    test('texte emballé en CPIM (Linphone)', () {
      const cpim = 'From: <sip:1001@pbx>\r\nTo: <sip:1003@pbx>\r\n'
          'DateTime: 2026-11-19T10:00:00Z\r\n\r\n'
          'Content-Type: text/plain\r\n\r\nTu es dispo ?';
      expect(extractMessageText('message/cpim', cpim), 'Tu es dispo ?');
    });

    test('accusés de lecture ignorés', () {
      expect(extractMessageText('message/imdn+xml', '<imdn/>'), isNull);
      expect(
          extractMessageText('message/cpim',
              'From: x\r\n\r\nContent-Type: message/imdn+xml\r\n\r\n<imdn/>'),
          isNull);
    });
  });

  testWidgets('Conversation : un message non connecté est marqué non envoyé',
      (tester) async {
    final sip = SipService(); // jamais démarré : pas de serveur
    await tester.pumpWidget(MaterialApp(
      home: ConversationPage(sip: sip, peer: '1001'),
    ));

    await tester.enterText(find.byType(TextField), 'Bonjour Client A');
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour Client A'), findsOneWidget);
    expect(find.text('Non envoyé'), findsOneWidget);
    expect(sip.conversations['1001']!.single.status, MessageStatus.failed);
  });

  testWidgets('Onglet Messages : liste des conversations', (tester) async {
    final sip = SipService();
    sip.sendText('1001', 'Premier message');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
            listenable: sip, builder: (_, _) => MessagesPage(sip: sip)),
      ),
    ));

    expect(find.text('Client A'), findsOneWidget); // nom du contact
    expect(find.text('Vous : Premier message'), findsOneWidget);
  });
}
