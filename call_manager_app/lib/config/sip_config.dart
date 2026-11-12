/// Paramètres de connexion au serveur Asterisk.
///
/// L'IP est celle du PC qui fait tourner Asterisk (IP Wi-Fi). Elle doit être
/// la même que dans asterisk/config/pjsip.conf et rtp.conf.
class SipConfig {
  static const String serverIp = '192.168.55.12';

  /// Serveur HTTP d'Asterisk (http.conf) : SIP sur WebSocket.
  static const String webSocketUrl = 'ws://$serverIp:8088/ws';

  /// Compte de l'app, déclaré dans pjsip.conf (section [1003]).
  static const String user = '1003';
  static const String password = 'Labo1003';
  static const String displayName = 'Call Manager';

  static const String sipUri = 'sip:$user@$serverIp';
}
