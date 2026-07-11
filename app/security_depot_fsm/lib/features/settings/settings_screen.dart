import 'package:flutter/material.dart';
import '../../data/field_service_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.repository});
  final FieldServiceRepository repository;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const Text('Demo connections and data controls'),
        const SizedBox(height: 24),
        const Card(
            child: Column(children: [
          ListTile(
              leading: CircleAvatar(child: Icon(Icons.mail)),
              title: Text('Gmail Demo'),
              subtitle: Text('Mixed mailbox simulation'),
              trailing: Chip(
                  avatar:
                      Icon(Icons.check_circle, color: Colors.green, size: 17),
                  label: Text('Connected'))),
          Divider(height: 1),
          ListTile(
              leading: CircleAvatar(child: Icon(Icons.calendar_month)),
              title: Text('Google Calendar Demo'),
              subtitle: Text('Technician calendar simulation'),
              trailing: Chip(
                  avatar:
                      Icon(Icons.check_circle, color: Colors.green, size: 17),
                  label: Text('Connected')))
        ])),
        const SizedBox(height: 24),
        Card(
            child: ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFE5E6),
                    child: Icon(Icons.restart_alt, color: Color(0xFFE31B23))),
                title: const Text('Reset demo data',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                    'Restore the original emails, service calls, technicians, and history.'),
                trailing: OutlinedButton(
                    onPressed: () => _reset(context),
                    child: const Text('Reset'))))
      ]));
  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Reset all demo data?'),
                content: const Text(
                    'Every change made during this demo will be replaced with the original sample data.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset demo'))
                ]));
    if (ok == true) {
      await repository.resetDemoData();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Demo data restored.')));
      }
    }
  }
}
