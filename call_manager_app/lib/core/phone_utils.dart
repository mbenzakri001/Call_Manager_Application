// Compare l'identité SIP de l'appelant ("sip:+33612345678@pbx" ou "1001")
// avec les numéros des contacts ("06 12 34 56 78").

/// Ne garde que les chiffres, retire "sip:" / le domaine, convertit +33 en 0.
String normalizePhone(String raw) {
  var s = raw.trim();
  s = s.replaceFirst(RegExp(r'^sips?:'), '');
  final at = s.indexOf('@');
  if (at >= 0) s = s.substring(0, at);

  final hasPlus = s.startsWith('+');
  var digits = s.replaceAll(RegExp(r'\D'), '');

  if (hasPlus && digits.startsWith('33')) {
    digits = '0${digits.substring(2)}';
  } else if (digits.startsWith('0033')) {
    digits = '0${digits.substring(4)}';
  }
  return digits;
}

/// Vrai si deux numéros désignent la même ligne :
/// égalité stricte (extensions courtes "1001"), sinon 9 derniers chiffres.
bool samePhone(String a, String b) {
  final x = normalizePhone(a);
  final y = normalizePhone(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  if (x.length >= 9 && y.length >= 9) {
    return x.substring(x.length - 9) == y.substring(y.length - 9);
  }
  return false;
}