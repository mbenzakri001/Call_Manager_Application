import 'package:call_manager/core/voicemail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification MWI avec détail : nouveaux / anciens', () {
    const body = 'Messages-Waiting: yes\r\n'
        'Message-Account: sip:1003@192.168.55.12\r\n'
        'Voice-Message: 2/1 (0/0)\r\n';
    final c = parseMessageSummary(body)!;
    expect(c.newMessages, 2);
    expect(c.oldMessages, 1);
  });

  test('plus aucun message', () {
    final c = parseMessageSummary('Messages-Waiting: no\r\n'
        'Voice-Message: 0/3 (0/0)\r\n')!;
    expect(c.newMessages, 0);
    expect(c.oldMessages, 3);
  });

  test('sans détail : seulement Messages-Waiting', () {
    expect(parseMessageSummary('Messages-Waiting: yes')!.newMessages, 1);
    expect(parseMessageSummary('Messages-Waiting: no')!.newMessages, 0);
    expect(parseMessageSummary(null), isNull);
  });
}
