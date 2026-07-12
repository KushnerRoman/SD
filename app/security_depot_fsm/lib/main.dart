import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'data/api_field_service_repository.dart';
import 'data/field_service_repository.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/jobs/jobs_screen.dart';
import 'features/history/history_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/schedule/schedule_screen.dart';
import 'features/sites/sites_screen.dart';
import 'features/technicians/technicians_screen.dart';
import 'features/visits/visit_update_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SecurityDepotApp(repositoryLoader: _loadRepository()));
}

Future<FieldServiceRepository> _loadRepository() async {
  final apiRepository = ApiFieldServiceRepository(baseUrl: _apiBaseUrl());
  await apiRepository.getDashboardSummary().timeout(const Duration(seconds: 2));
  return apiRepository;
}

Uri _apiBaseUrl() {
  if (kIsWeb) {
    return Uri.base;
  }
  return Uri.parse('http://127.0.0.1:8765');
}

class SecurityDepotApp extends StatelessWidget {
  const SecurityDepotApp({
    super.key,
    required this.repositoryLoader,
  });

  final Future<FieldServiceRepository> repositoryLoader;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Security Depot FSM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE31B23),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        fontFamily: 'Arial',
        inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)))),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE31B23),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16))),
        cardTheme: const CardTheme(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      home: FutureBuilder<FieldServiceRepository>(
        future: repositoryLoader,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      'Could not connect to the local API at http://127.0.0.1:8765.\n${snapshot.error}'),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return AppShell(repository: snapshot.data!);
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.repository});

  final FieldServiceRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(repository: widget.repository),
      InboxScreen(repository: widget.repository),
      ScheduleScreen(repository: widget.repository),
      JobsScreen(repository: widget.repository),
      SitesScreen(repository: widget.repository),
      TechniciansScreen(repository: widget.repository),
      VisitUpdateScreen(repository: widget.repository),
      HistoryScreen(repository: widget.repository),
      CalendarScreen(repository: widget.repository),
      SettingsScreen(repository: widget.repository),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 760 && constraints.maxHeight >= 700;
        return Scaffold(
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  minWidth: 112,
                  backgroundColor: const Color(0xFF101B2D),
                  indicatorColor: const Color(0xFFE31B23),
                  selectedIconTheme: const IconThemeData(color: Colors.white),
                  unselectedIconTheme:
                      const IconThemeData(color: Color(0xFFB7C6D9)),
                  selectedLabelTextStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                  unselectedLabelTextStyle:
                      const TextStyle(color: Color(0xFFB7C6D9)),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: _BrandMark(),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        label: Text('Dashboard')),
                    NavigationRailDestination(
                        icon: Icon(Icons.mail_outline), label: Text('Inbox')),
                    NavigationRailDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        label: Text('Schedule')),
                    NavigationRailDestination(
                        icon: Icon(Icons.work_outline), label: Text('Jobs')),
                    NavigationRailDestination(
                        icon: Icon(Icons.apartment_outlined),
                        label: Text('Sites')),
                    NavigationRailDestination(
                        icon: Icon(Icons.engineering_outlined),
                        label: Text('Techs')),
                    NavigationRailDestination(
                        icon: Icon(Icons.fact_check_outlined),
                        label: Text('Visit')),
                    NavigationRailDestination(
                        icon: Icon(Icons.history), label: Text('History')),
                    NavigationRailDestination(
                        icon: Icon(Icons.event_available_outlined),
                        label: Text('Calendar')),
                    NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        label: Text('Settings')),
                  ],
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                ),
              Expanded(child: screens[_selectedIndex]),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        label: 'Dashboard'),
                    NavigationDestination(
                        icon: Icon(Icons.mail_outline), label: 'Inbox'),
                    NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        label: 'Schedule'),
                    NavigationDestination(
                        icon: Icon(Icons.work_outline), label: 'Jobs'),
                    NavigationDestination(
                        icon: Icon(Icons.apartment_outlined), label: 'Sites'),
                    NavigationDestination(
                        icon: Icon(Icons.engineering_outlined), label: 'Techs'),
                    NavigationDestination(
                        icon: Icon(Icons.fact_check_outlined), label: 'Visit'),
                    NavigationDestination(
                        icon: Icon(Icons.history), label: 'History'),
                    NavigationDestination(
                        icon: Icon(Icons.event_available_outlined),
                        label: 'Calendar'),
                    NavigationDestination(
                        icon: Icon(Icons.settings_outlined), label: 'Settings'),
                  ],
                ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF6EA8FF)),
          ),
          child: const Icon(Icons.shield_outlined, color: Colors.white),
        ),
        const SizedBox(height: 10),
        const Text(
          'Operations',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ],
    );
  }
}
