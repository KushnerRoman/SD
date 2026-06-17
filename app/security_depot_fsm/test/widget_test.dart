import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:security_depot_fsm/data/mock_field_service_repository.dart';
import 'package:security_depot_fsm/main.dart';

void main() {
  testWidgets('default app loads bundled seed data',
      (WidgetTester tester) async {
    await tester.pumpWidget(SecurityDepotApp());
    await tester.pumpAndSettle();

    expect(find.text('Manager Dashboard'), findsOneWidget);
    expect(find.textContaining('Could not load local seed data'), findsNothing);
  });

  testWidgets('app shell shows manager dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(SecurityDepotApp(
      repositoryLoader: Future.value(MockFieldServiceRepository()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Manager Dashboard'), findsOneWidget);
    expect(find.text('New Jobs'), findsOneWidget);
    expect(find.text('Schedule Preview'), findsOneWidget);
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
