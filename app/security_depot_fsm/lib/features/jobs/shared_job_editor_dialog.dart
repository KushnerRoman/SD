import 'package:flutter/material.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';

Future<bool> showSharedJobEditorDialog({
  required BuildContext context,
  required FieldServiceRepository repository,
  required Job job,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _SharedJobEditorDialog(repository: repository, initialJob: job),
  );
  return saved ?? false;
}

class _SharedJobEditorDialog extends StatefulWidget {
  const _SharedJobEditorDialog({
    required this.repository,
    required this.initialJob,
  });

  final FieldServiceRepository repository;
  final Job initialJob;

  @override
  State<_SharedJobEditorDialog> createState() => _SharedJobEditorDialogState();
}

class _SharedJobEditorDialogState extends State<_SharedJobEditorDialog> {
  late Future<_EditorData> _dataFuture;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late JobStatus _status;
  late JobPriority _priority;
  late String _technicianId;
  late String _siteId;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _titleController = TextEditingController(text: widget.initialJob.title);
    _descriptionController =
        TextEditingController(text: widget.initialJob.description);
    _dateController = TextEditingController(
        text: widget.initialJob.scheduledStart
            .toIso8601String()
            .split('T')
            .first);
    _startTimeController = TextEditingController(
        text: _formatTime(widget.initialJob.scheduledStart));
    _endTimeController = TextEditingController(
        text: _formatTime(widget.initialJob.scheduledEnd));
    _status = widget.initialJob.status;
    _priority = widget.initialJob.priority;
    _technicianId = widget.initialJob.assignedTechnicianId;
    _siteId = widget.initialJob.siteId;
  }

  Future<_EditorData> _loadData() async {
    final results = await Future.wait([
      widget.repository.getSites(),
      widget.repository.getTechnicians(),
    ]);
    return _EditorData(
      sites: results[0] as List<Site>,
      technicians: results[1] as List<Technician>,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Row(
        children: [
          Expanded(
            child: Text('Edit Job',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: FutureBuilder<_EditorData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
                width: 520,
                height: 220,
                child: Center(child: CircularProgressIndicator()));
          }

          final data = snapshot.data!;
          if (!data.technicians.any((tech) => tech.id == _technicianId)) {
            _technicianId =
                data.technicians.isEmpty ? '' : data.technicians.first.id;
          }
          if (!data.sites.any((site) => site.id == _siteId)) {
            _siteId = data.sites.isEmpty ? '' : data.sites.first.id;
          }

          return SizedBox(
            width: 760,
            height: MediaQuery.of(context).size.height * 0.72,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.initialJob.id.toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                        labelText: 'Job title', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        labelText: 'Job notes / description',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<String>(
                          value: _siteId.isEmpty ? null : _siteId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Site', border: OutlineInputBorder()),
                          items: data.sites
                              .map((site) => DropdownMenuItem(
                                  value: site.id, child: Text(site.name)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _siteId = value ?? _siteId),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          value: _technicianId.isEmpty ? null : _technicianId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Technician',
                              border: OutlineInputBorder()),
                          items: data.technicians
                              .map((tech) => DropdownMenuItem(
                                  value: tech.id, child: Text(tech.name)))
                              .toList(),
                          onChanged: (value) => setState(
                              () => _technicianId = value ?? _technicianId),
                        ),
                      ),
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<JobStatus>(
                          value: _status,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder()),
                          items: JobStatus.values
                              .map((status) => DropdownMenuItem(
                                  value: status, child: Text(status.label)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _status = value ?? _status),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<JobPriority>(
                          value: _priority,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder()),
                          items: JobPriority.values
                              .map((priority) => DropdownMenuItem(
                                  value: priority, child: Text(priority.label)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _priority = value ?? _priority),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: _dateController,
                          decoration: const InputDecoration(
                              labelText: 'Date', border: OutlineInputBorder()),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _startTimeController,
                          decoration: const InputDecoration(
                              labelText: 'Start', border: OutlineInputBorder()),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _endTimeController,
                          decoration: const InputDecoration(
                              labelText: 'End', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!,
                        style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : () => _save(assignAndSend: false),
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : () => _save(assignAndSend: true),
          icon: const Icon(Icons.send_outlined),
          label: const Text('Assign & Send'),
        ),
      ],
    );
  }

  Future<void> _save({required bool assignAndSend}) async {
    final data = await _dataFuture;
    final selectedSite = data.sites.where((site) => site.id == _siteId);
    final site = selectedSite.isEmpty ? null : selectedSite.first;
    final scheduledStart = _parseDateAndTime(
      _dateController.text,
      _startTimeController.text,
      widget.initialJob.scheduledStart,
    );
    final parsedEnd = _parseDateAndTime(
      _dateController.text,
      _endTimeController.text,
      widget.initialJob.scheduledEnd,
    );
    final scheduledEnd = parsedEnd.isAfter(scheduledStart)
        ? parsedEnd
        : scheduledStart.add(const Duration(hours: 1));
    final updatedJob = widget.initialJob.copyWith(
      title: _titleController.text.trim().isEmpty
          ? widget.initialJob.title
          : _titleController.text.trim(),
      siteId: site?.id,
      siteName: site?.name,
      address: site?.address,
      description: _descriptionController.text.trim(),
      status: assignAndSend ? JobStatus.scheduled : _status,
      priority: _priority,
      assignedTechnicianId: _technicianId,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
    );

    setState(() {
      _saving = true;
      _message = null;
    });

    await widget.repository.updateJob(updatedJob);
    if (assignAndSend) {
      await widget.repository.scheduleVisit(Visit(
        id: 'visit_${updatedJob.id}',
        jobId: updatedJob.id,
        siteId: updatedJob.siteId,
        technicianId: updatedJob.assignedTechnicianId,
        start: updatedJob.scheduledStart,
        end: updatedJob.scheduledEnd,
        status: VisitStatus.notCompleted,
        workDone: '',
        partsStatus: PartsStatus.noPartsUsed,
      ));
    }

    if (mounted) {
      Navigator.of(context).pop(true);
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

class _EditorData {
  const _EditorData({required this.sites, required this.technicians});

  final List<Site> sites;
  final List<Technician> technicians;
}
