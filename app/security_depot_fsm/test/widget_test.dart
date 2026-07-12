import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:security_depot_fsm/data/field_service_repository.dart';
import 'package:security_depot_fsm/data/mock_field_service_repository.dart';
import 'package:security_depot_fsm/domain/models.dart';
import 'package:security_depot_fsm/main.dart';

class _EmptyRepository extends MockFieldServiceRepository {
  @override
  Future<List<EmailMessage>> getEmails() async => const [];
}

class _CalendarRepository extends MockFieldServiceRepository {
  @override
  Future<List<Visit>> getTodayVisits() async {
    final visits = await super.getTodayVisits();
    return [
      visits.first.copyWith(
          calendarDeliveryStatus: 'synced',
          reportUrl: Uri.parse('http://127.0.0.1:8765/report/test-token')),
      visits[1].copyWith(calendarDeliveryStatus: 'pending'),
      visits[2].copyWith(calendarDeliveryStatus: 'failed'),
    ];
  }
}

void main() {
  testWidgets('failed API startup shows connection error instead of demo data',
      (WidgetTester tester) async {
    final repositoryLoader = Completer<FieldServiceRepository>();
    await tester.pumpWidget(SecurityDepotApp(
      repositoryLoader: repositoryLoader.future,
    ));
    repositoryLoader.completeError(StateError('API unavailable'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not connect to the local API'),
        findsOneWidget);
    expect(find.text('Operations Command Center'), findsNothing);
  });

  testWidgets('app shell shows manager dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(SecurityDepotApp(
      repositoryLoader: Future.value(MockFieldServiceRepository()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Operations Command Center'), findsOneWidget);
    expect(find.text('New Jobs'), findsOneWidget);
    expect(find.text('Schedule Preview'), findsOneWidget);
  });

  testWidgets('operations shell exposes real-data Calendar navigation',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SecurityDepotApp(
      repositoryLoader: Future.value(MockFieldServiceRepository()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('Inbox'), findsWidgets);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.textContaining('Demo'), findsNothing);
  });

  testWidgets('empty inbox explains how to import real Gmail messages',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SecurityDepotApp(
        repositoryLoader: Future.value(_EmptyRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.mail_outline).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('No imported Gmail messages yet.'), findsOneWidget);
    expect(find.textContaining('Settings'), findsWidgets);
    expect(find.textContaining('demo'), findsNothing);
  });

  testWidgets('technician editor requires a valid Gmail address',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SecurityDepotApp(
        repositoryLoader: Future.value(MockFieldServiceRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Techs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Technician'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Technician name'), 'Test Tech');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'not-an-email');
    await tester.ensureVisible(find.text('Create Technician'));
    await tester.tap(find.text('Create Technician'));
    await tester.pump();
    expect(find.text('Enter a valid Gmail address.'), findsOneWidget);
  });

  testWidgets('Calendar shows delivery badges and report-link actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SecurityDepotApp(
        repositoryLoader: Future.value(_CalendarRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Synced'), findsOneWidget);
    expect(find.byTooltip('Copy report link'), findsOneWidget);
    expect(find.byTooltip('Open report link'), findsOneWidget);
  });

  testWidgets('technicians screen supports workforce overview',
      (WidgetTester tester) async {
    await tester.pumpWidget(SecurityDepotApp(
      repositoryLoader: Future.value(MockFieldServiceRepository()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Techs'));
    await tester.pumpAndSettle();

    expect(find.text('Technicians'), findsOneWidget);
    expect(find.text('Add Technician'), findsOneWidget);
    expect(find.text('Open Jobs'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
  });

  testWidgets('schedule screen shows technician visit board',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(SecurityDepotApp(
      repositoryLoader: Future.value(MockFieldServiceRepository()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Schedule Date'), findsOneWidget);
    expect(find.text('Assigned Techs'), findsOneWidget);
    expect(find.text('Roman Kushner'), findsWidgets);

    await tester.tap(find.text('Front Door Reader').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Job'), findsOneWidget);
    expect(find.text('Assign & Send'), findsOneWidget);
  });

  testWidgets('visits screen shows selectable visit list',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(SecurityDepotApp(
      repositoryLoader: Future.value(MockFieldServiceRepository()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Visit'));
    await tester.pumpAndSettle();

    expect(find.text('Visits'), findsOneWidget);
    expect(find.text('Select Visit'), findsOneWidget);
    expect(find.text('Save Update'), findsOneWidget);
  });

  testWidgets('jobs and sites screens expose create actions',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(SecurityDepotApp(
      repositoryLoader: Future.value(MockFieldServiceRepository()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jobs'));
    await tester.pumpAndSettle();
    expect(find.text('New Job'), findsOneWidget);

    await tester.tap(find.text('Sites'));
    await tester.pumpAndSettle();
    expect(find.text('New Site'), findsOneWidget);
  });
}
