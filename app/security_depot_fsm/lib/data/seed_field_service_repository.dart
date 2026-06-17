import 'dart:convert';

import 'package:flutter/services.dart';

import 'field_service_repository.dart';
import '../domain/models.dart';

class SeedFieldServiceRepository implements FieldServiceRepository {
  SeedFieldServiceRepository._({
    required List<Site> sites,
    required List<Job> jobs,
    required List<Visit> visits,
    required List<Technician> technicians,
  })  : _sites = sites,
        _jobs = jobs,
        _visits = visits,
        _technicians = technicians;

  factory SeedFieldServiceRepository.fromJsonString(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final siteMaps =
        (data['sites'] as List<dynamic>).cast<Map<String, dynamic>>();
    final jobMaps =
        (data['jobs'] as List<dynamic>).cast<Map<String, dynamic>>();
    final visitMaps =
        (data['visits'] as List<dynamic>).cast<Map<String, dynamic>>();
    final technicianMaps =
        (data['technicians'] as List<dynamic>).cast<Map<String, dynamic>>();

    final technicians = technicianMaps.map(_technicianFromJson).toList();
    final technicianIds = technicians
        .map((technician) => technician.id)
        .where((id) => id.isNotEmpty)
        .toList();
    final sites = siteMaps.map(_siteFromJson).toList();
    final siteById = {for (final site in sites) site.id: site};
    final jobs = _ensureOpenJobMix([
      for (var index = 0; index < jobMaps.length; index++)
        _jobFromJson(jobMaps[index], siteById, technicianIds, index),
    ]);
    final jobTechnicianById = {
      for (final job in jobs) job.id: job.assignedTechnicianId
    };
    final visits = [
      for (var index = 0; index < visitMaps.length; index++)
        _visitFromJson(
            visitMaps[index], technicianIds, index, jobTechnicianById),
    ];

    return SeedFieldServiceRepository._(
      sites: sites,
      jobs: jobs,
      visits: visits,
      technicians: technicians,
    );
  }

  static Future<SeedFieldServiceRepository> fromAsset(
      [String assetPath = 'assets/data/seed_data.json']) async {
    final source = await rootBundle.loadString(assetPath);
    return SeedFieldServiceRepository.fromJsonString(source);
  }

  final List<Site> _sites;
  final List<Job> _jobs;
  final List<Visit> _visits;
  final List<Technician> _technicians;

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    return DashboardSummary(
      newJobs: _jobs
          .where((job) =>
              job.status == JobStatus.newJob ||
              job.status == JobStatus.scheduled)
          .length,
      inProgress:
          _jobs.where((job) => job.status == JobStatus.inProgress).length,
      waitingParts:
          _jobs.where((job) => job.status == JobStatus.waitingForParts).length,
      completed: _jobs.where((job) => job.status == JobStatus.completed).length,
    );
  }

  @override
  Future<void> addJob(Job job) async {
    if (_jobs.any((item) => item.id == job.id)) {
      throw ArgumentError('Job already exists: ${job.id}');
    }
    _jobs.add(job);
  }

  @override
  Future<void> updateJob(Job job) async {
    final index = _jobs.indexWhere((item) => item.id == job.id);
    if (index == -1) {
      throw ArgumentError('Job not found: ${job.id}');
    }
    _jobs[index] = job;
  }

  @override
  Future<List<Job>> getJobs() async => List<Job>.unmodifiable(_jobs);

  @override
  Future<List<Site>> getSites() async => List<Site>.unmodifiable(_sites);

  @override
  Future<void> addSite(Site site) async {
    if (_sites.any((item) => item.id == site.id)) {
      throw ArgumentError('Site already exists: ${site.id}');
    }
    _sites.add(site);
  }

  @override
  Future<void> updateSite(Site site) async {
    final index = _sites.indexWhere((item) => item.id == site.id);
    if (index == -1) {
      throw ArgumentError('Site not found: ${site.id}');
    }
    _sites[index] = site;
  }

  @override
  Future<List<Technician>> getTechnicians() async =>
      List<Technician>.unmodifiable(_technicians);

  @override
  Future<void> addTechnician(Technician technician) async {
    if (_technicians.any((item) => item.id == technician.id)) {
      throw ArgumentError('Technician already exists: ${technician.id}');
    }
    _technicians.add(technician);
  }

  @override
  Future<void> updateTechnician(Technician technician) async {
    final index = _technicians.indexWhere((item) => item.id == technician.id);
    if (index == -1) {
      throw ArgumentError('Technician not found: ${technician.id}');
    }
    _technicians[index] = technician;
  }

  @override
  Future<List<Visit>> getTodayVisits() async =>
      List<Visit>.unmodifiable(_visits);

  @override
  Future<void> scheduleVisit(Visit visit) async {
    final index = _visits.indexWhere((item) => item.id == visit.id);
    if (index == -1) {
      _visits.add(visit);
    } else {
      _visits[index] = visit;
    }

    final jobIndex = _jobs.indexWhere((job) => job.id == visit.jobId);
    if (jobIndex != -1) {
      _jobs[jobIndex] = _jobs[jobIndex].copyWith(
        status: JobStatus.scheduled,
        assignedTechnicianId: visit.technicianId,
        scheduledStart: visit.start,
        scheduledEnd: visit.end,
      );
    }
  }

  @override
  Future<void> saveVisitUpdate({
    required String visitId,
    required VisitStatus status,
    required String workDone,
    required PartsStatus partsStatus,
    String? technicianId,
    DateTime? start,
    DateTime? end,
  }) async {
    final index = _visits.indexWhere((visit) => visit.id == visitId);
    if (index == -1) {
      throw ArgumentError('Visit not found: $visitId');
    }

    final updatedVisit = _visits[index].copyWith(
      status: status,
      workDone: workDone,
      partsStatus: partsStatus,
      technicianId: technicianId,
      start: start,
      end: end,
    );
    _visits[index] = updatedVisit;

    final jobIndex = _jobs.indexWhere((job) => job.id == updatedVisit.jobId);
    if (jobIndex != -1) {
      _jobs[jobIndex] = _jobs[jobIndex].copyWith(
        status: _jobStatusFromVisitStatus(status),
        assignedTechnicianId: updatedVisit.technicianId,
        scheduledStart: updatedVisit.start,
        scheduledEnd: updatedVisit.end,
      );
    }
  }
}

