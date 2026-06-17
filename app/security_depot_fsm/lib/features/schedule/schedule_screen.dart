import 'package:flutter/material.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';
import '../jobs/shared_job_editor_dialog.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.repository});

  final FieldServiceRepository repository;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime? _selectedDate;
  late Future<_ScheduleData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ScheduleData> _loadData() async {
    final results = await Future.wait([
      widget.repository.getTodayVisits(),
      widget.repository.getJobs(),
      widget.repository.getTechnicians(),
    ]);
    return _ScheduleData(
      visits: results[0] as List<Visit>,
      jobs: results[1] as List<Job>,
      technicians: results[2] as List<Technician>,
    );
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
    return FutureBuilder<_ScheduleData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final dates = _availableDates(data.visits);
        final selectedDate =
            _selectedDate ?? (dates.isEmpty ? DateTime.now() : dates.first);
        final visitsForDate = data.visits
            .where((visit) => _sameDay(visit.start, selectedDate))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Schedule',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            '${visitsForDate.length} visits on ${_formatDate(selectedDate)}',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<DateTime>(
                        value: dates.any((date) => _sameDay(date, selectedDate))
                            ? dates.firstWhere(
                                (date) => _sameDay(date, selectedDate))
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Schedule Date',
                            border: OutlineInputBorder()),
                        items: dates
                            .map((date) => DropdownMenuItem(
                                  value: date,
                                  child: Text(_formatDate(date)),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedDate = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ScheduleSummary(
                  visits: visitsForDate,
                  technicians: data.technicians,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (data.technicians.isEmpty) {
                        return const _EmptySchedule(
                            message: 'No technicians found.');
                      }
                      if (constraints.maxWidth < 900) {
                        return ListView(
                          children: data.technicians
                              .map((technician) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _TechnicianScheduleColumn(
                                      technician: technician,
                                      visits: _visitsForTechnician(
                                          visitsForDate, technician.id),
                                      jobs: data.jobs,
                                      onJobSelected: _editJob,
                                    ),
                                  ))
                              .toList(),
                        );
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: data.technicians
                              .map((technician) => Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: SizedBox(
                                      width: 320,
                                      child: _TechnicianScheduleColumn(
                                        technician: technician,
                                        visits: _visitsForTechnician(
                                            visitsForDate, technician.id),
                                        jobs: data.jobs,
                                        onJobSelected: _editJob,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DateTime> _availableDates(List<Visit> visits) {
    final seen = <String, DateTime>{};
    for (final visit in visits) {
      final date =
          DateTime(visit.start.year, visit.start.month, visit.start.day);
      seen[_dateKey(date)] = date;
    }
    return seen.values.toList()..sort((a, b) => a.compareTo(b));
  }

  List<Visit> _visitsForTechnician(List<Visit> visits, String technicianId) {
    return visits.where((visit) => visit.technicianId == technicianId).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }
}

class _ScheduleData {
  const _ScheduleData({
    required this.visits,
    required this.jobs,
    required this.technicians,
  });

  final List<Visit> visits;
  final List<Job> jobs;
  final List<Technician> technicians;
}

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({
    required this.visits,
    required this.technicians,
  });

  final List<Visit> visits;
  final List<Technician> technicians;

  @override
  Widget build(BuildContext context) {
    final completed =
        visits.where((visit) => visit.status == VisitStatus.completed).length;
    final open = visits.length - completed;
    final assignedTechs =
        visits.map((visit) => visit.technicianId).toSet().length;
    final waitingParts = visits
        .where((visit) => visit.partsStatus == PartsStatus.waitingForParts)
        .length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryTile(
            label: 'Visits',
            value: visits.length.toString(),
            icon: Icons.event_available_outlined),
        _SummaryTile(
            label: 'Open',
            value: open.toString(),
            icon: Icons.pending_actions_outlined),
        _SummaryTile(
            label: 'Completed',
            value: completed.toString(),
            icon: Icons.check_circle_outline),
        _SummaryTile(
            label: 'Waiting Parts',
            value: waitingParts.toString(),
            icon: Icons.inventory_2_outlined),
        _SummaryTile(
            label: 'Assigned Techs',
            value: '$assignedTechs/${technicians.length}',
            icon: Icons.engineering_outlined),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF0B5ED7)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TechnicianScheduleColumn extends StatelessWidget {
  const _TechnicianScheduleColumn({
    required this.technician,
    required this.visits,
    required this.jobs,
    required this.onJobSelected,
  });

  final Technician technician;
  final List<Visit> visits;
  final List<Job> jobs;
  final ValueChanged<Job> onJobSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                    child: Text(technician.initials.isEmpty
                        ? '?'
                        : technician.initials)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(technician.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text('${visits.length} visits',
                          style: const TextStyle(color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            if (visits.isEmpty)
              const _EmptySchedule(message: 'No visits scheduled.')
            else
              ...visits.map((visit) {
                final job = _jobForVisit(visit);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _VisitScheduleCard(
                    visit: visit,
                    job: job,
                    onTap: job == null ? null : () => onJobSelected(job),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Job? _jobForVisit(Visit visit) {
    final matches = jobs.where((job) => job.id == visit.jobId);
    return matches.isEmpty ? null : matches.first;
  }
}

class _VisitScheduleCard extends StatelessWidget {
  const _VisitScheduleCard({
    required this.visit,
    required this.job,
    required this.onTap,
  });

  final Visit visit;
  final Job? job;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          color: _statusBackground(visit.status),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(
                      '${_formatTime(visit.start)}-${_formatTime(visit.end)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _StatusPill(status: visit.status)),
                ],
              ),
              const SizedBox(height: 10),
              Text(job?.title ?? visit.jobId,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(job?.siteName ?? visit.siteId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF475569))),
              if ((job?.address ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(job!.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF64748B))),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(visit.partsStatus.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(status.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(message, style: const TextStyle(color: Color(0xFF64748B))),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';

String _formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

Color _statusBackground(VisitStatus status) {
  return switch (status) {
    VisitStatus.completed => const Color(0xFFF0FDF4),
    VisitStatus.notCompleted => const Color(0xFFFFFBEB),
    VisitStatus.needReturnVisit => const Color(0xFFF5F3FF),
    VisitStatus.waitingForParts => const Color(0xFFFEF2F2),
    VisitStatus.couldNotAccessSite => const Color(0xFFFFF7ED),
    VisitStatus.needManagerReview => const Color(0xFFF8FAFC),
  };
}
