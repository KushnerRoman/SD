import 'package:flutter_test/flutter_test.dart';
import 'package:security_depot_fsm/data/mock_field_service_repository.dart';
import 'package:security_depot_fsm/domain/models.dart';

void main() {
  test('mock repository returns jobs, sites, technicians, and visits',
      () async {
    final repository = MockFieldServiceRepository();

    expect(await repository.getJobs(), isNotEmpty);
    expect(await repository.getSites(), isNotEmpty);
    expect(await repository.getTechnicians(), isNotEmpty);
    expect(await repository.getTodayVisits(), isNotEmpty);
  });

  test('dashboard summary counts operational job states', () async {
    final repository = MockFieldServiceRepository();
    final summary = await repository.getDashboardSummary();

    expect(summary.newJobs, greaterThan(0));
    expect(summary.inProgress, greaterThan(0));
    expect(summary.waitingParts, greaterThan(0));
    expect(summary.completed, greaterThan(0));
  });

  test('saveVisitUpdate updates visit and related job status', () async {
    final repository = MockFieldServiceRepository();
    final visits = await repository.getTodayVisits();
    final visit = visits.first;

    await repository.saveVisitUpdate(
      visitId: visit.id,
      status: VisitStatus.completed,
      workDone: 'Checked reader, cleaned connections and tested.',
      partsStatus: PartsStatus.noPartsUsed,
    );

    final updatedVisit = (await repository.getTodayVisits())
        .firstWhere((item) => item.id == visit.id);
    final updatedJob = (await repository.getJobs())
        .firstWhere((item) => item.id == visit.jobId);

    expect(updatedVisit.status, VisitStatus.completed);
    expect(updatedVisit.workDone, contains('Checked reader'));
    expect(updatedJob.status, JobStatus.completed);
  });

  test('saveVisitUpdate can change technician and scheduled time', () async {
    final repository = MockFieldServiceRepository();
    final visit = (await repository.getTodayVisits()).first;

    await repository.saveVisitUpdate(
      visitId: visit.id,
      status: VisitStatus.notCompleted,
      workDone: 'Moved to Dex for afternoon.',
      partsStatus: PartsStatus.noPartsUsed,
      technicianId: 'tech_dex',
      start: DateTime(2026, 6, 1, 14),
      end: DateTime(2026, 6, 1, 15),
    );

    final updatedVisit = (await repository.getTodayVisits())
        .firstWhere((item) => item.id == visit.id);
    final updatedJob = (await repository.getJobs())
        .firstWhere((item) => item.id == visit.jobId);

    expect(updatedVisit.technicianId, 'tech_dex');
    expect(updatedVisit.start.hour, 14);
    expect(updatedJob.assignedTechnicianId, 'tech_dex');
    expect(updatedJob.scheduledStart.hour, 14);
  });

  test('updateJob persists editable job fields', () async {
    final repository = MockFieldServiceRepository();
    final job = (await repository.getJobs()).first;

    final updated = job.copyWith(
      title: 'Updated reader issue',
      description: 'Updated job notes for manual testing.',
      status: JobStatus.inProgress,
      priority: JobPriority.high,
      assignedTechnicianId: 'tech_dex',
    );

    await repository.updateJob(updated);

    final saved =
        (await repository.getJobs()).firstWhere((item) => item.id == job.id);
    expect(saved.title, 'Updated reader issue');
    expect(saved.description, 'Updated job notes for manual testing.');
    expect(saved.status, JobStatus.inProgress);
    expect(saved.priority, JobPriority.high);
    expect(saved.assignedTechnicianId, 'tech_dex');
  });

  test('repository can add and update technicians', () async {
    final repository = MockFieldServiceRepository();

    await repository.addTechnician(const Technician(
      id: 'tech_sam',
      name: 'Sam',
      email: 'sam@securitydepot.ca',
      initials: 'SM',
    ));
    await repository.updateTechnician(const Technician(
      id: 'tech_sam',
      name: 'Sam Installer',
      email: 'sam.installer@securitydepot.ca',
      initials: 'SI',
    ));

    final technicians = await repository.getTechnicians();
    final saved =
        technicians.singleWhere((technician) => technician.id == 'tech_sam');
    expect(saved.name, 'Sam Installer');
    expect(saved.email, 'sam.installer@securitydepot.ca');
    expect(saved.initials, 'SI');
  });

  test('updateSite persists editable site fields', () async {
    final repository = MockFieldServiceRepository();
    final site = (await repository.getSites()).first;

    await repository.updateSite(site.copyWith(
      name: 'Edited Site',
      address: '123 Edited Street',
      slackChannel: '#edited-site',
      notes: 'Updated manually.',
    ));

    final saved =
        (await repository.getSites()).firstWhere((item) => item.id == site.id);
    expect(saved.name, 'Edited Site');
    expect(saved.address, '123 Edited Street');
    expect(saved.slackChannel, '#edited-site');
    expect(saved.notes, 'Updated manually.');
  });

  test('repository can add jobs and sites', () async {
    final repository = MockFieldServiceRepository();

    await repository.addSite(const Site(
      id: 'site_manual',
      name: 'Manual Site',
      address: '99 Manual Road',
      slackChannel: '#manual-site',
    ));
    await repository.addJob(Job(
      id: 'job_manual',
      title: 'Manual service call',
      siteId: 'site_manual',
      siteName: 'Manual Site',
      address: '99 Manual Road',
      type: JobType.serviceCall,
      priority: JobPriority.medium,
      status: JobStatus.newJob,
      assignedTechnicianId: 'tech_roman',
      scheduledStart: DateTime(2026, 6, 1, 9),
      scheduledEnd: DateTime(2026, 6, 1, 10),
      description: 'Created manually.',
      source: JobSource.manual,
    ));

    expect(
        (await repository.getSites()).any((site) => site.id == 'site_manual'),
        isTrue);
    expect((await repository.getJobs()).any((job) => job.id == 'job_manual'),
        isTrue);
  });

  test('scheduleVisit creates a visit and marks the job scheduled', () async {
    final repository = MockFieldServiceRepository();
    final job = (await repository.getJobs()).first;

    await repository.scheduleVisit(Visit(
      id: 'visit_${job.id}',
      jobId: job.id,
      siteId: job.siteId,
      technicianId: 'tech_dex',
      start: DateTime(2026, 6, 1, 14),
      end: DateTime(2026, 6, 1, 15),
      status: VisitStatus.notCompleted,
      workDone: '',
      partsStatus: PartsStatus.noPartsUsed,
    ));

    final visit = (await repository.getTodayVisits())
        .firstWhere((item) => item.id == 'visit_${job.id}');
    final updatedJob =
        (await repository.getJobs()).firstWhere((item) => item.id == job.id);

    expect(visit.technicianId, 'tech_dex');
    expect(updatedJob.status, JobStatus.scheduled);
    expect(updatedJob.assignedTechnicianId, 'tech_dex');
    expect(updatedJob.scheduledStart.hour, 14);
  });

  test('scheduleVisit can transfer an existing job to another technician',
      () async {
    final repository = MockFieldServiceRepository();
    final job = (await repository.getJobs())
        .firstWhere((item) => item.assignedTechnicianId != 'tech_mike');

    await repository.updateJob(job.copyWith(
      assignedTechnicianId: 'tech_mike',
      status: JobStatus.scheduled,
      scheduledStart: DateTime(2026, 6, 2, 11),
      scheduledEnd: DateTime(2026, 6, 2, 12),
    ));
    await repository.scheduleVisit(Visit(
      id: 'visit_${job.id}',
      jobId: job.id,
      siteId: job.siteId,
      technicianId: 'tech_mike',
      start: DateTime(2026, 6, 2, 11),
      end: DateTime(2026, 6, 2, 12),
      status: VisitStatus.notCompleted,
      workDone: '',
      partsStatus: PartsStatus.noPartsUsed,
    ));

    final updatedJob =
        (await repository.getJobs()).firstWhere((item) => item.id == job.id);
    final visit = (await repository.getTodayVisits())
        .firstWhere((item) => item.id == 'visit_${job.id}');

    expect(updatedJob.assignedTechnicianId, 'tech_mike');
    expect(updatedJob.status, JobStatus.scheduled);
    expect(visit.technicianId, 'tech_mike');
  });
}
