import 'dart:convert';
import 'dart:math';

/// Un message SIP (requête ou réponse) : ligne de départ + en-têtes + corps.
class SipMessage {
  SipMessage({required this.startLine, required this.headers, this.body = ''});

  /// "REGISTER sip:... SIP/2.0" ou "SIP/2.0 200 OK"
  final String startLine;

  /// Liste (et non Map) : l'ordre compte et un en-tête peut apparaître
  /// plusieurs fois (ex : plusieurs Via quand le message traverse un proxy).
  final List<MapEntry<String, String>> headers;

  final String body;

  /// Une réponse commence par "SIP/2.0", une requête par sa méthode.
  bool get isRequest => !startLine.startsWith('SIP/2.0');

  /// Méthode de la requête, ou méthode à laquelle répond une réponse (via CSeq).
  String get method => isRequest
      ? startLine.split(' ').first
      : (header('CSeq') ?? '').split(' ').last;

  /// Code de réponse (200, 404…), null pour une requête.
  int? get statusCode =>
      isRequest ? null : int.tryParse(startLine.split(' ')[1]);

  /// SIP autorise des noms courts : "v" = Via, "f" = From, etc.
  static const _compact = {
    'v': 'via',
    'f': 'from',
    't': 'to',
    'i': 'call-id',
    'm': 'contact',
    'l': 'content-length',
    'c': 'content-type',
  };

  static String canonical(String name) {
    final n = name.toLowerCase();
    return _compact[n] ?? n;
  }

  /// Premier en-tête portant ce nom (insensible à la casse), ou null.
  String? header(String name) {
    final wanted = canonical(name);
    for (final h in headers) {
      if (canonical(h.key) == wanted) return h.value;
    }
    return null;
  }

  /// Analyse un message brut reçu sur le réseau.
  factory SipMessage.parse(String raw) {
    final text = raw.replaceAll('\r\n', '\n');
    final sep = text.indexOf('\n\n'); // ligne vide = fin des en-têtes
    final head = sep >= 0 ? text.substring(0, sep) : text;
    final body = sep >= 0 ? text.substring(sep + 2) : '';

    final lines = head.split('\n');
    final headers = <MapEntry<String, String>>[];
    for (final line in lines.skip(1)) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      headers.add(
        MapEntry(line.substring(0, i).trim(), line.substring(i + 1).trim()),
      );
    }
    return SipMessage(
      startLine: lines.first.trim(),
      headers: headers,
      body: body,
    );
  }

  /// Transforme le message en texte prêt à envoyer (fins de ligne CRLF).
  String serialize() {
    final b = StringBuffer('$startLine\r\n');
    for (final h in headers) {
      if (canonical(h.key) == 'content-length') continue; // recalculé
      b.write('${h.key}: ${h.value}\r\n');
    }
    b.write('Content-Length: ${utf8.encode(body).length}\r\n\r\n');
    b.write(body);
    return b.toString();
  }
}

/// Chaîne aléatoire pour les tags, branch et Call-ID.
String randomToken([int length = 10]) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Extrait l'utilisateur d'une URI : "<sip:1001@192.168.1.20>" -> "1001".
String? uriUser(String value) =>
    RegExp(r'sips?:([^@;>\s]+)@').firstMatch(value)?.group(1);