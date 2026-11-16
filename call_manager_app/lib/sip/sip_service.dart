import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';

import '../config/sip_config.dart';
import '../core/call_decision.dart';
import '../core/call_decision_engine.dart';
import '../core/demo_repositories.dart';

/// Seul point de contact avec sip_ua : connexion à Asterisk, enregistrement,
/// appels entrants/sortants. L'interface ne fait qu'écouter ce service.
class SipService extends ChangeNotifier implements SipUaHelperListener {
  final SIPUAHelper _helper = SIPUAHelper();

  TransportStateEnum transportState = TransportStateEnum.NONE;
  RegistrationStateEnum registrationState = RegistrationStateEnum.NONE;
  String? lastError;

  /// Appel en cours (un seul à la fois pour l'instant).
  Call? currentCall;
  CallStateEnum callState = CallStateEnum.NONE;
  bool speakerOn = false;

  MediaStream? _localStream;

  // --- Moteur de décision (call manager) ------------------------------------

  /// Contacts et calendrier de démo (remplacés plus tard par les vrais).
  final DemoContacts contacts = DemoContacts();
  final DemoCalendar calendar = DemoCalendar();

  late final CallDecisionEngine engine =
      CallDecisionEngine(contacts: contacts, calendar: calendar);

  /// Canal utilisé pour prévenir l'appelant quand on refuse.
  ResponseMode responseMode = ResponseMode.sms;

  /// Texte de la dernière décision prise (affiché pour la démo).
  String? lastDecision;

  /// Permet à l'interface de demander un rafraîchissement.
  void refresh() => notifyListeners();

  // ---------------------------------------------------------------------------

  bool get isRegistered =>
      registrationState == RegistrationStateEnum.REGISTERED;

  /// Appel entrant qui sonne encore (pas encore décroché).
  bool get isRinging =>
      currentCall != null &&
      currentCall!.direction == Direction.incoming &&
      (callState == CallStateEnum.CALL_INITIATION ||
          callState == CallStateEnum.PROGRESS);

  Future<void> start() async {
    final settings = UaSettings()
      ..transportType = TransportType.WS
      ..webSocketUrl = SipConfig.webSocketUrl
      ..uri = SipConfig.sipUri
      ..host = SipConfig.serverIp
      ..authorizationUser = SipConfig.user
      ..password = SipConfig.password
      ..displayName = SipConfig.displayName
      ..userAgent = 'ITEC4 Call Manager'
      ..dtmfMode = DtmfMode.RFC2833
      // Réseau local uniquement : pas besoin de serveur STUN public.
      ..iceServers = <Map<String, String>>[];

    _helper.addSipUaHelperListener(this);
    await _helper.start(settings);
  }

  void stop() {
    _helper.removeSipUaHelperListener(this);
    _helper.stop();
  }

  Future<MediaStream> _openMicrophone() async {
    _localStream ??= await navigator.mediaDevices
        .getUserMedia(<String, dynamic>{'audio': true, 'video': false});
    return _localStream!;
  }

  Future<void> _closeMicrophone() async {
    final stream = _localStream;
    _localStream = null;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  /// Appel sortant (ex : "600" pour le test d'écho).
  Future<void> call(String target) async {
    if (target.trim().isEmpty || currentCall != null) return;
    final stream = await _openMicrophone();
    await _helper.call('sip:${target.trim()}@${SipConfig.serverIp}',
        voiceOnly: true, mediaStream: stream);
  }

  Future<void> answer() async {
    final call = currentCall;
    if (call == null) return;
    final stream = await _openMicrophone();
    call.answer(_helper.buildCallOptions(true), mediaStream: stream);
  }

  /// Raccroche, ou refuse un appel entrant avec un code SIP
  /// (486 Busy Here, 603 Decline…), visible côté appelant.
  void hangup({int? statusCode}) {
    final call = currentCall;
    if (call == null) return;
    call.hangup(statusCode == null
        ? <String, dynamic>{}
        : <String, dynamic>{'status_code': statusCode});
  }

  void toggleSpeaker() {
    speakerOn = !speakerOn;
    Helper.setSpeakerphoneOn(speakerOn);
    notifyListeners();
  }

  /// Interroge le moteur de décision pour un appel entrant, puis applique
  /// la décision : laisser sonner, ou refuser automatiquement.
  Future<void> _applyDecision(Call call) async {
    final number = call.remote_identity ?? '';
    final decision = await engine.decide(number, responseMode);

    // L'appelant a pu raccrocher pendant l'analyse.
    if (call.state == CallStateEnum.ENDED ||
        call.state == CallStateEnum.FAILED) {
      return;
    }

    switch (decision) {
      case LetRing(:final contactName):
        lastDecision =
            '$contactName ($number) : contact connu et disponible -> sonnerie';

      case RejectUnknown():
        lastDecision = '$number : numéro inconnu -> refusé automatiquement (603)';
        call.hangup(<String, dynamic>{'status_code': 603}); // Decline

      case RejectBusy(:final contactName, :final appointment):
        lastDecision = '$contactName ($number) : en rendez-vous jusqu\'à '
            '${formatHour(appointment.end)} -> refusé automatiquement (486)';
        call.hangup(<String, dynamic>{'status_code': 486}); // Busy Here
    }

    debugPrint('DÉCISION : $lastDecision');
    notifyListeners();
  }

  // --- SipUaHelperListener ---------------------------------------------------

  @override
  void transportStateChanged(TransportState state) {
    transportState = state.state;
    if (state.cause != null) lastError = state.cause.toString();
    notifyListeners();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    registrationState = state.state ?? RegistrationStateEnum.NONE;
    lastError = registrationState == RegistrationStateEnum.REGISTRATION_FAILED
        ? state.cause.toString()
        : null;
    notifyListeners();
  }

  @override
  void callStateChanged(Call call, CallState state) {
    debugPrint('Appel ${call.id} (${call.remote_identity}) : ${state.state}');

    // Un seul appel à la fois : on refuse un second appel entrant.
    if (currentCall != null && call.id != currentCall!.id) {
      if (state.state == CallStateEnum.CALL_INITIATION &&
          call.direction == Direction.incoming) {
        call.hangup(<String, dynamic>{'status_code': 486});
      }
      return;
    }

    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        currentCall = call;
        callState = state.state;
        // Moteur de décision : uniquement pour les appels entrants.
        if (call.direction == Direction.incoming) {
          _applyDecision(call);
        }
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        if (state.cause?.status_code != null &&
            state.state == CallStateEnum.FAILED) {
          lastError = state.cause.toString();
        }
        currentCall = null;
        callState = CallStateEnum.NONE;
        if (speakerOn) toggleSpeaker();
        _closeMicrophone();
      case CallStateEnum.STREAM:
      case CallStateEnum.MUTED:
      case CallStateEnum.UNMUTED:
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
      case CallStateEnum.REFER:
        // Événements média/annexes : ne changent pas l'étape de l'appel.
        break;
      default:
        callState = state.state;
    }
    notifyListeners();
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}

  @override
  void onNewInfo(SipInfo info) {}

  @override
  void dispose() {
    stop();
    _closeMicrophone();
    super.dispose();
  }
}