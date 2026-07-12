import 'package:flutter/material.dart';
import '../../data/field_service_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.repository});
  final FieldServiceRepository repository;
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        Text('Google connections'),
        SizedBox(height: 24),
        Card(
            child: Column(children: [
          ListTile(
              leading: CircleAvatar(child: Icon(Icons.mail)),
              title: Text('Gmail'),
              subtitle: Text('Connect a Google account to sync service email'),
              trailing: Chip(
                  avatar: Icon(Icons.info_outline, size: 17),
                  label: Text('Not connected'))),
          Divider(height: 1),
          ListTile(
              leading: CircleAvatar(child: Icon(Icons.calendar_month)),
              title: Text('Google Calendar'),
              subtitle: Text('Connect a Google account to sync field visits'),
              trailing: Chip(
                  avatar: Icon(Icons.info_outline, size: 17),
                  label: Text('Not connected')))
        ])),
        SizedBox(height: 16),
        Text('Google connection setup will be available here.')
      ]));
}
