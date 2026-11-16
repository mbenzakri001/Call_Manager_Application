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

/// Numéro absent des contacts : on refuse et on demande un SMS.
class RejectUnknown extends CallDecision {
  const RejectUnknown(super.callerNumber, this.mode, this.message);
  final ResponseMode mode;
  final String message;
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

/// Formate une heure en "14h30".
String formatHour(DateTime t) =>
    '${t.hour}h${t.minute.toString().padLeft(2, '0')}';

/// Textes envoyés à l'appelant.
class Messages {
  static String unknownCaller() =>
      "Bonjour, je ne connais pas votre numéro et je ne prends donc pas "
      "votre appel. Merci de me laisser un SMS en précisant qui vous êtes "
      "et l'objet de votre appel.";

  static String busy(String contactName, DateTime until) {
    final firstName = contactName.trim().split(RegExp(r'\s+')).first;
    final hello = firstName.isEmpty ? 'Bonjour' : 'Bonjour $firstName';
    return "$hello, je suis en rendez-vous jusqu'à ${formatHour(until)}. "
        "Je vous rappelle dès que possible.";
  }
}