List<Job> _ensureOpenJobMix(List<Job> jobs) {
  final targetOpen = (jobs.length / 2).ceil();
  var openCount = jobs.where((job) => job.isOpen).length;
  if (openCount >= targetOpen) {
    return jobs;
  }

  var statusIndex = 0;
  const openStatuses = [
    JobStatus.scheduled,
    JobStatus.inProgress,
    JobStatus.waitingForParts,
    JobStatus.needReturnVisit,
    JobStatus.needManagerReview,
  ];

  return jobs.map((job) {
    if (openCount >= targetOpen || job.isOpen) {
      return job;
    }
    final status = openStatuses[statusIndex % openStatuses.length];
    statusIndex += 1;
    openCount += 1;
    return job.copyWith(status: status);
  }).toList();
}

Site _siteFromJson(Map<String, dynamic> json) {
  return Site(
    id: _readString(json, 'id'),
    name: _readString(json, 'name'),
    address: _readString(json, 'address'),
    slackChannel: _readString(json, 'slackChannel').isEmpty
        ? null
        : _readString(json, 'slackChannel'),
    notes: _readBool(json, 'needsManualReview') ? 'Needs manual review' : null,
  );
}

Technician _technicianFromJson(Map<String, dynamic> json) {
  return Technician(
    id: _readString(json, 'id'),
    name: _readString(json, 'name'),
    email: _readString(json, 'email'),
    initials: _readString(json, 'initials'),
  );
}

Job _jobFromJson(Map<String, dynamic> json, Map<String, Site> siteById,
    List<String> technicianIds, int index) {
  final siteId = _readString(json, 'siteId');
  final site = siteById[siteId];
  final siteName = _readString(json, 'siteName').isEmpty
      ? site?.name ?? 'Unknown Site'
      : _readString(json, 'siteName');
  final technicianId = technicianIds.isEmpty
      ? 'tech_roman'
      : technicianIds[index % technicianIds.length];
  return Job(
    id: _readString(json, 'id'),
    title: _readString(json, 'title').isEmpty
        ? 'Untitled Job'
        : _readString(json, 'title'),
    siteId: siteId,
    siteName: siteName,
    address: site?.address ?? '',
    type: _jobTypeFromText(_readString(json, 'type')),
    priority: _priorityFromText(_readString(json, 'priority')),
    status: _jobStatusFromText(_readString(json, 'status')),
    assignedTechnicianId: technicianId,
    scheduledStart: _dateFromText(_readString(json, 'firstSeenDate')),
    scheduledEnd: _dateFromText(_readString(json, 'lastSeenDate'))
        .add(const Duration(hours: 1)),
    description: _descriptionFromJob(json),
    source: JobSource.calendar,
  );
}

