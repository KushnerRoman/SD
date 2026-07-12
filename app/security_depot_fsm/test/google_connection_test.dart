import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:security_depot_fsm/data/api_field_service_repository.dart';
import 'package:security_depot_fsm/data/mock_field_service_repository.dart';
import 'package:security_depot_fsm/domain/models.dart';
import 'package:security_depot_fsm/features/settings/settings_screen.dart';

class ConnectedRepository extends MockFieldServiceRepository {
  @override
  Future<GoogleConnectionState> getGoogleConnection() async =>
      const GoogleConnectionState(
          status: GoogleConnectionStatus.connected,
          accountEmail: 'ops@example.com');
  @override
  Future<SyncStatus> syncGoogleNow() async =>
      SyncStatus(status: 'ok', lastSyncedAt: DateTime(2026, 7, 11, 12));
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
    await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(repository: ConnectedRepository())));
    await tester.pumpAndSettle();
    expect(find.text('ops@example.com'), findsOneWidget);
    expect(find.text('Sync Now'), findsOneWidget);
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect Google?'), findsOneWidget);
  });
}
