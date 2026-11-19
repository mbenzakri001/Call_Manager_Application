import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';

import '../config/sip_config.dart';
import '../core/call_decision.dart';
import '../core/call_decision_engine.dart';
import '../core/call_rules.dart';
import '../core/chat.dart';
import '../core/decision_log.dart';
import '../core/demo_repositories.dart';
import '../core/phone_utils.dart';
import '../core/voicemail.dart';

/// Seul point de contact avec sip_ua : connexion à Asterisk, enregistrement,
/// appels entrants/sortants. L'interface ne fait qu'écouter ce service.
class SipService extends ChangeNotifier
    implements
        SipUaHelperListener,
        CallHistoryRepository,
        UserSettingsRepository {
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
  final DemoCallerLists lists = DemoCallerLists();

  late final CallDecisionEngine engine = CallDecisionEngine(
    contacts: contacts,
    calendar: calendar,
    lists: lists,
    history: this,
    settings: this,
  );

  // Ne pas déranger -----------------------------------------------------------

  bool _doNotDisturb = false;
  bool get doNotDisturbOn => _doNotDisturb;

  set doNotDisturbOn(bool on) {
    _doNotDisturb = on;
    notifyListeners();
  }

  @override
  Future<bool> doNotDisturb() async => _doNotDisturb;

  // Liste noire et favoris ----------------------------------------------------

  bool isBlocked(String number) => lists.blockedSync(number);
  bool isFavorite(String number) => lists.favoriteSync(number);

  void setBlocked(String number, bool blocked) {
    final n = number.trim();
    if (n.isEmpty) return;
    blocked
        ? lists.blocked.add(n)
        : lists.blocked.removeWhere((b) => samePhone(b, n));
    notifyListeners();
  }

  void setFavorite(String number, bool favorite) {
    favorite
        ? lists.favorites.add(number)
        : lists.favorites.removeWhere((f) => samePhone(f, number));
    notifyListeners();
  }

  // Appels répétés ------------------------------------------------------------

  @override
  Future<int> countCallsFrom(String number, DateTime since) async => history
      .where((e) => e.time.isAfter(since) && samePhone(e.callerNumber, number))
      .length;

  /// Canal utilisé pour prévenir l'appelant quand on refuse.
  ResponseMode responseMode = ResponseMode.sms;

  /// Décisions prises, la plus récente en premier (écran Historique).
  final List<DecisionLogEntry> history = [];

  DecisionLogEntry? get lastEntry => history.isEmpty ? null : history.first;

  /// Noms des règles désactivées dans l'onglet Réglages.
  final Set<String> _disabledRules = {};

  bool isRuleEnabled(CallRule rule) => !_disabledRules.contains(rule.name);

  void setRuleEnabled(CallRule rule, bool enabled) {
    if (!rule.canBeDisabled) return;
    enabled ? _disabledRules.remove(rule.name) : _disabledRules.add(rule.name);
    engine.rules = defaultRules.where(isRuleEnabled).toList();
    notifyListeners();
  }

  // Calendrier --------------------------------------------------------------

  /// Rendez-vous en cours, ou null si disponible.
  Appointment? get currentAppointment => calendar.appointmentAt(DateTime.now());

  bool get inMeeting => currentAppointment != null;

  void addAppointment(Appointment appointment) {
    calendar.add(appointment);
    notifyListeners();
  }

  void removeAppointment(Appointment appointment) {
    calendar.remove(appointment);
    notifyListeners();
  }

  /// Raccourci : "je suis en réunion à partir de maintenant".
  void startMeeting(Duration duration) {
    calendar.startMeeting(duration);
    notifyListeners();
  }

  void endMeeting() {
    calendar.endCurrentMeeting();
    notifyListeners();
  }

  // Contacts ----------------------------------------------------------------

  void addContact(String number, String name) {
    contacts.byNumber[number.trim()] = name.trim();
    notifyListeners();
  }

  void removeContact(String number) {
    contacts.byNumber.remove(number);
    lists.favorites.removeWhere((f) => samePhone(f, number));
    notifyListeners();
  }

  /// Nom du contact pour ce numéro, ou null (lecture directe, sans attente).
  String? contactNameFor(String number) {
    for (final e in contacts.byNumber.entries) {
      if (samePhone(e.key, number)) return e.value;
    }
    return null;
  }

  // Historique --------------------------------------------------------------

  // Messages (SIP MESSAGE) ---------------------------------------------------

  /// Conversations par numéro, messages du plus ancien au plus récent.
  final Map<String, List<ChatMessage>> conversations = {};
  final Map<String, int> _unread = {};

  int get unreadMessages => _unread.values.fold(0, (a, b) => a + b);
  int unreadFor(String peer) => _unread[peer] ?? 0;

  void markRead(String peer) {
    if (_unread.remove(peer) != null) notifyListeners();
  }

  /// Conversations triées : la plus récente en premier.
  List<String> get conversationPeers => conversations.keys.toList()
    ..sort((a, b) =>
        conversations[b]!.last.time.compareTo(conversations[a]!.last.time));

  void _addMessage(ChatMessage m) {
    conversations.putIfAbsent(m.peer, () => []).add(m);
    if (m.incoming) _unread[m.peer] = unreadFor(m.peer) + 1;
    notifyListeners();
  }

  /// Envoie un SIP MESSAGE ; Asterisk le relaie au compte [peer].
  void sendText(String peer, String text, {bool automatic = false}) {
    final to = peer.trim();
    final body = text.trim();
    if (to.isEmpty || body.isEmpty) return;

    final message = ChatMessage(
      peer: to,
      text: body,
      time: DateTime.now(),
      incoming: false,
      status: MessageStatus.sending,
      automatic: automatic,
    );
    _addMessage(message);

    if (!isRegistered) {
      message.status = MessageStatus.failed;
      notifyListeners();
      return;
    }
    debugPrint('MESSAGE -> $to : $body');
    final sending =
        _helper.sendMessage('sip:$to@${SipConfig.serverIp}', body);
    sending.on(EventSucceeded(), (EventSucceeded _) {
      message.status = MessageStatus.sent;
      notifyListeners();
    });
    sending.on(EventCallFailed(), (EventCallFailed e) {
      debugPrint('MESSAGE -> $to : échec ${e.cause}');
      message.status = MessageStatus.failed;
      notifyListeners();
    });
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
  }

  DecisionLogEntry _log(String number, CallDecision decision, CallRule rule) {
    final entry = DecisionLogEntry(
      time: DateTime.now(),
      callerNumber: number,
      decision: decision,
      ruleName: rule.name,
    );
    history.insert(0, entry);
    debugPrint(
      'DÉCISION (${rule.name}) : $number -> '
      '${decisionSummary(decision)}',
    );
    notifyListeners();
    return entry;
  }

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
    _localStream ??= await navigator.mediaDevices.getUserMedia(
      <String, dynamic>{'audio': true, 'video': false},
    );
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
    await _helper.call(
      'sip:${target.trim()}@${SipConfig.serverIp}',
      voiceOnly: true,
      mediaStream: stream,
    );
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
    call.hangup(
      statusCode == null
          ? <String, dynamic>{}
          : <String, dynamic>{'status_code': statusCode},
    );
  }

  /// Envoie une touche du clavier pendant l'appel (tonalité DTMF), par
  /// exemple pour naviguer dans la messagerie vocale.
  void sendDtmf(String tone) {
    final call = currentCall;
    if (call == null || isRinging) return;
    call.sendDTMF(tone);
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
    final result = await engine.decideWithRule(number, responseMode);

    // L'appelant a pu raccrocher pendant l'analyse.
    if (call.state == CallStateEnum.ENDED ||
        call.state == CallStateEnum.FAILED) {
      return;
    }

    _log(number, result.decision, result.rule);

    // Refus : code SIP visible côté appelant (603 Decline, 486 Busy Here).
    final code = sipRejectCode(result.decision);
    if (code != null) {
      call.hangup(<String, dynamic>{'status_code': code});
    }

    // SMS automatique à l'appelant refusé (idée d'Halima) : le message prévu
    // par la décision ("en rendez-vous jusqu'à 15h30"…). Rien pour un numéro
    // bloqué.
    final sms = callerMessage(result.decision);
    if (code != null && sms != null) {
      sendText(number, sms, automatic: true);
    }
  }

  // --- SipUaHelperListener ---------------------------------------------------

  @override
  void transportStateChanged(TransportState state) {
    transportState = state.state;
    if (state.state == TransportStateEnum.CONNECTED) {
      lastError = null; // reconnecté : l'ancienne erreur n'est plus valable
    } else if (state.cause != null) {
      lastError = state.cause.toString();
    }
    // Connexion perdue : l'abonnement à la messagerie est à refaire.
    if (state.state == TransportStateEnum.DISCONNECTED) {
      _voicemailSubscribed = false;
    }
    notifyListeners();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    registrationState = state.state ?? RegistrationStateEnum.NONE;
    lastError = registrationState == RegistrationStateEnum.REGISTRATION_FAILED
        ? state.cause.toString()
        : null;
    if (isRegistered && !_voicemailSubscribed) _subscribeVoicemail();
    notifyListeners();
  }

  // Messagerie vocale ---------------------------------------------------------

  /// Messages vocaux en attente sur la boîte du compte (via MWI).
  VoicemailCount voicemail = const VoicemailCount(0, 0);
  bool _voicemailSubscribed = false;

  /// Demande à Asterisk de prévenir l'app des nouveaux messages vocaux.
  void _subscribeVoicemail() {
    _voicemailSubscribed = true;
    _helper.subscribe(SipConfig.sipUri, 'message-summary',
        'application/simple-message-summary');
  }

  /// Appelle la messagerie pour écouter ses messages.
  Future<void> callVoicemail() => call(voicemailNumber);

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
  void onNewMessage(SIPMessageRequest msg) {
    final dynamic request = msg.request;
    final peer = msg.message?.remote_identity?.uri?.user ?? '';
    final String? contentType = request?.getHeader('content-type')?.toString();
    final String? body = request?.body as String?;
    final text = extractMessageText(contentType, body);

    debugPrint('MESSAGE <- $peer ($contentType) : $body');
    if (peer.isEmpty || text == null || text.isEmpty) return;
    // Un numéro en liste noire ne peut pas non plus écrire.
    if (isBlocked(peer)) return;

    _addMessage(ChatMessage(
      peer: peer,
      text: text,
      time: DateTime.now(),
      incoming: true,
      status: MessageStatus.received,
    ));
  }

  @override
  void onNewNotify(Notify ntf) {
    final count = parseMessageSummary(ntf.request?.body);
    debugPrint('MWI : ${ntf.request?.body}');
    if (count == null) return;
    voicemail = count;
    notifyListeners();
  }

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
