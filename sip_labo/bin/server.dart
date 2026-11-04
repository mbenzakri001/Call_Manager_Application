import 'dart:convert';
import 'dart:io';

import 'package:sip_labo/sip_message.dart';

/// Où joindre un utilisateur enregistré.
class Registration {
  Registration(this.address, this.port, this.contact, this.expiresAt);
  final InternetAddress address; // IP source réelle du paquet
  final int port; // port source réel du paquet
  final String contact; // ce que le client a déclaré dans Contact
  final DateTime expiresAt;
}

/// Table de localisation : "1001" -> Registration
final registrations = <String, Registration>{};

const sipPort = 5060;

Future<void> main() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, sipPort);
  print('Serveur SIP en écoute sur UDP 0.0.0.0:$sipPort');

  socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final dg = socket.receive();
    if (dg == null) return;

    final raw = utf8.decode(dg.data, allowMalformed: true);
    if (raw.trim().isEmpty) return; // "keep-alive" envoyé par certains clients

    final msg = SipMessage.parse(raw);
    print('<<< ${dg.address.address}:${dg.port}  ${msg.startLine}');

    if (!msg.isRequest) return; // pas de réponses à traiter à cette étape

    switch (msg.method) {
      case 'REGISTER':
        handleRegister(socket, msg, dg);
      case 'ACK':
        break; // on ne répond jamais à un ACK
      default:
        send(socket, buildResponse(msg, dg, 501, 'Not Implemented'),
            dg.address, dg.port);
    }
  });
}

void handleRegister(RawDatagramSocket socket, SipMessage req, Datagram dg) {
  final user = uriUser(req.header('To') ?? '');
  final contact = req.header('Contact');

  if (user == null || contact == null) {
    send(socket, buildResponse(req, dg, 400, 'Bad Request'), dg.address, dg.port);
    return;
  }

  // Durée demandée : en-tête Expires, sinon paramètre ;expires= du Contact.
  final fromParam = RegExp(r';\s*expires=(\d+)').firstMatch(contact)?.group(1);
  final expires = int.tryParse(req.header('Expires') ?? '') ??
      int.tryParse(fromParam ?? '') ??
      3600;

  if (expires == 0 || contact == '*') {
    registrations.remove(user); // Expires: 0 = désenregistrement
    print('*** $user désenregistré');
  } else {
    registrations[user] = Registration(
      dg.address,
      dg.port,
      contact,
      DateTime.now().add(Duration(seconds: expires)),
    );
    print('*** $user enregistré -> ${dg.address.address}:${dg.port}');
  }

  final cleanContact = contact.replaceAll(RegExp(r';\s*expires=\d+'), '');
  send(
    socket,
    buildResponse(req, dg, 200, 'OK', [
      MapEntry('Contact', '$cleanContact;expires=$expires'),
      MapEntry('Expires', '$expires'),
    ]),
    dg.address,
    dg.port,
  );
  printTable();
}

/// Construit une réponse en recopiant les en-têtes obligatoires de la requête.
SipMessage buildResponse(
  SipMessage req,
  Datagram from,
  int code,
  String reason, [
  List<MapEntry<String, String>> extra = const [],
]) {
  final headers = <MapEntry<String, String>>[];
  var firstVia = true;

  for (final h in req.headers) {
    switch (SipMessage.canonical(h.key)) {
      case 'via':
        headers.add(MapEntry(
          'Via',
          firstVia ? stampVia(h.value, from.address, from.port) : h.value,
        ));
        firstVia = false;
      case 'from':
        headers.add(MapEntry('From', h.value));
      case 'to':
        // Le serveur ajoute son propre tag dans To.
        final to = h.value.contains('tag=')
            ? h.value
            : '${h.value};tag=${randomToken()}';
        headers.add(MapEntry('To', to));
      case 'call-id':
        headers.add(MapEntry('Call-ID', h.value));
      case 'cseq':
        headers.add(MapEntry('CSeq', h.value));
    }
  }

  headers.addAll(extra);
  headers.add(const MapEntry('Server', 'DartSIP-Labo'));
  return SipMessage(startLine: 'SIP/2.0 $code $reason', headers: headers);
}

/// Ajoute au Via l'adresse réellement vue (received / rport, RFC 3581).
/// Utile quand le client est derrière un NAT et ignore sa vraie adresse.
String stampVia(String via, InternetAddress addr, int port) {
  var v = via.replaceFirst(RegExp(r';rport(?=;|$)'), ';rport=$port');
  if (!v.contains('received=')) v = '$v;received=${addr.address}';
  return v;
}

void send(RawDatagramSocket socket, SipMessage msg, InternetAddress addr, int port) {
  socket.send(utf8.encode(msg.serialize()), addr, port);
  print('>>> ${addr.address}:$port  ${msg.startLine}');
}

void printTable() {
  print('--- Utilisateurs enregistrés ---');
  registrations.forEach((user, r) {
    print('  $user -> ${r.address.address}:${r.port}  (expire à ${r.expiresAt})');
  });
}