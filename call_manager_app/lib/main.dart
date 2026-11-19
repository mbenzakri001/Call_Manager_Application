import 'package:flutter/material.dart';

import 'sip/sip_service.dart';
import 'ui/calendar_page.dart';
import 'ui/call_view.dart';
import 'ui/contacts_page.dart';
import 'ui/history_page.dart';
import 'ui/messages_page.dart';
import 'ui/phone_page.dart';
import 'ui/settings_page.dart';

void main() {
  runApp(const CallManagerApp());
}

class CallManagerApp extends StatelessWidget {
  const CallManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SipService _sip = SipService();
  static const _historyTab = 4;
  static const _titles = [
    'Téléphone',
    'Contacts',
    'Calendrier',
    'Messages',
    'Historique',
    'Réglages',
  ];

  int _tab = 0;
  int _seenDecisions = 0;

  @override
  void initState() {
    super.initState();
    // L'autorisation micro est demandée par flutter_webrtc au premier
    // décroché ou au premier appel sortant.
    _sip.addListener(_closeScreensOnIncomingCall);
    _sip.start();
  }

  bool _wasInCall = false;

  /// Un appel arrive pendant qu'une conversation est ouverte : on revient à
  /// l'écran principal, qui affiche l'écran d'appel.
  void _closeScreensOnIncomingCall() {
    final inCall = _sip.currentCall != null;
    if (inCall && !_wasInCall && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _wasInCall = inCall;
  }

  @override
  void dispose() {
    _sip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sip,
      builder: (context, _) {
        final inCall = _sip.currentCall != null;
        if (_tab == _historyTab) _seenDecisions = _sip.history.length;
        final unseen = _sip.history.length - _seenDecisions;

        return Scaffold(
          appBar: AppBar(
            title: Text(inCall ? 'Call Manager' : _titles[_tab]),
            actions: [
              if (_sip.doNotDisturbOn)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: 'Ne pas déranger activé',
                    child: Icon(
                      Icons.do_not_disturb_on,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  Icons.circle,
                  size: 14,
                  color: _sip.isRegistered ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          // Pendant un appel, l'écran d'appel remplace les onglets.
          body: inCall
              ? CallView(sip: _sip)
              : IndexedStack(
                  index: _tab,
                  children: [
                    PhonePage(sip: _sip),
                    ContactsPage(sip: _sip),
                    CalendarPage(sip: _sip),
                    MessagesPage(sip: _sip),
                    HistoryPage(sip: _sip),
                    SettingsPage(sip: _sip),
                  ],
                ),
          bottomNavigationBar: inCall
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  // 6 onglets : libellé seulement sous l'onglet actif.
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.phone_outlined),
                      selectedIcon: Icon(Icons.phone),
                      label: 'Téléphone',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.contacts_outlined),
                      selectedIcon: Icon(Icons.contacts),
                      label: 'Contacts',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Calendrier',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: _sip.unreadMessages > 0,
                        label: Text('${_sip.unreadMessages}'),
                        child: const Icon(Icons.chat_bubble_outline),
                      ),
                      selectedIcon: const Icon(Icons.chat_bubble),
                      label: 'Messages',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: unseen > 0,
                        label: Text('$unseen'),
                        child: const Icon(Icons.history),
                      ),
                      label: 'Historique',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: 'Réglages',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
