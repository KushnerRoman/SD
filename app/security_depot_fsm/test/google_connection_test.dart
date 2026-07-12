import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:security_depot_fsm/data/api_field_service_repository.dart';
import 'package:security_depot_fsm/data/mock_field_service_repository.dart';
import 'package:security_depot_fsm/domain/models.dart';
import 'package:security_depot_fsm/features/settings/settings_screen.dart';

class ConnectedRepository extends MockFieldServiceRepository {
  int connectionLoads = 0;
  int statusLoads = 0;
  @override
  Future<GoogleConnectionState> getGoogleConnection() async {
    connectionLoads++;
    return const GoogleConnectionState(
        status: GoogleConnectionStatus.connected,
        accountEmail: 'ops@example.com');
  }

  @override
  Future<SyncStatus> getGoogleSyncStatus() async {
    statusLoads++;
    return SyncStatus(
        status: 'error',
        lastSyncedAt: DateTime(2026, 7, 11, 11),
        errorCode: 'quota');
  }

  @override
  Future<SyncStatus> syncGoogleNow() async => SyncStatus(
      status: 'ok',
      lastSyncedAt: DateTime(2026, 7, 11, 12),
      calendarDelivered: 4,
      gmailAdded: 2);
}

class DisconnectedRepository extends MockFieldServiceRepository {
  int loads = 0;
  @override
  Future<GoogleConnectionState> getGoogleConnection() async {
    loads++;
    return const GoogleConnectionState(
        status: GoogleConnectionStatus.disconnected);
  }

  @override
  Future<Uri> startGoogleConnection() async =>
      Uri.parse('http://localhost:8765/auth/google/start');
}

class FailingConnectRepository extends DisconnectedRepository {
  @override
  Future<Uri> startGoogleConnection() async =>
      throw StateError('secret provider detail');
}

void main() {
  test('API maps connection and uses safe Google endpoints', () async {
    final requests = <http.Request>[];
    final repository = ApiFieldServiceRepository(
        baseUrl: Uri.parse('http://localhost:8765'),
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/google/connection') {
            return http.Response(
                '{"status":"connected","account_email":"ops@example.com"}',
                200);
          }
          if (request.url.path == '/google/sync-status') {
            return http.Response(
                '{"status":"ok","last_synced_at":"2026-07-11T12:00:00"}', 200);
          }
          return http.Response('{}', 200);
        }));
    final state = await repository.getGoogleConnection();
    expect(state.isConnected, isTrue);
    expect(
        (await repository.startGoogleConnection()).path, '/auth/google/start');
    await repository.syncGoogleNow();
    await repository.disconnectGoogle();
    expect(
        requests.map((r) => r.url.path),
        containsAll([
          '/google/sync',
          '/google/sync-status',
          '/auth/google/disconnect'
        ]));
  });

  testWidgets('connected screen offers sync and confirms disconnect',
      (tester) async {
    final repository = ConnectedRepository();
    await tester
        .pumpWidget(MaterialApp(home: SettingsScreen(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('ops@example.com'), findsOneWidget);
    expect(find.text('Sync Now'), findsOneWidget);
    expect(find.textContaining('Last sync:'), findsOneWidget);
    expect(find.textContaining('quota'), findsOneWidget);
    expect(repository.connectionLoads, 1);
    expect(repository.statusLoads, 1);
    await tester.tap(find.text('Sync Now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gmail: 2 added'), findsOneWidget);
    expect(find.textContaining('Calendar: 4 delivered'), findsOneWidget);
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect Google?'), findsOneWidget);
  });

  testWidgets(
      'current-window OAuth relies on callback reload instead of dead polling',
      (tester) async {
    final repository = DisconnectedRepository();
    Uri? opened;
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
      repository: repository,
      openGoogle: (uri) async {
        opened = uri;
        return true;
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect Google'));
    await tester.pumpAndSettle();
    expect(opened?.path, '/auth/google/start');
    expect(repository.loads, 1);
  });

  testWidgets('connect errors become safe UI state', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(repository: FailingConnectRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect Google'));
    await tester.pumpAndSettle();
    expect(find.text('Could not start Google authorization.'), findsOneWidget);
    expect(find.textContaining('secret provider detail'), findsNothing);
  });
}
