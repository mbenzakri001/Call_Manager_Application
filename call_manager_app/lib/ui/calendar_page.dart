import 'package:flutter/material.dart';

import '../core/call_decision.dart';
import '../sip/sip_service.dart';

/// Onglet Calendrier : disponibilité actuelle et rendez-vous à venir.
/// Pendant un rendez-vous, le call manager refuse les appels (sauf favoris).
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key, required this.sip});
  final SipService sip;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = sip.calendar.appointments
        .where((a) => a.end.isAfter(now))
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final rdv = await showDialog<Appointment>(
              context: context, builder: (_) => const _NewAppointmentDialog());
          if (rdv != null) sip.addAppointment(rdv);
        },
        icon: const Icon(Icons.add),
        label: const Text('Rendez-vous'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          _AvailabilityCard(sip: sip),
          const SizedBox(height: 24),
          Text("Aujourd'hui et à venir",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            const Text('Aucun rendez-vous prévu.')
          else
            for (final rdv in upcoming)
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.event,
                    color: rdv == sip.currentAppointment ? Colors.orange : null,
                  ),
                  title: Text(rdv.title ?? 'Rendez-vous'),
                  subtitle: Text(_slot(rdv, now) +
                      (rdv == sip.currentAppointment ? ' · en cours' : '')),
                  trailing: IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => sip.removeAppointment(rdv),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

String _slot(Appointment a, DateTime now) {
  final sameDay = a.start.year == now.year &&
      a.start.month == now.month &&
      a.start.day == now.day;
  final day = sameDay
      ? ''
      : '${a.start.day.toString().padLeft(2, '0')}/'
          '${a.start.month.toString().padLeft(2, '0')} · ';
  return '$day${formatHour(a.start)} – ${formatHour(a.end)}';
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.sip});
  final SipService sip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rdv = sip.currentAppointment;
    final busy = rdv != null;

    return Card(
      color: (busy ? Colors.orange : Colors.green).withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(busy ? Icons.event_busy : Icons.event_available,
                    color: busy ? Colors.orange : Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    busy
                        ? "${rdv.title ?? 'En rendez-vous'} jusqu'à ${formatHour(rdv.end)}"
                        : 'Disponible',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(busy
                ? 'Les appels sont refusés (486), sauf favoris et appels '
                    'répétés, avec un '
                    'message indiquant votre heure de fin.'
                : 'Les appels sonnent normalement.'),
            const SizedBox(height: 12),
            if (busy)
              OutlinedButton.icon(
                onPressed: sip.endMeeting,
                icon: const Icon(Icons.stop),
                label: const Text('Terminer maintenant'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('En réunion maintenant :'),
                  for (final (label, minutes) in const [
                    ('15 min', 15),
                    ('30 min', 30),
                    ('1 h', 60),
                  ])
                    OutlinedButton(
                      onPressed: () =>
                          sip.startMeeting(Duration(minutes: minutes)),
                      child: Text(label),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Saisie d'un rendez-vous : titre, jour, heure de début et de fin.
class _NewAppointmentDialog extends StatefulWidget {
  const _NewAppointmentDialog();

  @override
  State<_NewAppointmentDialog> createState() => _NewAppointmentDialogState();
}

class _NewAppointmentDialogState extends State<_NewAppointmentDialog> {
  final TextEditingController _title = TextEditingController();
  late DateTime _day;
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _start = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
    _end = TimeOfDay(hour: (now.hour + 2) % 24, minute: 0);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) =>
      DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);

  bool get _valid => _at(_end).isAfter(_at(_start));

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _day = d);
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(
        context: context, initialTime: start ? _start : _end);
    if (t == null) return;
    setState(() => start ? _start = t : _end = t);
  }

  @override
  Widget build(BuildContext context) {
    String fmt(TimeOfDay t) =>
        '${t.hour}h${t.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      title: const Text('Nouveau rendez-vous'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Titre', hintText: 'Réunion projet'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text('${_day.day.toString().padLeft(2, '0')}/'
                '${_day.month.toString().padLeft(2, '0')}/${_day.year}'),
            onTap: _pickDay,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text('Début : ${fmt(_start)}'),
            onTap: () => _pickTime(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: Text('Fin : ${fmt(_end)}'),
            subtitle: _valid
                ? null
                : const Text('La fin doit être après le début',
                    style: TextStyle(color: Colors.red)),
            onTap: () => _pickTime(false),
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
                    context,
                    Appointment(
                      title: _title.text.trim().isEmpty
                          ? 'Rendez-vous'
                          : _title.text.trim(),
                      start: _at(_start),
                      end: _at(_end),
                    ),
                  )
              : null,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
