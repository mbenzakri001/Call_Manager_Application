import 'package:flutter/material.dart';

import '../sip/sip_service.dart';

/// Onglet Contacts : les numéros connus, les favoris et la liste noire.
class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key, required this.sip});
  final SipService sip;

  Future<void> _addContact(BuildContext context) async {
    final contact = await showDialog<({String name, String number})>(
      context: context,
      builder: (_) => const _NewContactDialog(),
    );
    if (contact != null) sip.addContact(contact.number, contact.name);
  }

  Future<void> _blockNumber(BuildContext context) async {
    final number = await showDialog<String>(
      context: context,
      builder: (_) => const _BlockNumberDialog(),
    );
    if (number != null) sip.setBlocked(number, true);
  }

  @override
  Widget build(BuildContext context) {
    // Favoris en premier, puis ordre alphabétique.
    final contacts = sip.contacts.byNumber.entries.toList()
      ..sort((a, b) {
        final fa = sip.isFavorite(a.key), fb = sip.isFavorite(b.key);
        if (fa != fb) return fa ? -1 : 1;
        return a.value.toLowerCase().compareTo(b.value.toLowerCase());
      });
    final blocked = sip.lists.blocked.toList()..sort();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addContact(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
      body: contacts.isEmpty && blocked.isEmpty
          ? _Empty(onBlock: () => _blockNumber(context))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final c in contacts) _ContactTile(sip: sip, contact: c),
                const Divider(height: 32),
                ListTile(
                  title: Text(
                    'Numéros bloqués',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: const Text(
                    'Toujours refusés (603), même s\'ils sont dans vos contacts.',
                  ),
                  trailing: IconButton(
                    tooltip: 'Bloquer un numéro',
                    icon: const Icon(Icons.block),
                    onPressed: () => _blockNumber(context),
                  ),
                ),
                if (blocked.isEmpty)
                  const ListTile(title: Text('Aucun numéro bloqué.')),
                for (final n in blocked)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x22F44336),
                      foregroundColor: Colors.red,
                      child: Icon(Icons.block),
                    ),
                    title: Text(sip.contactNameFor(n) ?? n),
                    subtitle: sip.contactNameFor(n) == null ? null : Text(n),
                    trailing: TextButton(
                      onPressed: () => sip.setBlocked(n, false),
                      child: const Text('Débloquer'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.sip, required this.contact});
  final SipService sip;
  final MapEntry<String, String> contact;

  @override
  Widget build(BuildContext context) {
    final number = contact.key;
    final name = contact.value;
    final favorite = sip.isFavorite(number);
    final blocked = sip.isBlocked(number);

    return ListTile(
      leading: CircleAvatar(child: Text(name.isEmpty ? '?' : name[0])),
      title: Text(name),
      subtitle: Text(
        blocked ? '$number · bloqué' : number,
        style: blocked ? const TextStyle(color: Colors.red) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            icon: Icon(
              favorite ? Icons.star : Icons.star_border,
              color: favorite ? Colors.amber : null,
            ),
            onPressed: () => sip.setFavorite(number, !favorite),
          ),
          IconButton(
            tooltip: 'Appeler',
            icon: const Icon(Icons.call),
            color: Colors.green,
            onPressed: sip.isRegistered ? () => sip.call(number) : null,
          ),
          PopupMenuButton<String>(
            tooltip: 'Plus',
            onSelected: (action) => switch (action) {
              'block' => sip.setBlocked(number, !blocked),
              _ => sip.removeContact(number),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'block',
                child: Text(blocked ? 'Débloquer' : 'Bloquer'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onBlock});
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.contacts,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun contact.\nAjoutez-en pour les mettre en favoris.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onBlock,
              icon: const Icon(Icons.block),
              label: const Text('Bloquer un numéro'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saisie d'un contact. Le dialogue gère lui-même ses champs de texte.
class _NewContactDialog extends StatefulWidget {
  const _NewContactDialog();

  @override
  State<_NewContactDialog> createState() => _NewContactDialogState();
}

class _NewContactDialogState extends State<_NewContactDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _number = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Réactive le bouton "Enregistrer" dès que les deux champs sont remplis.
    _name.addListener(_refresh);
    _number.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _number.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau contact'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _number,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(context, (
                  name: _name.text.trim(),
                  number: _number.text.trim(),
                ))
              : null,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Saisie d'un numéro à bloquer.
class _BlockNumberDialog extends StatefulWidget {
  const _BlockNumberDialog();

  @override
  State<_BlockNumberDialog> createState() => _BlockNumberDialogState();
}

class _BlockNumberDialogState extends State<_BlockNumberDialog> {
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
      title: const Text('Bloquer un numéro'),
      content: TextField(
        controller: _number,
        autofocus: true,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Numéro',
          prefixIcon: Icon(Icons.block),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, _number.text.trim())
              : null,
          child: const Text('Bloquer'),
        ),
      ],
    );
  }
}
