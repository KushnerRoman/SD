import 'package:flutter/material.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';
import '../jobs/shared_job_editor_dialog.dart';

class SitesScreen extends StatefulWidget {
  const SitesScreen({super.key, required this.repository});

  final FieldServiceRepository repository;

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  String? _selectedSiteId;
  late Future<_SitesData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_SitesData> _loadData() async {
    final results = await Future.wait([
      widget.repository.getSites(),
      widget.repository.getJobs(),
    ]);
    return _SitesData(
      sites: results[0] as List<Site>,
      jobs: results[1] as List<Job>,
    );
  }

  Future<void> _saveSite(Site site) async {
    await widget.repository.updateSite(site);
    setState(() {
      _selectedSiteId = site.id;
      _dataFuture = _loadData();
    });
  }

  Future<void> _addNewSite() async {
    final now = DateTime.now();
    final site = Site(
      id: 'site_manual_${now.millisecondsSinceEpoch}',
      name: 'New Site',
      address: '',
      slackChannel: '',
      notes: 'Created manually.',
    );
    await widget.repository.addSite(site);
    setState(() {
      _selectedSiteId = site.id;
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
    return FutureBuilder<_SitesData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final selected = _selectedSite(data.sites);
        final siteJobs =
            data.jobs.where((job) => job.siteId == selected.id).toList();

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
                          Text('Sites',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          const Text(
                              'Edit building names, addresses, Slack channels, and review linked work.',
                              style: TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _addNewSite,
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('New Site'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 980;
                      final list = ListView(
                        children: data.sites
                            .map((site) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _SiteTile(
                                    site: site,
                                    jobs: data.jobs
                                        .where((job) => job.siteId == site.id)
                                        .toList(),
                                    selected: site.id == selected.id,
                                    onTap: () => setState(
                                        () => _selectedSiteId = site.id),
                                  ),
                                ))
                            .toList(),
                      );
                      final editor = _SiteEditor(
                        key: ValueKey(selected.id),
                        site: selected,
                        jobs: siteJobs,
                        onSave: _saveSite,
                        onJobSelected: _editJob,
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
                          SizedBox(width: 390, child: list),
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

  Site _selectedSite(List<Site> sites) {
    if (sites.isEmpty) {
      return const Site(id: '', name: 'No sites', address: '');
    }
    final selectedId = _selectedSiteId;
    if (selectedId != null) {
      for (final site in sites) {
        if (site.id == selectedId) return site;
      }
    }
    return sites.first;
  }
}

class _SitesData {
  const _SitesData({required this.sites, required this.jobs});

  final List<Site> sites;
  final List<Job> jobs;
}

class _SiteTile extends StatelessWidget {
  const _SiteTile(
      {required this.site,
      required this.jobs,
      required this.selected,
      required this.onTap});

  final Site site;
  final List<Job> jobs;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final openCount = jobs.where((job) => job.isOpen).length;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.apartment_outlined, color: Color(0xFF0B5ED7)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(site.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                        site.address.isEmpty
                            ? 'Address needs review'
                            : site.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Text('$openCount open',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteEditor extends StatefulWidget {
  const _SiteEditor(
      {super.key,
      required this.site,
      required this.jobs,
      required this.onSave,
      required this.onJobSelected});

  final Site site;
  final List<Job> jobs;
  final Future<void> Function(Site site) onSave;
  final ValueChanged<Job> onJobSelected;

  @override
  State<_SiteEditor> createState() => _SiteEditorState();
}

class _SiteEditorState extends State<_SiteEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _slackController;
  late final TextEditingController _notesController;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.site.name);
    _addressController = TextEditingController(text: widget.site.address);
    _slackController =
        TextEditingController(text: widget.site.slackChannel ?? '');
    _notesController = TextEditingController(text: widget.site.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _slackController.dispose();
    _notesController.dispose();
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
            Text(widget.site.id.toUpperCase(),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Site name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                    labelText: 'Address', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: _slackController,
                decoration: const InputDecoration(
                    labelText: 'Slack channel', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Notes', border: OutlineInputBorder())),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Site'),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!,
                  style: const TextStyle(
                      color: Color(0xFF15803D), fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 24),
            Text('Site Jobs',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (widget.jobs.isEmpty)
              const Text('No jobs linked to this site yet.',
                  style: TextStyle(color: Color(0xFF64748B)))
            else
              ...widget.jobs.take(12).map((job) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => widget.onJobSelected(job),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.work_outline,
                                size: 18, color: Color(0xFF0B5ED7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${job.status.label} - ${job.title}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const Icon(Icons.edit_outlined, size: 16),
                          ],
                        ),
                      ),
                    ),
                  )),
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
    await widget.onSave(widget.site.copyWith(
      name: _nameController.text.trim().isEmpty
          ? widget.site.name
          : _nameController.text.trim(),
      address: _addressController.text.trim(),
      slackChannel: _slackController.text.trim(),
      notes: _notesController.text.trim(),
    ));
    if (mounted) {
      setState(() {
        _saving = false;
        _message = 'Site saved.';
      });
    }
  }
}
