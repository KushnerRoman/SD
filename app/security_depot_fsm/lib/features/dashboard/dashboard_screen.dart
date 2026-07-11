import 'package:flutter/material.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';
import '../jobs/shared_job_editor_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.repository});

  final FieldServiceRepository repository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Object>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<List<Object>> _loadData() {
    return Future.wait([
      widget.repository.getDashboardSummary(),
      widget.repository.getJobs(),
      widget.repository.getEmails(),
      widget.repository.getNotifications(),
    ]);
  }

  Future<void> _editJob(Job job) async {
    final changed = await showSharedJobEditorDialog(
      context: context,
      repository: widget.repository,
      job: job,
    );
    if (changed && mounted) {
      setState(() => _dataFuture = _loadData());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = snapshot.data![0] as DashboardSummary;
        final jobs = snapshot.data![1] as List<Job>;
        final emails = snapshot.data![2] as List<EmailMessage>;
        final notifications = snapshot.data![3] as List<ManagerNotification>;
        final scheduleJobs = [...jobs]
          ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
        final visibleSchedule = scheduleJobs.take(10).toList();

        return _Page(
          title: 'Operations Command Center',
          subtitle: 'Dispatch, workload, and service completion at a glance',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                      label: 'New Jobs',
                      value: summary.newJobs,
                      color: const Color(0xFF2563EB)),
                  _MetricTile(
                      label: 'In Progress',
                      value: summary.inProgress,
                      color: const Color(0xFFF59E0B)),
                  _MetricTile(
                      label: 'Waiting Parts',
                      value: summary.waitingParts,
                      color: const Color(0xFFDC2626)),
                  _MetricTile(
                      label: 'Completed',
                      value: summary.completed,
                      color: const Color(0xFF16A34A)),
                  _MetricTile(
                      label: 'Inbox',
                      value: emails
                          .where((email) => !email.isRead && !email.isLinked)
                          .length,
                      color: const Color(0xFFE31B23)),
                  _MetricTile(
                      label: 'Updates',
                      value: notifications.where((item) => !item.isRead).length,
                      color: const Color(0xFF7C3AED)),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 900;
                  final children = [
                    _StatusPanel(jobs: jobs),
                    _SchedulePanel(
                        jobs: visibleSchedule, onJobSelected: _editJob),
                  ];
                  if (!twoColumns) {
                    return Column(
                        children: children
                            .map((child) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: child))
                            .toList());
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: children[0]),
                      const SizedBox(width: 12),
                      Expanded(child: children[1]),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Page extends StatelessWidget {
  const _Page(
      {required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: const Color(0xFF64748B))),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.toString(),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF475569), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.jobs});

  final List<Job> jobs;

  @override
  Widget build(BuildContext context) {
    const statuses = JobStatus.values;
    return _Panel(
      title: 'Jobs by Status',
      child: Column(
        children: statuses.map((status) {
          final count = jobs.where((job) => job.status == status).length;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: _statusColor(status), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(status.label)),
                Text(count.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({required this.jobs, required this.onJobSelected});

  final List<Job> jobs;
  final ValueChanged<Job> onJobSelected;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Schedule Preview',
      child: Column(
        children: jobs
            .map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => onJobSelected(job),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 92,
                              child: Text(_date(job.scheduledStart),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(job.siteName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                Text(job.title,
                                    style: const TextStyle(
                                        color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_outlined, size: 16),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

String _date(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

Color _statusColor(JobStatus status) {
  return switch (status) {
    JobStatus.newJob => const Color(0xFF2563EB),
    JobStatus.scheduled => const Color(0xFF38BDF8),
    JobStatus.inProgress => const Color(0xFFF59E0B),
    JobStatus.waitingForParts => const Color(0xFFDC2626),
    JobStatus.needReturnVisit => const Color(0xFF7C3AED),
    JobStatus.completed => const Color(0xFF16A34A),
    JobStatus.needManagerReview => const Color(0xFF64748B),
  };
}
