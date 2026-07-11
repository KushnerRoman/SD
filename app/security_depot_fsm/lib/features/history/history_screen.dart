import 'package:flutter/material.dart';

import '../../data/field_service_repository.dart';
import '../../domain/models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.repository});
  final FieldServiceRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Service History',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const Text(
              'Search completed work, incomplete visits, and return requirements'),
          const SizedBox(height: 18),
          TextField(
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search customer, site, technician, or work'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Job>>(
              future: widget.repository.getJobs(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final jobs = snapshot.data!
                    .where((job) => !job.isOpen || job.needsFollowUp)
                    .where((job) =>
                        '${job.title} ${job.siteName} ${job.description}'
                            .toLowerCase()
                            .contains(_query))
                    .toList();
                if (jobs.isEmpty) {
                  return const Card(
                      child: Center(
                          child:
                              Text('No historical work matches your search.')));
                }
                return Card(
                  child: ListView.separated(
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final job = jobs[index];
                      final completed = job.status == JobStatus.completed;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: completed
                              ? const Color(0xFFE6F4EA)
                              : const Color(0xFFFFF3E0),
                          child: Icon(completed ? Icons.check : Icons.refresh,
                              color: completed ? Colors.green : Colors.orange),
                        ),
                        title: Text(job.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${job.siteName} · ${job.description}',
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Chip(label: Text(job.status.label)),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
