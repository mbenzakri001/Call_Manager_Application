import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';

import 'config/sip_config.dart';
import 'sip/sip_service.dart';

void main() {
  runApp(const CallManagerApp());
}

class CallManagerApp extends StatelessWidget {
  const CallManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Manager',
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
  final TextEditingController _target = TextEditingController(text: '600');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // L'autorisation micro est demandée par flutter_webrtc au premier
    // décroché ou au premier appel sortant.
    await _sip.start();
  }

  @override
  void dispose() {
    _sip.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call Manager')),
      body: ListenableBuilder(
        listenable: _sip,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(sip: _sip),
            const SizedBox(height: 16),
            if (_sip.currentCall == null)
              _DialPanel(sip: _sip, target: _target)
            else
              _CallPanel(sip: _sip),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.sip});
  final SipService sip;

  @override
  Widget build(BuildContext context) {
    final registered = sip.isRegistered;
    return Card(
      child: ListTile(
        leading: Icon(
          registered ? Icons.check_circle : Icons.error_outline,
          color: registered ? Colors.green : Colors.orange,
        ),
        title: Text('${SipConfig.displayName} (${SipConfig.user})'),
        subtitle: Text(
          'Transport : ${sip.transportState.name}\n'
          'Enregistrement : ${sip.registrationState.name}'
          '${sip.lastError != null ? '\nErreur : ${sip.lastError}' : ''}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _DialPanel extends StatelessWidget {
  const _DialPanel({required this.sip, required this.target});
  final SipService sip;
  final TextEditingController target;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: target,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro (600 = écho, 1001, 1002)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: sip.isRegistered ? () => sip.call(target.text) : null,
          icon: const Icon(Icons.call),
          label: const Text('Appeler'),
        ),
      ],
    );
  }
}

class _CallPanel extends StatelessWidget {
  const _CallPanel({required this.sip});
  final SipService sip;

  @override
  Widget build(BuildContext context) {
    final call = sip.currentCall!;
    final incoming = call.direction == Direction.incoming;
    final name = call.remote_display_name ?? '';
    final number = call.remote_identity ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              sip.isRinging
                  ? 'Appel entrant'
                  : incoming
                      ? 'Appel reçu'
                      : 'Appel sortant',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(name.isNotEmpty ? name : number,
                style: Theme.of(context).textTheme.headlineMedium),
            if (name.isNotEmpty) Text(number),
            const SizedBox(height: 8),
            Text('État : ${sip.callState.name}'),
            const SizedBox(height: 24),
            if (sip.isRinging)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.red),
                    // 603 Decline : l'appelant voit un refus explicite.
                    onPressed: () => sip.hangup(statusCode: 603),
                    icon: const Icon(Icons.call_end),
                    label: const Text('Refuser'),
                  ),
                  FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: sip.answer,
                    icon: const Icon(Icons.call),
                    label: const Text('Décrocher'),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filledTonal(
                    onPressed: sip.toggleSpeaker,
                    icon: Icon(
                        sip.speakerOn ? Icons.volume_up : Icons.hearing),
                    tooltip: 'Haut-parleur',
                  ),
                  FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: sip.hangup,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Raccrocher'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