Visit _visitFromJson(Map<String, dynamic> json, List<String> technicianIds,
    int index, Map<String, String> jobTechnicianById) {
  final start = _dateTimeFromText(_readString(json, 'startDateTime'));
  final end = _dateTimeFromText(_readString(json, 'endDateTime'));
  final jobId = _readString(json, 'jobId');
  return Visit(
    id: _readString(json, 'id'),
    jobId: jobId,
    siteId: _readString(json, 'siteId'),
    technicianId: jobTechnicianById[jobId] ??
        (technicianIds.isEmpty
            ? 'tech_roman'
            : technicianIds[index % technicianIds.length]),
    start: start,
    end: end.isAfter(start) ? end : start.add(const Duration(hours: 1)),
    status: _visitStatusFromText(_readString(json, 'status')),
    workDone: _readString(json, 'workSummary'),
    partsStatus: _partsStatusFromText(_readString(json, 'partsStatus')),
  );
}

String _descriptionFromJob(Map<String, dynamic> json) {
  final parts = [
    if (_readString(json, 'jobNumber').isNotEmpty)
      'Job number: ${_readString(json, 'jobNumber')}',
    if (_readBool(json, 'needsParts')) 'Parts need attention.',
    if (_readBool(json, 'needsReturnVisit')) 'Return visit may be required.',
    if (_readBool(json, 'needsManagerReview')) 'Manager review required.',
    if (_readString(json, 'confidence').isNotEmpty)
      'Import confidence: ${_readString(json, 'confidence')}',
  ];
  return parts.isEmpty
      ? 'Imported from historical calendar data.'
      : parts.join('\n');
}

String _readString(Map<String, dynamic> json, String key) =>
    (json[key] ?? '').toString();

bool _readBool(Map<String, dynamic> json, String key) =>
    json[key] == true || _readString(json, key).toUpperCase() == 'TRUE';

DateTime _dateFromText(String value) {
  if (value.isEmpty) {
    return DateTime(2026, 5, 29, 9);
  }
  return DateTime.tryParse(value) ?? DateTime(2026, 5, 29, 9);
}

DateTime _dateTimeFromText(String value) {
  if (value.isEmpty) {
    return DateTime(2026, 5, 29, 9);
  }
  return DateTime.tryParse(value)?.toLocal() ?? DateTime(2026, 5, 29, 9);
}

JobType _jobTypeFromText(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('install')) return JobType.installation;
  if (normalized.contains('project')) return JobType.project;
  if (normalized.contains('maintenance')) return JobType.maintenance;
  if (normalized.contains('inspection')) return JobType.inspection;
  return JobType.serviceCall;
}

JobPriority _priorityFromText(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('urgent')) return JobPriority.urgent;
  if (normalized.contains('high')) return JobPriority.high;
  if (normalized.contains('low')) return JobPriority.low;
  return JobPriority.medium;
}

JobStatus _jobStatusFromText(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('complete')) return JobStatus.completed;
  if (normalized.contains('waiting')) return JobStatus.waitingForParts;
  if (normalized.contains('return')) return JobStatus.needReturnVisit;
  if (normalized.contains('review')) return JobStatus.needManagerReview;
  if (normalized.contains('progress')) return JobStatus.inProgress;
  if (normalized.contains('new')) return JobStatus.newJob;
  return JobStatus.scheduled;
}

VisitStatus _visitStatusFromText(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('not')) return VisitStatus.notCompleted;
  if (normalized.contains('complete')) return VisitStatus.completed;
  if (normalized.contains('return')) return VisitStatus.needReturnVisit;
  if (normalized.contains('waiting')) return VisitStatus.waitingForParts;
  if (normalized.contains('access')) return VisitStatus.couldNotAccessSite;
  if (normalized.contains('review')) return VisitStatus.needManagerReview;
  return VisitStatus.needManagerReview;
}

PartsStatus _partsStatusFromText(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('waiting')) return PartsStatus.waitingForParts;
  if (normalized.contains('order')) return PartsStatus.needToOrder;
  if (normalized.contains('needed')) return PartsStatus.partsNeeded;
  if (normalized.contains('used')) return PartsStatus.partsUsed;
  if (normalized.contains('picked')) return PartsStatus.partsPickedUp;
  return PartsStatus.noPartsUsed;
}

JobStatus _jobStatusFromVisitStatus(VisitStatus status) {
  return switch (status) {
    VisitStatus.completed => JobStatus.completed,
    VisitStatus.notCompleted => JobStatus.inProgress,
    VisitStatus.needReturnVisit => JobStatus.needReturnVisit,
    VisitStatus.waitingForParts => JobStatus.waitingForParts,
    VisitStatus.couldNotAccessSite => JobStatus.needManagerReview,
    VisitStatus.needManagerReview => JobStatus.needManagerReview,
  };
}
