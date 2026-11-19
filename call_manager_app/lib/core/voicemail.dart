// Messagerie vocale : numéro de consultation et lecture des notifications
// "nouveau message vocal" (MWI) envoyées par Asterisk.

/// Numéro à appeler pour écouter ses messages (extensions.conf).
const String voicemailNumber = '8000';

/// Nombre de messages vocaux nouveaux et déjà écoutés.
class VoicemailCount {
  const VoicemailCount(this.newMessages, this.oldMessages);
  final int newMessages;
  final int oldMessages;
}

/// Lit le corps d'une notification MWI (application/simple-message-summary) :
///   Messages-Waiting: yes
///   Voice-Message: 2/1 (0/0)      -> 2 nouveaux, 1 ancien
VoicemailCount? parseMessageSummary(String? body) {
  if (body == null) return null;
  final m = RegExp(r'Voice-Message:\s*(\d+)/(\d+)', caseSensitive: false)
      .firstMatch(body);
  if (m == null) {
    // Pas de détail : seulement "Messages-Waiting: yes/no".
    final waiting =
        RegExp(r'Messages-Waiting:\s*yes', caseSensitive: false).hasMatch(body);
    return VoicemailCount(waiting ? 1 : 0, 0);
  }
  return VoicemailCount(int.parse(m.group(1)!), int.parse(m.group(2)!));
}
