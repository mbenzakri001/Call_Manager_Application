// Modèle de décision

/// Comment on prévient l'appelant quand on ne prend pas l'appel.
enum ResponseMode { audio, sms }

/// Un rendez-vous lu dans le calendrier.
class Appointment {
  const Appointment({this.title, required this.start, required this.end});

  final String? title;
  final DateTime start;
  final DateTime end;
}

/// Résultat de l'analyse d'un appel entrant.
sealed class CallDecision {
  const CallDecision(this.callerNumber);
  final String callerNumber;
}

/// Contact connu et disponible : on laisse sonner normalement.
class LetRing extends CallDecision {
  const LetRing(super.callerNumber, this.contactName);
  final String contactName;
}

/// Contact connu mais en rendez-vous : on refuse en indiquant l'heure de fin.
class RejectBusy extends CallDecision {
  const RejectBusy(
    super.callerNumber,
    this.contactName,
    this.appointment,
    this.mode,
    this.message,
  );
  final String contactName;
  final Appointment appointment;
  final ResponseMode mode;
  final String message;
}

/// Numéro en liste noire : refus sec, sans message.
class RejectBlocked extends CallDecision {
  const RejectBlocked(super.callerNumber, {this.contactName});
  final String? contactName;
}

/// Mode "Ne pas déranger" activé : refus avec un message.
class RejectDoNotDisturb extends CallDecision {
  const RejectDoNotDisturb(
    super.callerNumber,
    this.message, {
    this.contactName,
  });
  final String? contactName;
  final String message;
}

/// Formate une heure en "14h30".
String formatHour(DateTime t) =>
    '${t.hour}h${t.minute.toString().padLeft(2, '0')}';

/// Textes envoyés à l'appelant.
class Messages {
  static String busy(String contactName, DateTime until) {
    final firstName = contactName.trim().split(RegExp(r'\s+')).first;
    final hello = firstName.isEmpty ? 'Bonjour' : 'Bonjour $firstName';
    return "$hello, je suis en rendez-vous jusqu'à ${formatHour(until)}. "
        "Laissez-moi un message vocal, je vous rappelle dès que possible.";
  }

  static String doNotDisturb(String? contactName) {
    final firstName = (contactName ?? '').trim().split(RegExp(r'\s+')).first;
    final hello = firstName.isEmpty ? 'Bonjour' : 'Bonjour $firstName';
    return "$hello, je ne suis pas disponible pour le moment. "
        "Laissez-moi un message vocal, ou rappelez dans les 30 secondes "
        "si c'est urgent.";
  }
}
