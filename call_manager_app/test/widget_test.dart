import 'package:call_manager/config/sip_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la configuration SIP pointe vers le serveur WebSocket du compte 1003',
      () {
    expect(SipConfig.webSocketUrl, 'ws://${SipConfig.serverIp}:8088/ws');
    expect(SipConfig.sipUri, 'sip:1003@${SipConfig.serverIp}');
  });
}
