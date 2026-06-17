import 'package:flutter/material.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';
import '../jobs/shared_job_editor_dialog.dart';

class VisitUpdateScreen extends StatefulWidget {
  const VisitUpdateScreen({super.key, required this.repository});

  final FieldServiceRepository repository;

  @override
  State<VisitUpdateScreen> createState() => _VisitUpdateScreenState();
}

class _VisitUpdateScreenState extends State<VisitUpdateScreen> {
  String? _selectedVisitId;
  late Future<_VisitsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_VisitsData> _loadData() async {
    final results = await Future.wait([
      widget.repository.getTodayVisits(),
      widget.repository.getJobs(),
      widget.repository.getTechnicians(),
    ]);
    return _VisitsData(
      visits: results[0] as List<Visit>,
      jobs: results[1] as List<Job>,
      technicians: results[2] as List<Technician>,
    );
  }

  Future<void> _saveVisit({
    required String visitId,
    required VisitStatus status,
    required String workDone,
    required PartsStatus partsStatus,
    required String technicianId,
    required DateTime start,
    required DateTime end,
  }) async {
    await widget.repository.saveVisitUpdate(
      visitId: visitId,
      status: status,
      workDone: workDone,
      partsStatus: partsStatus,
      technicianId: technicianId,
      start: start,
      end: end,
    );
    setState(() {
      _selectedVisitId = visitId;
      _dataFuture = _loadData();
    });
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
    return FutureBuilder<_VisitsData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final selected = _selectedVisit(data.visits);
        final jobMatches = data.jobs.where((item) => item.id == selected.jobId);
        final job = jobMatches.isEmpty ? null : jobMatches.first;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Visits',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    '${data.visits.length} visit records - choose one to update work notes, status, and parts.',
                    style: const TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 18),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 980;
                      final list = _VisitList(
                        visits: data.visits,
                        jobs: data.jobs,
                        technicians: data.technicians,
                        selectedVisitId: selected.id,
                        onSelected: (visit) =>
                            setState(() => _selectedVisitId = visit.id),
                      );
                      final editor = _VisitEditor(
                        key: ValueKey(selected.id),
                        visit: selected,
                        job: job,
                        technicians: data.technicians,
                        onJobSelected: _editJob,
                        onSave: _saveVisit,
                      );

                      if (!wide) {
                        return ListView(
                          children: [
                            SizedBox(height: 420, child: list),
                            const SizedBox(height: 16),
                            editor,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 410, child: list),
                          const SizedBox(width: 16),
                          Expanded(child: editor),
                        ],
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

  Visit _selectedVisit(List<Visit> visits) {
    if (visits.isEmpty) {
      final now = DateTime(2026, 5, 29, 9);
      return Visit(
        id: '',
        jobId: '',
        siteId: '',
        technicianId: '',
        start: now,
        end: now.add(const Duration(hours: 1)),
        status: VisitStatus.needManagerReview,
        workDone: '',
        partsStatus: PartsStatus.noPartsUsed,
      );
    }
    final selectedId = _selectedVisitId;
    if (selectedId != null) {
      for (final visit in visits) {
        if (visit.id == selectedId) return visit;
      }
    }
    return visits.first;
  }
}

class _VisitsData {
  const _VisitsData(
      {required this.visits, required this.jobs, required this.technicians});

  final List<Visit> visits;
  final List<Job> jobs;
  final List<Technician> technicians;
}

class _VisitList extends StatelessWidget {
  const _VisitList({
    required this.visits,
    required this.jobs,
    required this.technicians,
    required this.selectedVisitId,
    required this.onSelected,
  });

