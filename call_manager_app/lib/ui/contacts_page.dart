import 'package:flutter/material.dart';

import '../sip/sip_service.dart';

/// Onglet Contacts : les numéros connus. Un numéro absent de cette liste est
/// traité comme inconnu par le call manager.
class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key, required this.sip});
  final SipService sip;

  Future<void> _addContact(BuildContext context) async {
    final contact = await showDialog<({String name, String number})>(
        context: context, builder: (_) => const _NewContactDialog());
    if (contact != null) sip.addContact(contact.number, contact.name);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = sip.contacts.byNumber.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addContact(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
      body: contacts.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final c in contacts)
                  ListTile(
                    leading: CircleAvatar(
                        child: Text(c.value.isEmpty ? '?' : c.value[0])),
                    title: Text(c.value),
                    subtitle: Text(c.key),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Appeler',
                          icon: const Icon(Icons.call),
                          color: Colors.green,
                          onPressed:
                              sip.isRegistered ? () => sip.call(c.key) : null,
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => sip.removeContact(c.key),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contacts,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text(
              'Aucun contact.\nTous les appelants seront traités comme inconnus.',
              textAlign: TextAlign.center,
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
                labelText: 'Nom', prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _number,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Numéro', prefixIcon: Icon(Icons.phone)),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(
                  context, (name: _name.text.trim(), number: _number.text.trim()))
              : null,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
