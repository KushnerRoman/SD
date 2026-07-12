import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/field_service_repository.dart';
import '../../domain/models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen(
      {super.key,
      required this.repository,
      this.openGoogle,
      this.callbackGoogleConnected});
  final FieldServiceRepository repository;
  final Future<bool> Function(Uri)? openGoogle;
  final bool? callbackGoogleConnected;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GoogleConnectionState? connection;
  SyncStatus? sync;
  String? error;
  bool busy = false;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  bool get _isCallbackReload =>
      widget.callbackGoogleConnected ??
      (Uri.base.fragment.contains('google=connected') ||
          Uri.base.queryParameters['google'] == 'connected');

  Future<void> _initialize() async {
    final loaded = await _refresh();
    if (mounted &&
        loaded &&
        _isCallbackReload &&
        connection?.isConnected != true) {
      _scheduleCallbackPoll();
    }
  }

  void _scheduleCallbackPoll() {
    if (!mounted || _pollAttempts >= 30) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      _pollAttempts++;
      final loaded = await _refresh();
      if (mounted && loaded && connection?.isConnected != true) {
        _scheduleCallbackPoll();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<bool> _refresh() async {
    try {
      final values = await Future.wait([
        widget.repository.getGoogleConnection(),
        widget.repository.getGoogleSyncStatus(),
      ]);
      if (mounted) {
        setState(() {
          connection = values[0] as GoogleConnectionState;
          sync = values[1] as SyncStatus;
          error = null;
        });
      }
      return true;
    } catch (_) {
      if (mounted) setState(() => error = 'Could not check Google connection.');
      return false;
    }
  }

  Future<void> _connect() async {
    try {
      final uri = await widget.repository.startGoogleConnection();
      final opened = await (widget.openGoogle?.call(uri) ??
          launchUrl(uri, webOnlyWindowName: '_self'));
      if (!opened && mounted) {
        setState(() => error = 'Could not open Google authorization.');
      }
      // `_self` navigates away. The callback reload constructs a fresh Settings
      // screen whose initState loads both connection and prior sync status.
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not start Google authorization.');
      }
    }
  }

  Future<void> _sync() async {
    if (mounted) setState(() => busy = true);
    try {
      final value = await widget.repository.syncGoogleNow();
      if (mounted) {
        setState(() {
          sync = value;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'Sync failed safely. Try again or reconnect Google.');
      }
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
      try {
        await widget.repository.disconnectGoogle();
        if (mounted) await _refresh();
      } catch (_) {
        if (mounted) setState(() => error = 'Could not disconnect Google.');
      }
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
                    if (sync?.errorCode != null)
                      Text('Last sync error: ${sync!.errorCode}'),
                    if (sync != null &&
                        (sync!.gmailAdded +
                                sync!.gmailUpdated +
                                sync!.gmailDeleted +
                                sync!.calendarDelivered) >
                            0) ...[
                      Text(
                          'Gmail: ${sync!.gmailAdded} added, ${sync!.gmailUpdated} updated, ${sync!.gmailDeleted} deleted'),
                      Text('Calendar: ${sync!.calendarDelivered} delivered'),
                    ],
                    if (error != null)
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ]))),
    ]);
  }
}
