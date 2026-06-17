import 'package:flutter/material.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key, required this.repository});

  final FieldServiceRepository repository;

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  String? _selectedJobId;
  JobStatus? _statusFilter;
  String _query = '';
  late Future<_JobsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_JobsData> _loadData() async {
    final results = await Future.wait([
      widget.repository.getJobs(),
      widget.repository.getTechnicians(),
      widget.repository.getSites(),
    ]);
    return _JobsData(
      jobs: results[0] as List<Job>,
      technicians: results[1] as List<Technician>,
      sites: results[2] as List<Site>,
    );
  }

  Future<void> _saveJob(Job job) async {
    await widget.repository.updateJob(job);
    setState(() {
      _selectedJobId = job.id;
      _dataFuture = _loadData();
    });
  }

  Future<void> _assignAndSend(Job job) async {
    final scheduledJob = job.copyWith(status: JobStatus.scheduled);
    await widget.repository.updateJob(scheduledJob);
    await widget.repository.scheduleVisit(Visit(
      id: 'visit_${job.id}',
      jobId: scheduledJob.id,
      siteId: scheduledJob.siteId,
      technicianId: scheduledJob.assignedTechnicianId,
      start: scheduledJob.scheduledStart,
      end: scheduledJob.scheduledEnd.isAfter(scheduledJob.scheduledStart)
          ? scheduledJob.scheduledEnd
          : scheduledJob.scheduledStart.add(const Duration(hours: 1)),
      status: VisitStatus.notCompleted,
      workDone: '',
      partsStatus: PartsStatus.noPartsUsed,
    ));
    setState(() {
      _selectedJobId = job.id;
      _dataFuture = _loadData();
    });
  }

  Future<void> _addNewJob(_JobsData data) async {
    final now = DateTime.now();
    final site = data.sites.isNotEmpty
        ? data.sites.first
        : const Site(id: '', name: 'Manual Site', address: '');
    final technician =
        data.technicians.isNotEmpty ? data.technicians.first : null;
    final job = Job(
      id: 'job_manual_${now.millisecondsSinceEpoch}',
      title: 'New Manual Job',
      siteId: site.id,
      siteName: site.name,
      address: site.address,
      type: JobType.serviceCall,
      priority: JobPriority.medium,
      status: JobStatus.newJob,
      assignedTechnicianId: technician?.id ?? '',
      scheduledStart: now,
      scheduledEnd: now.add(const Duration(hours: 1)),
      description: 'Created manually.',
      source: JobSource.manual,
    );
    await widget.repository.addJob(job);
    setState(() {
      _selectedJobId = job.id;
      _statusFilter = null;
      _dataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_JobsData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final filteredJobs = _filterJobs(data.jobs);
        final selected = _selectedJob(filteredJobs, data.jobs);
        final openCount = data.jobs.where((job) => job.isOpen).length;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jobs',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            '${data.jobs.length} jobs loaded - $openCount open for assignment',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _addNewJob(data),
                      icon: const Icon(Icons.add),
                      label: const Text('New Job'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: selected == null
                          ? null
                          : () => _assignAndSend(selected),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Assign & Send'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Filters(
                  query: _query,
                  statusFilter: _statusFilter,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onStatusChanged: (value) =>
                      setState(() => _statusFilter = value),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      if (!wide) {
                        return ListView(
                          children: [
                            ...filteredJobs.map((job) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _JobCard(
                                    job: job,
                                    selected: job.id == selected?.id,
                                    onTap: () =>
                                        setState(() => _selectedJobId = job.id),
                                  ),
                                )),
                            const SizedBox(height: 4),
                            selected == null
                                ? const _EmptyState()
                                : _JobEditor(
                                    key: ValueKey(selected.id),
                                    job: selected,
                                    technicians: data.technicians,
                                    sites: data.sites,
                                    onSave: _saveJob,
                                    onAssignAndSend: _assignAndSend,
                                  ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 390,
                            child: ListView(
                              children: filteredJobs
                                  .map((job) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _JobCard(
                                          job: job,
                                          selected: job.id == selected?.id,
                                          onTap: () => setState(
                                              () => _selectedJobId = job.id),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: selected == null
                                ? const _EmptyState()
                                : _JobEditor(
                                    key: ValueKey(selected.id),
                                    job: selected,
                                    technicians: data.technicians,
                                    sites: data.sites,
                                    onSave: _saveJob,
                                    onAssignAndSend: _assignAndSend,
                                  ),
                          ),
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

  List<Job> _filterJobs(List<Job> jobs) {
    final normalizedQuery = _query.trim().toLowerCase();
    return jobs.where((job) {
      final matchesStatus =
          _statusFilter == null || job.status == _statusFilter;
      final haystack =
          '${job.title} ${job.siteName} ${job.address} ${job.description}'
              .toLowerCase();
      final matchesQuery =
          normalizedQuery.isEmpty || haystack.contains(normalizedQuery);
      return matchesStatus && matchesQuery;
    }).toList()
      ..sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        return a.scheduledStart.compareTo(b.scheduledStart);
      });
  }

  Job? _selectedJob(List<Job> filteredJobs, List<Job> allJobs) {
    if (filteredJobs.isEmpty) return null;
    final selectedId = _selectedJobId;
    if (selectedId != null) {
      for (final job in filteredJobs) {
        if (job.id == selectedId) return job;
      }
    }
    return filteredJobs.first;
  }
}

class _JobsData {
  const _JobsData(
      {required this.jobs, required this.technicians, required this.sites});

  final List<Job> jobs;
  final List<Technician> technicians;
  final List<Site> sites;
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String query;
  final JobStatus? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<JobStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search jobs, sites, notes',
              border: OutlineInputBorder(),
            ),
            onChanged: onQueryChanged,
          ),
        ),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<JobStatus?>(
            value: statusFilter,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Status', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<JobStatus?>(
                  value: null, child: Text('All statuses')),
              ...JobStatus.values.map((status) => DropdownMenuItem<JobStatus?>(
                  value: status, child: Text(status.label))),
            ],
            onChanged: onStatusChanged,
          ),
        ),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard(
      {required this.job, required this.selected, required this.onTap});

  final Job job;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Text(job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900))),
                  const SizedBox(width: 8),
                  _StatusChip(status: job.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(job.siteName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(job.address.isEmpty ? 'Address needs review' : job.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobEditor extends StatefulWidget {
  const _JobEditor(
      {super.key,
      required this.job,
      required this.technicians,
      required this.sites,
      required this.onSave,
      required this.onAssignAndSend});

  final Job job;
  final List<Technician> technicians;
  final List<Site> sites;
  final Future<void> Function(Job job) onSave;
  final Future<void> Function(Job job) onAssignAndSend;

  @override
  State<_JobEditor> createState() => _JobEditorState();
}

class _JobEditorState extends State<_JobEditor> {
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
    _titleController = TextEditingController(text: widget.job.title);
    _descriptionController =
        TextEditingController(text: widget.job.description);
    _dateController = TextEditingController(
        text: widget.job.scheduledStart.toIso8601String().split('T').first);
    _startTimeController =
        TextEditingController(text: _formatTime(widget.job.scheduledStart));
    _endTimeController =
        TextEditingController(text: _formatTime(widget.job.scheduledEnd));
    _status = widget.job.status;
    _priority = widget.job.priority;
    _technicianId = widget.technicians
            .any((tech) => tech.id == widget.job.assignedTechnicianId)
        ? widget.job.assignedTechnicianId
        : widget.technicians.isEmpty
            ? ''
            : widget.technicians.first.id;
    _siteId = widget.sites.any((site) => site.id == widget.job.siteId)
        ? widget.job.siteId
        : widget.sites.isEmpty
            ? ''
            : widget.sites.first.id;
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
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.job.id.toUpperCase(),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                _StatusChip(status: _status),
              ],
            ),
            const SizedBox(height: 8),
            Text(widget.job.siteName,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
                widget.job.address.isEmpty
                    ? 'Address needs review'
                    : widget.job.address,
                style: const TextStyle(color: Color(0xFF64748B))),
            const Divider(height: 30),
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
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _siteId.isEmpty ? null : _siteId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Site', border: OutlineInputBorder()),
                    items: widget.sites
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
                        labelText: 'Assign To', border: OutlineInputBorder()),
                    items: widget.technicians
                        .map((tech) => DropdownMenuItem(
                            value: tech.id, child: Text(tech.name)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _technicianId = value ?? _technicianId),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<JobStatus>(
                    value: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Status', border: OutlineInputBorder()),
                    items: JobStatus.values
                        .map((status) => DropdownMenuItem(
                            value: status, child: Text(status.label)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<JobPriority>(
                    value: _priority,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Priority', border: OutlineInputBorder()),
                    items: JobPriority.values
                        .map((priority) => DropdownMenuItem(
                            value: priority, child: Text(priority.label)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _priority = value ?? _priority),
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save Changes'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _assignAndSend,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(_saving ? 'Saving...' : 'Assign & Send'),
                  ),
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!,
                  style: const TextStyle(
                      color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 24),
            Text('Local History',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const _HistoryLine(
                time: 'Imported',
                text: 'Loaded from historical calendar dataset'),
            _HistoryLine(time: 'Status', text: _status.label),
            _HistoryLine(time: 'Tech', text: _technicianName()),
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

    await widget.onSave(_editedJob());

    if (mounted) {
      setState(() {
        _saving = false;
        _message = 'Saved locally. API/database sync comes later.';
      });
    }
  }

  Future<void> _assignAndSend() async {
    setState(() {
      _saving = true;
      _message = null;
    });

    await widget.onAssignAndSend(_editedJob().copyWith(
      status: JobStatus.scheduled,
    ));

    if (mounted) {
      setState(() {
        _saving = false;
        _message = 'Assigned and scheduled.';
      });
    }
  }

  Job _editedJob() {
    final selectedSite = widget.sites.where((site) => site.id == _siteId);
    final site = selectedSite.isEmpty ? null : selectedSite.first;
    final scheduledStart = _parseDateAndTime(
      _dateController.text,
      _startTimeController.text,
      widget.job.scheduledStart,
    );
    final scheduledEnd = _parseDateAndTime(
      _dateController.text,
      _endTimeController.text,
      widget.job.scheduledEnd,
    );

    return widget.job.copyWith(
      title: _titleController.text.trim().isEmpty
          ? widget.job.title
          : _titleController.text.trim(),
      siteId: site?.id,
      siteName: site?.name,
      address: site?.address,
      description: _descriptionController.text.trim(),
      status: _status,
      priority: _priority,
      assignedTechnicianId: _technicianId,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd.isAfter(scheduledStart)
          ? scheduledEnd
          : scheduledStart.add(const Duration(hours: 1)),
    );
  }

  String _technicianName() {
    for (final technician in widget.technicians) {
      if (technician.id == _technicianId) return technician.name;
    }
    return 'Unassigned';
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No jobs match the current filters.'),
        ),
      ),
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.time, required this.text});

  final String time;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child:
                  Text(time, style: const TextStyle(color: Color(0xFF64748B)))),
          const Icon(Icons.check_circle, size: 18, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.label),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: status == JobStatus.completed
          ? const Color(0xFFDCFCE7)
          : const Color(0xFFEFF6FF),
    );
  }
}
