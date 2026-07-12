import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/field_service_repository.dart';
import '../../domain/models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});
  final FieldServiceRepository repository;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GoogleConnectionState? connection;
  SyncStatus? sync;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final value = await widget.repository.getGoogleConnection();
      if (mounted) {
        setState(() {
          connection = value;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Could not check Google connection.');
    }
  }

  Future<void> _connect() async {
    final uri = await widget.repository.startGoogleConnection();
    if (!await launchUrl(uri, webOnlyWindowName: '_self')) {
      setState(() => error = 'Could not open Google authorization.');
      return;
    }
    for (var i = 0; i < 30 && mounted; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await _refresh();
      if (connection?.isConnected == true) break;
    }
  }

  Future<void> _sync() async {
    setState(() => busy = true);
    try {
      sync = await widget.repository.syncGoogleNow();
      error = null;
    } catch (_) {
      error = 'Sync failed safely. Try again or reconnect Google.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _disconnect() async {
    final yes = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                    title: const Text('Disconnect Google?'),
                    content: const Text(
                        'Gmail and Calendar synchronization will stop.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Disconnect'))
                    ])) ??
        false;
    if (yes) {
      await widget.repository.disconnectGoogle();
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = connection?.status ?? GoogleConnectionStatus.disconnected;
    final connected = state == GoogleConnectionStatus.connected;
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Google Connection',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        connected
                            ? 'Connected'
                            : state == GoogleConnectionStatus.expired
                                ? 'Reconnect required'
                                : 'Not connected',
                        style: Theme.of(context).textTheme.titleLarge),
                    if (connection?.accountEmail != null)
                      Text(connection!.accountEmail!),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, children: [
                      if (!connected)
                        FilledButton(
                            onPressed: _connect,
                            child: Text(state == GoogleConnectionStatus.expired
                                ? 'Reconnect'
                                : 'Connect Google')),
                      if (connected)
                        FilledButton(
                            onPressed: busy ? null : _sync,
                            child: const Text('Sync Now')),
                      if (connected)
                        OutlinedButton(
                            onPressed: _disconnect,
                            child: const Text('Disconnect')),
                    ]),
                    if (sync?.lastSyncedAt != null)
                      Text('Last sync: ${sync!.lastSyncedAt}'),
                    if (sync?.nextSyncAt != null)
                      Text('Next sync: ${sync!.nextSyncAt}'),
                    if (error != null)
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ]))),
    ]);
  }
}
