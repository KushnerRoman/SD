import 'package:flutter/material.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';
import '../jobs/shared_job_editor_dialog.dart';

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key, required this.repository});

  final FieldServiceRepository repository;

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  String? _selectedTechnicianId;
  late Future<_TechniciansData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_TechniciansData> _loadData() async {
    final results = await Future.wait([
      widget.repository.getTechnicians(),
      widget.repository.getJobs(),
      widget.repository.getTodayVisits(),
    ]);
    return _TechniciansData(
      technicians: results[0] as List<Technician>,
      jobs: results[1] as List<Job>,
      visits: results[2] as List<Visit>,
    );
  }

  Future<void> _saveTechnician(Technician technician,
      {required bool isNew}) async {
    if (isNew) {
      await widget.repository.addTechnician(technician);
    } else {
      await widget.repository.updateTechnician(technician);
    }
    setState(() {
      _selectedTechnicianId = technician.id;
      _dataFuture = _loadData();
    });
  }

  void _startNewTechnician(List<Technician> technicians) {
    var index = technicians.length + 1;
    var id = 'tech_new_$index';
    while (technicians.any((technician) => technician.id == id)) {
      index += 1;
      id = 'tech_new_$index';
    }
    setState(() => _selectedTechnicianId = id);
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
    return FutureBuilder<_TechniciansData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final selected = _selectedTechnician(data);
        final isNew = selected.id.startsWith('tech_new_');
        final stats = _statsFor(data, selected.id);

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
                          Text('Technicians',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            '${data.technicians.length} technicians - ${data.jobs.where((job) => job.isOpen).length} open jobs',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _startNewTechnician(data.technicians),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Add Technician'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 980;
                      final list = _TechnicianList(
                        technicians: data.technicians,
                        jobs: data.jobs,
                        visits: data.visits,
                        selectedTechnicianId: selected.id,
                        onSelected: (technician) => setState(
                            () => _selectedTechnicianId = technician.id),
                      );
                      final editor = _TechnicianEditor(
                        key: ValueKey(selected.id),
                        technician: selected,
                        isNew: isNew,
                        stats: stats,
                        jobs: data.jobs
                            .where((job) =>
                                job.assignedTechnicianId == selected.id)
                            .toList(),
                        visits: data.visits
                            .where((visit) => visit.technicianId == selected.id)
                            .toList(),
                        allJobs: data.jobs,
                        onJobSelected: _editJob,
                        onSave: (technician) =>
                            _saveTechnician(technician, isNew: isNew),
                      );

                      if (!wide) {
                        return ListView(
                          children: [
                            list,
                            const SizedBox(height: 16),
                            editor,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 380, child: list),
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

  Technician _selectedTechnician(_TechniciansData data) {
    final selectedId = _selectedTechnicianId;
    if (selectedId != null) {
      final matches =
          data.technicians.where((technician) => technician.id == selectedId);
      final existing = matches.isEmpty ? null : matches.first;
      if (existing != null) {
        return existing;
      }
      if (selectedId.startsWith('tech_new_')) {
        return Technician(id: selectedId, name: '', email: '', initials: '');
      }
    }
    return data.technicians.isEmpty
        ? const Technician(id: 'tech_new_1', name: '', email: '', initials: '')
        : data.technicians.first;
  }

  _TechnicianStats _statsFor(_TechniciansData data, String technicianId) {
    final jobs = data.jobs
        .where((job) => job.assignedTechnicianId == technicianId)
        .toList();
    final visits = data.visits
        .where((visit) => visit.technicianId == technicianId)
        .toList();
    return _TechnicianStats(
      openJobs: jobs.where((job) => job.isOpen).length,
      completedJobs:
          jobs.where((job) => job.status == JobStatus.completed).length,
      visits: visits.length,
    );
  }
}

class _TechniciansData {
  const _TechniciansData(
      {required this.technicians, required this.jobs, required this.visits});

  final List<Technician> technicians;
  final List<Job> jobs;
  final List<Visit> visits;
}

class _TechnicianStats {
  const _TechnicianStats(
      {required this.openJobs,
      required this.completedJobs,
      required this.visits});

  final int openJobs;
  final int completedJobs;
  final int visits;
}

class _TechnicianList extends StatelessWidget {
  const _TechnicianList({
    required this.technicians,
    required this.jobs,
    required this.visits,
    required this.selectedTechnicianId,
    required this.onSelected,
  });

  final List<Technician> technicians;
  final List<Job> jobs;
  final List<Visit> visits;
  final String selectedTechnicianId;
  final ValueChanged<Technician> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: technicians.map((technician) {
        final techJobs = jobs
            .where((job) => job.assignedTechnicianId == technician.id)
            .toList();
        final techVisits =
            visits.where((visit) => visit.technicianId == technician.id).length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelected(technician),
            child: Card(
              color: technician.id == selectedTechnicianId
                  ? const Color(0xFFEFF6FF)
                  : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                        child: Text(technician.initials.isEmpty
                            ? '?'
                            : technician.initials)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(technician.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                              '${techJobs.where((job) => job.isOpen).length} open - $techVisits visits',
                              style: const TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TechnicianEditor extends StatefulWidget {
  const _TechnicianEditor({
    super.key,
    required this.technician,
    required this.isNew,
    required this.stats,
    required this.jobs,
    required this.visits,
    required this.allJobs,
    required this.onJobSelected,
    required this.onSave,
  });

  final Technician technician;
  final bool isNew;
  final _TechnicianStats stats;
  final List<Job> jobs;
  final List<Visit> visits;
  final List<Job> allJobs;
  final ValueChanged<Job> onJobSelected;
  final Future<void> Function(Technician technician) onSave;

  @override
  State<_TechnicianEditor> createState() => _TechnicianEditorState();
}

class _TechnicianEditorState extends State<_TechnicianEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _initialsController;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.technician.name);
    _emailController = TextEditingController(text: widget.technician.email);
    _initialsController =
        TextEditingController(text: widget.technician.initials);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _initialsController.dispose();
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
                CircleAvatar(
                    radius: 24,
                    child: Text(_initialsController.text.trim().isEmpty
                        ? '?'
                        : _initialsController.text.trim())),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.isNew ? 'New Technician' : widget.technician.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatTile(
                    label: 'Open Jobs',
                    value: widget.stats.openJobs.toString(),
                    icon: Icons.assignment_outlined),
                _StatTile(
                    label: 'Completed',
                    value: widget.stats.completedJobs.toString(),
                    icon: Icons.check_circle_outline),
                _StatTile(
                    label: 'Visits',
                    value: widget.stats.visits.toString(),
                    icon: Icons.event_available_outlined),
              ],
            ),
            const Divider(height: 30),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                  labelText: 'Technician name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              child: TextField(
                controller: _initialsController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Initials', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving
                    ? 'Saving...'
                    : widget.isNew
                        ? 'Create Technician'
                        : 'Save Technician'),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!,
                  style: const TextStyle(
                      color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 24),
            Text('Assigned Work',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (widget.jobs.isEmpty)
              const Text('No assigned jobs yet.',
                  style: TextStyle(color: Color(0xFF64748B)))
            else
              ..._sortedJobs().map((job) => _WorkLine(
                  title: job.title,
                  subtitle: '${job.status.label} - ${job.siteName}',
                  onTap: () => widget.onJobSelected(job))),
            const SizedBox(height: 18),
            Text('Recent Visits',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (widget.visits.isEmpty)
              const Text('No visits recorded yet.',
                  style: TextStyle(color: Color(0xFF64748B)))
            else
              ..._sortedVisits().map((visit) {
                final job = _jobForVisit(visit);
                return _WorkLine(
                  title: _visitTitle(visit, job),
                  subtitle: job == null
                      ? (visit.workDone.isEmpty ? 'No notes' : visit.workDone)
                      : '${job.status.label} - ${job.siteName}',
                  onTap: job == null ? null : () => widget.onJobSelected(job),
                );
              }),
          ],
        ),
      ),
    );
  }

  List<Job> _sortedJobs() {
    return List<Job>.from(widget.jobs)
      ..sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        return b.scheduledStart.compareTo(a.scheduledStart);
      });
  }

  List<Visit> _sortedVisits() {
    return List<Visit>.from(widget.visits)
      ..sort((a, b) => b.start.compareTo(a.start));
  }

  Job? _jobForVisit(Visit visit) {
    final matches = widget.allJobs.where((job) => job.id == visit.jobId);
    return matches.isEmpty ? null : matches.first;
  }

  String _visitTitle(Visit visit, Job? job) {
    final hour = visit.start.hour.toString().padLeft(2, '0');
    final minute = visit.start.minute.toString().padLeft(2, '0');
    return '$hour:$minute - ${job?.title ?? visit.status.label}';
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _message = 'Name is required.');
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    final initials = _initialsController.text.trim().isEmpty
        ? _deriveInitials(name)
        : _initialsController.text.trim().toUpperCase();
    await widget.onSave(widget.technician.copyWith(
      name: name,
      email: _emailController.text.trim(),
      initials: initials,
    ));

    if (mounted) {
      setState(() {
        _saving = false;
        _message = widget.isNew ? 'Technician created.' : 'Technician saved.';
      });
    }
  }

  String _deriveInitials(String name) {
    final parts =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF0B5ED7)),
              const SizedBox(height: 8),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkLine extends StatelessWidget {
  const _WorkLine({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.radio_button_checked,
                size: 16, color: Color(0xFF0B5ED7)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
