import 'package:flutter/material.dart';

import 'sip/sip_service.dart';
import 'ui/calendar_page.dart';
import 'ui/call_view.dart';
import 'ui/contacts_page.dart';
import 'ui/history_page.dart';
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
  static const _historyTab = 3;
  static const _titles = [
    'Téléphone',
    'Contacts',
    'Calendrier',
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
    _sip.start();
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
                    HistoryPage(sip: _sip),
                    SettingsPage(sip: _sip),
                  ],
                ),
          bottomNavigationBar: inCall
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: [
                    const NavigationDestination(
                        icon: Icon(Icons.phone_outlined),
                        selectedIcon: Icon(Icons.phone),
                        label: 'Téléphone'),
                    const NavigationDestination(
                        icon: Icon(Icons.contacts_outlined),
                        selectedIcon: Icon(Icons.contacts),
                        label: 'Contacts'),
                    const NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: 'Calendrier'),
                    NavigationDestination(
                        icon: Badge(
                          isLabelVisible: unseen > 0,
                          label: Text('$unseen'),
                          child: const Icon(Icons.history),
                        ),
                        label: 'Historique'),
                    const NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: 'Réglages'),
                  ],
                ),
        );
      },
    );
  }
}
