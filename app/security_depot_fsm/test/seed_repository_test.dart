import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:security_depot_fsm/data/seed_field_service_repository.dart';
import 'package:security_depot_fsm/domain/models.dart';

void main() {
  test('seed repository loads historical jobs, sites, and visits from JSON',
      () async {
    final json = await File('assets/data/seed_data.json').readAsString();
    final repository = SeedFieldServiceRepository.fromJsonString(json);

    expect(await repository.getSites(), hasLength(130));
    expect(await repository.getJobs(), hasLength(115));
    expect(await repository.getTodayVisits(), hasLength(180));
  });

  test('seed repository saves a visit update locally', () async {
    final json = await File('assets/data/seed_data.json').readAsString();
    final repository = SeedFieldServiceRepository.fromJsonString(json);
    final visit = (await repository.getTodayVisits()).first;

    await repository.saveVisitUpdate(
      visitId: visit.id,
      status: VisitStatus.completed,
      workDone: 'Manual test update',
      partsStatus: PartsStatus.noPartsUsed,
    );

    final updated = (await repository.getTodayVisits())
        .firstWhere((item) => item.id == visit.id);
    expect(updated.status, VisitStatus.completed);
    expect(updated.workDone, 'Manual test update');
  });

  test(
      'seed repository keeps at least half of jobs open for assignment testing',
      () async {
    final json = await File('assets/data/seed_data.json').readAsString();
    final repository = SeedFieldServiceRepository.fromJsonString(json);
    final jobs = await repository.getJobs();
    final openJobs = jobs.where((job) => job.isOpen).length;

    expect(openJobs, greaterThanOrEqualTo((jobs.length / 2).ceil()));
  });

  test('seed repository updates job assignment and text in memory', () async {
    final json = await File('assets/data/seed_data.json').readAsString();
    final repository = SeedFieldServiceRepository.fromJsonString(json);
    final job = (await repository.getJobs()).first;

    await repository.updateJob(job.copyWith(
      title: 'Edited historical job',
      description: 'Manual edit saved in local repository.',
      status: JobStatus.needReturnVisit,
      priority: JobPriority.urgent,
      assignedTechnicianId: 'tech_mike',
    ));

    final saved =
        (await repository.getJobs()).firstWhere((item) => item.id == job.id);
    expect(saved.title, 'Edited historical job');
    expect(saved.description, 'Manual edit saved in local repository.');
    expect(saved.status, JobStatus.needReturnVisit);
    expect(saved.priority, JobPriority.urgent);
    expect(saved.assignedTechnicianId, 'tech_mike');
  });

  test(
      'seed repository distributes historical work across multiple technicians',
      () async {
    final json = await File('assets/data/seed_data.json').readAsString();
    final repository = SeedFieldServiceRepository.fromJsonString(json);

    final jobs = await repository.getJobs();
    final assignedTechnicians =
        jobs.map((job) => job.assignedTechnicianId).toSet();

    expect(assignedTechnicians.length, greaterThanOrEqualTo(3));
  });

  test('seed repository can add and update technicians', () async {
    final json = await File('assets/data/seed_data.json').readAsString();
    final repository = SeedFieldServiceRepository.fromJsonString(json);

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

    final saved = (await repository.getTechnicians())
        .singleWhere((technician) => technician.id == 'tech_sam');
    expect(saved.name, 'Sam Installer');
    expect(saved.initials, 'SI');
  });

  test('seed repository updates site details in memory', () async {
    final json = await File('assets/data/seed_data.json').readAsString();
    final repository = SeedFieldServiceRepository.fromJsonString(json);
    final site = (await repository.getSites()).first;

    await repository.updateSite(site.copyWith(
      name: 'Edited historical site',
      address: '777 Manual Review Ave',
      slackChannel: '#manual-review',
      notes: 'Confirmed by manager.',
    ));

    final saved =
        (await repository.getSites()).firstWhere((item) => item.id == site.id);
    expect(saved.name, 'Edited historical site');
    expect(saved.address, '777 Manual Review Ave');
    expect(saved.slackChannel, '#manual-review');
    expect(saved.notes, 'Confirmed by manager.');
  });
}