  final List<Visit> visits;
  final List<Job> jobs;
  final List<Technician> technicians;
  final String selectedVisitId;
  final ValueChanged<Visit> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Visit',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: visits.map((visit) {
              final jobMatches = jobs.where((item) => item.id == visit.jobId);
              final job = jobMatches.isEmpty ? null : jobMatches.first;
              final technicianMatches =
                  technicians.where((item) => item.id == visit.technicianId);
              final technician =
                  technicianMatches.isEmpty ? null : technicianMatches.first;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => onSelected(visit),
                  borderRadius: BorderRadius.circular(8),
                  child: Card(
                    color: visit.id == selectedVisitId
                        ? const Color(0xFFEFF6FF)
                        : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Text(job?.title ?? visit.jobId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900))),
                              _VisitStatusChip(status: visit.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(technician?.name ?? visit.technicianId,
                              style: const TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _VisitEditor extends StatefulWidget {
  const _VisitEditor(
      {super.key,
      required this.visit,
      required this.job,
      required this.technicians,
      required this.onJobSelected,
      required this.onSave});

  final Visit visit;
  final Job? job;
  final List<Technician> technicians;
  final ValueChanged<Job> onJobSelected;
  final Future<void> Function({
    required String visitId,
    required VisitStatus status,
    required String workDone,
    required PartsStatus partsStatus,
    required String technicianId,
    required DateTime start,
    required DateTime end,
  }) onSave;

  @override
  State<_VisitEditor> createState() => _VisitEditorState();
}

class _VisitEditorState extends State<_VisitEditor> {
  late VisitStatus _status;
  late PartsStatus _partsStatus;
  late final TextEditingController _workDoneController;
  late final TextEditingController _dateController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late String _technicianId;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _status = widget.visit.status;
    _partsStatus = widget.visit.partsStatus;
    _workDoneController = TextEditingController(text: widget.visit.workDone);
    _dateController = TextEditingController(
        text: widget.visit.start.toIso8601String().split('T').first);
    _startTimeController =
        TextEditingController(text: _formatTime(widget.visit.start));
    _endTimeController =
        TextEditingController(text: _formatTime(widget.visit.end));
    _technicianId = widget.technicians
            .any((technician) => technician.id == widget.visit.technicianId)
        ? widget.visit.technicianId
        : widget.technicians.isEmpty
            ? ''
            : widget.technicians.first.id;
  }

  @override
  void dispose() {
    _workDoneController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update Visit',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
                job == null
                    ? widget.visit.id
                    : '${job.id.toUpperCase()} - ${job.siteName}',
                style: const TextStyle(color: Color(0xFF64748B))),
            const Divider(height: 30),
            if (job != null)
              _ReadOnlyJobHeader(
                job: job,
                onEdit: () => widget.onJobSelected(job),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    value: _technicianId.isEmpty ? null : _technicianId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Technician', border: OutlineInputBorder()),
                    items: widget.technicians
                        .map((technician) => DropdownMenuItem(
                            value: technician.id, child: Text(technician.name)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _technicianId = value ?? _technicianId),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                        labelText: 'Date', border: OutlineInputBorder()),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _startTimeController,
                    decoration: const InputDecoration(
                        labelText: 'Start', border: OutlineInputBorder()),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _endTimeController,
                    decoration: const InputDecoration(
                        labelText: 'End', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<VisitStatus>(
              value: _status,
              decoration: const InputDecoration(
                  labelText: 'Status', border: OutlineInputBorder()),
              items: VisitStatus.values
                  .map((status) => DropdownMenuItem(
                      value: status, child: Text(status.label)))
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _workDoneController,
              maxLines: 5,
              decoration: const InputDecoration(
                  labelText: 'Work Done / Notes', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<PartsStatus>(
              value: _partsStatus,
              decoration: const InputDecoration(
                  labelText: 'Parts', border: OutlineInputBorder()),
              items: PartsStatus.values
                  .map((status) => DropdownMenuItem(
                      value: status, child: Text(status.label)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _partsStatus = value ?? _partsStatus),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Update'),
                onPressed: _saving || widget.visit.id.isEmpty ? null : _save,
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!,
                  style: const TextStyle(
                      color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    final start = _parseDateAndTime(
      _dateController.text,
      _startTimeController.text,
      widget.visit.start,
    );
    final end = _parseDateAndTime(
      _dateController.text,
      _endTimeController.text,
      widget.visit.end,
    );
    await widget.onSave(
      visitId: widget.visit.id,
      status: _status,
      workDone: _workDoneController.text.trim(),
      partsStatus: _partsStatus,
      technicianId: _technicianId,
      start: start,
      end: end.isAfter(start) ? end : start.add(const Duration(hours: 1)),
    );
    if (mounted) {
      setState(() {
        _saving = false;
        _message = 'Visit saved.';
      });
    }
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  DateTime _parseDateAndTime(
      String dateText, String timeText, DateTime fallback) {
    final date = DateTime.tryParse(dateText.trim()) ?? fallback;
    final parts = timeText.trim().split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

class _ReadOnlyJobHeader extends StatelessWidget {
  const _ReadOnlyJobHeader({required this.job, required this.onEdit});

  final Job job;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(job.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
            ),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Job'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(job.address.isEmpty ? 'Address needs review' : job.address,
            style: const TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        Text(job.description, maxLines: 8, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _VisitStatusChip extends StatelessWidget {
  const _VisitStatusChip({required this.status});

  final VisitStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.label),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: status == VisitStatus.completed
          ? const Color(0xFFDCFCE7)
          : const Color(0xFFEFF6FF),
    );
  }
}
