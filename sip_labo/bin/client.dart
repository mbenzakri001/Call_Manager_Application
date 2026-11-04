import 'dart:convert';
import 'dart:io';

import 'package:sip_labo/sip_message.dart';

/// Usage : `dart run bin/client.dart UTILISATEUR [IP_SERVEUR]`
Future<void> main(List<String> args) async {
  final user = args.isNotEmpty ? args[0] : '1001';
  final serverIp = args.length > 1 ? args[1] : '127.0.0.1';
  const serverPort = 5060;

  // Port 0 = le système choisit un port libre (évite les conflits sur 5060).
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final localIp = serverIp == '127.0.0.1' ? '127.0.0.1' : await findLocalIp();
  final localPort = socket.port;
  print('Client $user sur $localIp:$localPort -> serveur $serverIp:$serverPort');

  final register = SipMessage(
    startLine: 'REGISTER sip:$serverIp SIP/2.0',
    headers: [
      MapEntry('Via',
          'SIP/2.0/UDP $localIp:$localPort;branch=z9hG4bK${randomToken()};rport'),
      const MapEntry('Max-Forwards', '70'),
      MapEntry('From', '<sip:$user@$serverIp>;tag=${randomToken()}'),
      MapEntry('To', '<sip:$user@$serverIp>'),
      MapEntry('Call-ID', '${randomToken(16)}@$localIp'),
      const MapEntry('CSeq', '1 REGISTER'),
      MapEntry('Contact', '<sip:$user@$localIp:$localPort>'),
      const MapEntry('Expires', '3600'),
      const MapEntry('User-Agent', 'DartSIP-Client'),
    ],
  );

  socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final dg = socket.receive();
    if (dg == null) return;
    final msg = SipMessage.parse(utf8.decode(dg.data, allowMalformed: true));
    print('<<< ${msg.startLine}');

    if (!msg.isRequest && msg.method == 'REGISTER' && msg.statusCode == 200) {
      print('✅ $user est enregistré auprès du serveur');
    }
  });

  socket.send(
      utf8.encode(register.serialize()), InternetAddress(serverIp), serverPort);
  print('>>> ${register.startLine}');
  // Le programme reste ouvert : plus tard, il recevra les appels (INVITE).
}

/// Première adresse IPv4 non-loopback de la machine (ex : 192.168.1.20).
Future<String> findLocalIp() async {
  for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
    for (final a in ni.addresses) {
      if (!a.isLoopback) return a.address;
    }
  }
  return '127.0.0.1';
}