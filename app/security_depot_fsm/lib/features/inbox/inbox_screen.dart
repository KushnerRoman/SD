import 'package:flutter/material.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.repository});
  final FieldServiceRepository repository;
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late Future<List<EmailMessage>> _future;
  EmailMessage? _selected;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = widget.repository.getEmails();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Inbox',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text(
                      'Mixed Gmail demo · choose which messages become service calls')
                ])),
            SizedBox(
                width: 320,
                child: TextField(
                    onChanged: (v) => setState(() => _query = v.toLowerCase()),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search mail')))
          ]),
          const SizedBox(height: 20),
          Expanded(
              child: FutureBuilder<List<EmailMessage>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _ErrorState(
                          error: snapshot.error.toString(),
                          retry: () => setState(_reload));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!
                        .where((m) => '${m.sender} ${m.subject} ${m.body}'
                            .toLowerCase()
                            .contains(_query))
                        .toList();
                    if (messages.isEmpty) {
                      return const Center(
                          child: Text('No messages match this search.'));
                    }
                    _selected ??= messages.first;
                    return Row(children: [
                      Expanded(
                          flex: 5,
                          child: Card(
                              child: ListView.separated(
                                  itemCount: messages.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final message = messages[i];
                                    return ListTile(
                                        selected: _selected?.id == message.id,
                                        leading: CircleAvatar(
                                            backgroundColor: message.isRead
                                                ? const Color(0xFFE8EDF3)
                                                : const Color(0xFFFFE5E6),
                                            child: Icon(
                                                message.isLinked
                                                    ? Icons.link
                                                    : Icons.mail_outline,
                                                color: message.isLinked
                                                    ? Colors.green
                                                    : const Color(0xFFE31B23))),
                                        title: Text(message.subject,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontWeight: message.isRead
                                                    ? FontWeight.w500
                                                    : FontWeight.w800)),
                                        subtitle: Text(
                                            '${message.sender}\n${message.body}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        isThreeLine: true,
                                        trailing: message.isLinked
                                            ? const Chip(label: Text('Linked'))
                                            : null,
                                        onTap: () => setState(
                                            () => _selected = message));
                                  }))),
                      const SizedBox(width: 16),
                      Expanded(
                          flex: 6,
                          child: _MessageDetail(
                              message: _selected!,
                              repository: widget.repository,
                              onSaved: () => setState(() {
                                    _selected = null;
                                    _reload();
                                  }))),
                    ]);
                  })),
        ]),
      );
}

class _MessageDetail extends StatelessWidget {
  const _MessageDetail(
      {required this.message, required this.repository, required this.onSaved});
  final EmailMessage message;
  final FieldServiceRepository repository;
  final VoidCallback onSaved;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(message.subject,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800))),
              if (message.isLinked)
                const Chip(
                    avatar: Icon(Icons.check, size: 16),
                    label: Text('Service call created'))
            ]),
            const SizedBox(height: 12),
            Text('From  ${message.sender}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('To  ${message.recipients}',
                style: const TextStyle(color: Colors.black54)),
            const Divider(height: 32),
            Expanded(
                child: SingleChildScrollView(
                    child: Text(message.body,
                        style: const TextStyle(fontSize: 16, height: 1.6)))),
            if (message.attachmentNames.isNotEmpty)
              Wrap(
                  spacing: 8,
                  children: message.attachmentNames
                      .map((a) => Chip(
                          avatar: const Icon(Icons.attach_file, size: 16),
                          label: Text(a)))
                      .toList()),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: message.isLinked
                        ? null
                        : () async {
                            final saved = await showDialog<bool>(
                                context: context,
                                builder: (_) => _DispatchDialog(
                                    email: message, repository: repository));
                            if (saved == true) onSaved();
                          },
                    icon: const Icon(Icons.add_task),
                    label: Text(message.isLinked
                        ? 'Already linked'
                        : 'Create service call'))),
          ])));
}

class _DispatchDialog extends StatefulWidget {
  const _DispatchDialog({required this.email, required this.repository});
  final EmailMessage email;
  final FieldServiceRepository repository;
  @override
  State<_DispatchDialog> createState() => _DispatchDialogState();
}

class _DispatchDialogState extends State<_DispatchDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.email.subject);
  late final TextEditingController _instructions =
      TextEditingController(text: widget.email.body);
  ServiceCategory _category = ServiceCategory.intercom;
  JobPriority _priority = JobPriority.medium;
  String? _site;
  String? _tech;
  final DateTime _start = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;
  String? _error;
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Create service call'),
          content: SizedBox(
              width: 620,
              child: FutureBuilder(
                  future: Future.wait([
                    widget.repository.getSites(),
                    widget.repository.getTechnicians()
                  ]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                          height: 240,
                          child: Center(child: CircularProgressIndicator()));
                    }
                    final sites = snapshot.data![0] as List<Site>;
                    final techs = snapshot.data![1] as List<Technician>;
                    _site ??= sites.firstOrNull?.id;
                    _tech ??= techs.firstOrNull?.id;
                    return Form(
                        key: _form,
                        child: SingleChildScrollView(
                            child: Column(children: [
                          TextFormField(
                              controller: _title,
                              decoration: const InputDecoration(
                                  labelText: 'Service call title'),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Title is required'
                                  : null),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: DropdownButtonFormField(
                                    value: _category,
                                    decoration: const InputDecoration(
                                        labelText: 'Service type'),
                                    items: ServiceCategory.values
                                        .map((v) => DropdownMenuItem(
                                            value: v, child: Text(v.label)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _category = v!))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: DropdownButtonFormField(
                                    value: _priority,
                                    decoration: const InputDecoration(
                                        labelText: 'Priority'),
                                    items: JobPriority.values
                                        .map((v) => DropdownMenuItem(
                                            value: v, child: Text(v.label)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _priority = v!)))
                          ]),
                          const SizedBox(height: 12),
                          DropdownButtonFormField(
                              value: _site,
                              decoration:
                                  const InputDecoration(labelText: 'Site'),
                              items: sites
                                  .map((v) => DropdownMenuItem(
                                      value: v.id, child: Text(v.name)))
                                  .toList(),
                              onChanged: (v) => setState(() => _site = v)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField(
                              value: _tech,
                              decoration: const InputDecoration(
                                  labelText: 'Technician'),
                              items: techs
                                  .map((v) => DropdownMenuItem(
                                      value: v.id, child: Text(v.name)))
                                  .toList(),
                              onChanged: (v) => setState(() => _tech = v)),
                          const SizedBox(height: 12),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event),
                              title: const Text('Scheduled tomorrow'),
                              subtitle: Text(
                                  '${_start.month}/${_start.day}/${_start.year} · 9:00 AM – 10:00 AM')),
                          TextFormField(
                              controller: _instructions,
                              minLines: 3,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                  labelText: 'Technician instructions'),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Instructions are required'
                                  : null),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(_error!,
                                    style: const TextStyle(color: Colors.red)))
                        ])));
                  })),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Creating…' : 'Assign & create event'))
          ]);
  Future<void> _save() async {
    if (!_form.currentState!.validate() || _site == null || _tech == null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final start = DateTime(_start.year, _start.month, _start.day, 9);
      await widget.repository.dispatchFromEmail(DispatchRequest(
          emailId: widget.email.id,
          siteId: _site!,
          title: _title.text,
          category: _category,
          priority: _priority,
          technicianId: _tech!,
          start: start,
          end: start.add(const Duration(hours: 1)),
          instructions: _instructions.text));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.retry});
  final String error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 48),
        const SizedBox(height: 12),
        Text(error, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: retry, child: const Text('Retry'))
      ]));
}
