import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.repository});
  final FieldServiceRepository repository;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String? _technicianId;
  int _refresh = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<List<Object>>(
        key: ValueKey(_refresh),
        future: Future.wait<Object>([
          widget.repository.getTechnicians(),
          widget.repository.getTodayVisits(),
          widget.repository.getJobs(),
          widget.repository.getSites()
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final techs = snapshot.data![0] as List<Technician>;
          final visits = snapshot.data![1] as List<Visit>;
          final jobs = snapshot.data![2] as List<Job>;
          final sites = snapshot.data![3] as List<Site>;
          _technicianId ??= techs.firstOrNull?.id;
          final tech =
              techs.where((item) => item.id == _technicianId).firstOrNull;
          final visible = visits
              .where((item) => item.technicianId == _technicianId)
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Calendar',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800)),
                        Text(
                            'Manager preview of scheduled visits and Google delivery state')
                      ])),
                  SizedBox(
                      width: 260,
                      child: DropdownButtonFormField<String>(
                          value: _technicianId,
                          decoration: const InputDecoration(
                              labelText: 'Viewing calendar for'),
                          items: techs
                              .map((item) => DropdownMenuItem(
                                  value: item.id, child: Text(item.name)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _technicianId = value))),
                ]),
                const SizedBox(height: 18),
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F4),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      CircleAvatar(
                          backgroundColor: const Color(0xFF4285F4),
                          child: Text(tech?.initials ?? '',
                              style: const TextStyle(color: Colors.white))),
                      const SizedBox(width: 12),
                      Text('${tech?.name ?? ''} · Week schedule',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      const Icon(Icons.chevron_left),
                      const SizedBox(width: 10),
                      const Text('This week'),
                      const SizedBox(width: 10),
                      const Icon(Icons.chevron_right)
                    ])),
                const SizedBox(height: 12),
                Expanded(
                    child: Card(
                        child: visible.isEmpty
                            ? const Center(
                                child: Text(
                                    'No calendar events assigned to this technician.'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final visit = visible[index];
                                  final job = jobs
                                      .where((item) => item.id == visit.jobId)
                                      .firstOrNull;
                                  final site = sites
                                      .where((item) => item.id == visit.siteId)
                                      .firstOrNull;
                                  return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          onTap: () async {
                                            final saved =
                                                await showDialog<bool>(
                                                    context: context,
                                                    builder: (_) =>
                                                        _ReportDialog(
                                                            repository: widget
                                                                .repository,
                                                            visit: visit,
                                                            job: job,
                                                            site: site));
                                            if (saved == true) {
                                              setState(() => _refresh++);
                                            }
                                          },
                                          child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE8F0FE),
                                                  border: const Border(
                                                      left: BorderSide(
                                                          color:
                                                              Color(0xFF4285F4),
                                                          width: 5)),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Row(children: [
                                                SizedBox(
                                                    width: 100,
                                                    child: Text(
                                                        '${_time(visit.start)}\n${_time(visit.end)}',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700))),
                                                Expanded(
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                      Text(
                                                          job?.title ??
                                                              'Service visit',
                                                          style: const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800)),
                                                      Text(
                                                          '${site?.name ?? job?.siteName ?? ''} · ${site?.address ?? ''}'),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                          job?.description ??
                                                              '',
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis)
                                                    ])),
                                                Chip(
                                                    label: Text(_deliveryLabel(visit
                                                        .calendarDeliveryStatus))),
                                                const SizedBox(width: 8),
                                                if (visit.reportUrl !=
                                                    null) ...[
                                                  IconButton(
                                                      tooltip:
                                                          'Copy report link',
                                                      onPressed: () => Clipboard
                                                          .setData(ClipboardData(
                                                              text: visit
                                                                  .reportUrl
                                                                  .toString())),
                                                      icon: const Icon(
                                                          Icons.copy)),
                                                  IconButton(
                                                      tooltip:
                                                          'Open report link',
                                                      onPressed: () =>
                                                          launchUrl(
                                                              visit.reportUrl!),
                                                      icon: const Icon(
                                                          Icons.open_in_new))
                                                ]
                                              ]))));
                                }))),
              ]);
        },
      ),
    );
  }

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _deliveryLabel(String status) => switch (status.toLowerCase()) {
        'pending' => 'Queued',
        'synced' => 'Synced',
        'failed' => 'Failed',
        _ => 'Local',
      };
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog(
      {required this.repository, required this.visit, this.job, this.site});
  final FieldServiceRepository repository;
  final Visit visit;
  final Job? job;
  final Site? site;
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _form = GlobalKey<FormState>();
  VisitStatus _status = VisitStatus.completed;
  final _minutes = TextEditingController(text: '60');
  final _work = TextEditingController();
  final _materials = TextEditingController();
  final _followUp = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.job?.title ?? 'Service visit'),
        content: SizedBox(
            width: 620,
            child: Form(
                key: _form,
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(widget.site?.name ?? widget.job?.siteName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(widget.site?.address ?? ''),
                      const SizedBox(height: 8),
                      Text(widget.job?.description ?? ''),
                      const Divider(height: 28),
                      const Text('Technician update',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<VisitStatus>(
                          value: _status,
                          decoration:
                              const InputDecoration(labelText: 'Result'),
                          items: const [
                            DropdownMenuItem(
                                value: VisitStatus.completed,
                                child: Text('Completed')),
                            DropdownMenuItem(
                                value: VisitStatus.notCompleted,
                                child: Text('Incomplete')),
                            DropdownMenuItem(
                                value: VisitStatus.needReturnVisit,
                                child: Text('Return Required'))
                          ],
                          onChanged: (value) =>
                              setState(() => _status = value!)),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _minutes,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Time spent (minutes)'),
                          validator: (value) =>
                              (int.tryParse(value ?? '') ?? 0) <= 0
                                  ? 'Enter time spent'
                                  : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _work,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                              labelText: 'Work performed'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Describe the work performed'
                                  : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: _materials,
                          decoration: const InputDecoration(
                              labelText: 'Materials used (optional)')),
                      if (_status != VisitStatus.completed) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: _followUp,
                            minLines: 2,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Follow-up required'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Explain what must happen next'
                                    : null)
                      ],
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error!,
                                style: const TextStyle(color: Colors.red))),
                    ])))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Saving…' : 'Save update'))
        ],
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.submitTechnicianReport(
          visitId: widget.visit.id,
          status: _status,
          durationMinutes: int.parse(_minutes.text),
          workPerformed: _work.text,
          materialsUsed: _materials.text,
          followUpNotes: _followUp.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }
}
