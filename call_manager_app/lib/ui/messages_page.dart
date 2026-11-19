import 'package:flutter/material.dart';

import '../core/call_decision.dart';
import '../core/chat.dart';
import '../sip/sip_service.dart';

/// Ouvre la conversation avec [peer] par-dessus les onglets.
void openConversation(BuildContext context, SipService sip, String peer) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ConversationPage(sip: sip, peer: peer),
  ));
}

/// Onglet Messages : une ligne par interlocuteur, la plus récente en haut.
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key, required this.sip});
  final SipService sip;

  Future<void> _newMessage(BuildContext context) async {
    final peer = await showDialog<String>(
        context: context, builder: (_) => const _NewMessageDialog());
    if (peer != null && context.mounted) openConversation(context, sip, peer);
  }

  @override
  Widget build(BuildContext context) {
    final peers = sip.conversationPeers;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newMessage(context),
        icon: const Icon(Icons.edit),
        label: const Text('Nouveau'),
      ),
      body: peers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 64, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun message.\nLes messages envoyés depuis Linphone '
                      'au 1003 apparaîtront ici.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final peer in peers) _ConversationTile(sip: sip, peer: peer),
              ],
            ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.sip, required this.peer});
  final SipService sip;
  final String peer;

  @override
  Widget build(BuildContext context) {
    final last = sip.conversations[peer]!.last;
    final name = sip.contactNameFor(peer);
    final unread = sip.unreadFor(peer);
    final bold = unread > 0 ? const TextStyle(fontWeight: FontWeight.bold) : null;

    return ListTile(
      leading: CircleAvatar(child: Text((name ?? peer)[0])),
      title: Text(name ?? peer, style: bold),
      subtitle: Text(
        '${last.incoming ? '' : 'Vous : '}${last.text}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: bold,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatHour(last.time), style: Theme.of(context).textTheme.bodySmall),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Badge(label: Text('$unread')),
          ],
        ],
      ),
      onTap: () => openConversation(context, sip, peer),
    );
  }
}

/// Fil de discussion avec un numéro, et zone de saisie pour répondre.
class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.sip, required this.peer});
  final SipService sip;
  final String peer;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    widget.sip.sendText(widget.peer, _text.text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.sip,
      builder: (context, _) {
        final sip = widget.sip;
        final messages = sip.conversations[widget.peer] ?? const [];
        // Conversation ouverte : ses messages sont lus.
        if (sip.unreadFor(widget.peer) > 0) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => sip.markRead(widget.peer));
        }
        final name = sip.contactNameFor(widget.peer);

        return Scaffold(
          appBar: AppBar(
            title: Text(name ?? widget.peer),
            actions: [
              IconButton(
                tooltip: 'Appeler',
                icon: const Icon(Icons.call),
                onPressed:
                    sip.isRegistered ? () => sip.call(widget.peer) : null,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  reverse: true, // les plus récents en bas, collés à la saisie
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final m in messages.reversed) _Bubble(message: m),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Envoyer',
                        onPressed: _text.text.trim().isEmpty ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    final mine = !message.incoming;
    final statusIcon = switch (message.status) {
      MessageStatus.sending => Icons.schedule,
      MessageStatus.sent => Icons.done,
      MessageStatus.failed => Icons.error_outline,
      MessageStatus.received => null,
    };

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.automatic)
              Text('Réponse automatique',
                  style: small?.copyWith(fontStyle: FontStyle.italic)),
            Text(message.text),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatHour(message.time), style: small),
                if (statusIcon != null) ...[
                  const SizedBox(width: 4),
                  Icon(statusIcon,
                      size: 14,
                      color: message.status == MessageStatus.failed
                          ? Colors.red
                          : null),
                ],
              ],
            ),
            if (message.status == MessageStatus.failed)
              Text('Non envoyé', style: small?.copyWith(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

/// Saisie du numéro pour un nouveau message.
class _NewMessageDialog extends StatefulWidget {
  const _NewMessageDialog();

  @override
  State<_NewMessageDialog> createState() => _NewMessageDialogState();
}

class _NewMessageDialogState extends State<_NewMessageDialog> {
  final TextEditingController _number = TextEditingController();

  @override
  void initState() {
    super.initState();
    _number.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _number.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Nouveau message'),
      content: TextField(
        controller: _number,
        autofocus: true,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
            labelText: 'Numéro (ex : 1001)', prefixIcon: Icon(Icons.person)),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed:
              valid ? () => Navigator.pop(context, _number.text.trim()) : null,
          child: const Text('Écrire'),
        ),
      ],
    );
  }
}
