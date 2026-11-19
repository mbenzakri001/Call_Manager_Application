// Messages texte échangés par SIP MESSAGE (le "SMS" de la téléphonie IP).
// Asterisk les relaie entre comptes via le contexte [messages].

enum MessageStatus { received, sending, sent, failed }

class ChatMessage {
  ChatMessage({
    required this.peer,
    required this.text,
    required this.time,
    required this.incoming,
    required this.status,
    this.automatic = false,
  });

  /// Numéro de l'interlocuteur (ex : "1001").
  final String peer;
  final String text;
  final DateTime time;
  final bool incoming;

  /// Évolue pour un message envoyé : sending -> sent / failed.
  MessageStatus status;

  /// Réponse envoyée automatiquement par le call manager (appel refusé).
  final bool automatic;
}

/// Extrait le texte d'un MESSAGE reçu, ou null s'il n'est pas à afficher.
///
/// Linphone peut envoyer du texte simple (text/plain), du texte emballé en
/// CPIM (message/cpim), ou des accusés de lecture (IMDN) qu'on ignore.
String? extractMessageText(String? contentType, String? body) {
  final type = (contentType ?? 'text/plain').toLowerCase();
  final text = body ?? '';
  if (type.contains('imdn')) return null;
  if (type.contains('cpim')) {
    if (text.contains('imdn+xml')) return null;
    // CPIM = en-têtes, ligne vide, en-têtes du contenu, ligne vide, texte.
    final normalized = text.replaceAll('\r\n', '\n');
    final i = normalized.lastIndexOf('\n\n');
    return i < 0 ? normalized.trim() : normalized.substring(i + 2).trim();
  }
  if (type.startsWith('text/')) return text.trim();
  return null;
}
