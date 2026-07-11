import 'field_service_repository.dart';
import '../domain/models.dart';

class MockFieldServiceRepository extends FieldServiceRepository {
  MockFieldServiceRepository()
      : _jobs = List<Job>.from(_seedJobs),
        _visits = List<Visit>.from(_seedVisits),
        _technicians = List<Technician>.from(_seedTechnicians),
        _sites = List<Site>.from(_seedSites);

  final List<Job> _jobs;
  final List<Visit> _visits;
  final List<Technician> _technicians;
  final List<Site> _sites;

  @override
  Future<List<Job>> getJobs() async => List<Job>.unmodifiable(_jobs);

  @override
  Future<void> addJob(Job job) async {
    if (_jobs.any((item) => item.id == job.id)) {
      throw ArgumentError('Job already exists: ${job.id}');
    }
    _jobs.add(job);
  }

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
  Future<void> updateJob(Job job) async {
    final index = _jobs.indexWhere((item) => item.id == job.id);
    if (index == -1) {
      throw ArgumentError('Job not found: ${job.id}');
    }
    _jobs[index] = job;
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
    final visitIndex = _visits.indexWhere((visit) => visit.id == visitId);
    if (visitIndex == -1) {
      throw ArgumentError('Visit not found: $visitId');
    }

    final updatedVisit = _visits[visitIndex].copyWith(
      status: status,
      workDone: workDone,
      partsStatus: partsStatus,
      technicianId: technicianId,
      start: start,
      end: end,
    );
    _visits[visitIndex] = updatedVisit;

    final jobIndex = _jobs.indexWhere((job) => job.id == updatedVisit.jobId);
    if (jobIndex == -1) {
      return;
    }

    _jobs[jobIndex] = _jobs[jobIndex].copyWith(
      status: _jobStatusFromVisitStatus(status),
      assignedTechnicianId: updatedVisit.technicianId,
      scheduledStart: updatedVisit.start,
      scheduledEnd: updatedVisit.end,
    );
  }
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

final _today = DateTime(2026, 5, 29);

const List<Technician> _seedTechnicians = [
  Technician(
      id: 'tech_roman',
      name: 'Roman Kushner',
      email: 'roman.kushner@gmail.com',
      initials: 'RK'),
  Technician(
      id: 'tech_dex',
      name: 'Dex',
      email: 'dex@securitydepot.ca',
      initials: 'DX'),
  Technician(
      id: 'tech_mike',
      name: 'Mike',
      email: 'mike@securitydepot.ca',
      initials: 'MK'),
  Technician(
      id: 'tech_alan',
      name: 'Alan',
      email: 'alan@securitydepot.ca',
      initials: 'AL'),
];

const List<Site> _seedSites = [
  Site(
    id: 'site_bella_vista',
    name: 'Bella Vista Condominiums',
    address: '200 Redstone Walk NE, Calgary, AB',
    slackChannel: '#bella-vista',
  ),
  Site(
    id: 'site_rocky_ridge',
    name: 'Rocky Ridge Landing',
    address: '500 Rocky Vista Gardens NW, Calgary, AB',
    slackChannel: '#rocky-ridge-landing',
  ),
  Site(
    id: 'site_gateway',
    name: 'Gateway Garrisonwood',
    address: '2233 34 Avenue SW, Calgary, AB',
    slackChannel: '#gatewaygarrisonwood',
  ),
  Site(
    id: 'site_copperfield',
    name: 'Copperfield Park 2',
    address: '755 Copperpond Blvd SE, Calgary, AB',
    slackChannel: '#copperfield-park',
  ),
];

final List<Job> _seedJobs = [
  Job(
    id: 'job_2487',
    title: 'Front Door Reader',
    siteId: 'site_bella_vista',
    siteName: 'Bella Vista Condominiums',
    address: '200 Redstone Walk NE, Calgary, AB',
    type: JobType.serviceCall,
    priority: JobPriority.medium,
    status: JobStatus.scheduled,
    assignedTechnicianId: 'tech_roman',
    scheduledStart: DateTime(_today.year, _today.month, _today.day, 10, 30),
    scheduledEnd: DateTime(_today.year, _today.month, _today.day, 11, 30),
    description: 'Front door reader not working. Please check and advise.',
    source: JobSource.email,
  ),
  Job(
    id: 'job_2488',
    title: 'Intercom Issue',
    siteId: 'site_rocky_ridge',
    siteName: 'Rocky Ridge Landing',
    address: '500 Rocky Vista Gardens NW, Calgary, AB',
    type: JobType.serviceCall,
    priority: JobPriority.high,
    status: JobStatus.inProgress,
    assignedTechnicianId: 'tech_roman',
    scheduledStart: DateTime(_today.year, _today.month, _today.day, 13),
    scheduledEnd: DateTime(_today.year, _today.month, _today.day, 14),
    description: 'Resident reports intercom call not reaching phone.',
    source: JobSource.calendar,
  ),
  Job(
    id: 'job_23327',
    title: 'IO Smart Reader Replacement',
    siteId: 'site_gateway',
    siteName: 'Gateway Garrisonwood',
    address: '2233 34 Avenue SW, Calgary, AB',
    type: JobType.project,
    priority: JobPriority.medium,
    status: JobStatus.waitingForParts,
    assignedTechnicianId: 'tech_dex',
    scheduledStart: DateTime(_today.year, _today.month, _today.day, 15),
    scheduledEnd: DateTime(_today.year, _today.month, _today.day, 16, 30),
    description:
        'Changing readers to IO Smart. Confirm slim line reader count.',
    source: JobSource.email,
  ),
  Job(
    id: 'job_23724',
    title: 'Access Control Follow-up',
    siteId: 'site_copperfield',
    siteName: 'Copperfield Park 2',
    address: '755 Copperpond Blvd SE, Calgary, AB',
    type: JobType.serviceCall,
    priority: JobPriority.low,
    status: JobStatus.completed,
    assignedTechnicianId: 'tech_mike',
    scheduledStart: DateTime(_today.year, _today.month, _today.day - 1, 9),
    scheduledEnd: DateTime(_today.year, _today.month, _today.day - 1, 10, 15),
    description: 'Checked controller and tested door schedule.',
    source: JobSource.calendar,
  ),
];

final List<Visit> _seedVisits = [
  Visit(
    id: 'visit_0001',
    jobId: 'job_2487',
    siteId: 'site_bella_vista',
    technicianId: 'tech_roman',
    start: DateTime(_today.year, _today.month, _today.day, 10, 30),
    end: DateTime(_today.year, _today.month, _today.day, 11, 30),
    status: VisitStatus.notCompleted,
    workDone: '',
    partsStatus: PartsStatus.noPartsUsed,
  ),
  Visit(
    id: 'visit_0002',
    jobId: 'job_2488',
    siteId: 'site_rocky_ridge',
    technicianId: 'tech_roman',
    start: DateTime(_today.year, _today.month, _today.day, 13),
    end: DateTime(_today.year, _today.month, _today.day, 14),
    status: VisitStatus.needManagerReview,
    workDone: 'Need to confirm programming issue with manager.',
    partsStatus: PartsStatus.noPartsUsed,
  ),
  Visit(
    id: 'visit_0003',
    jobId: 'job_23327',
    siteId: 'site_gateway',
    technicianId: 'tech_dex',
    start: DateTime(_today.year, _today.month, _today.day, 15),
    end: DateTime(_today.year, _today.month, _today.day, 16, 30),
    status: VisitStatus.waitingForParts,
    workDone: 'Reader count confirmed. Waiting for parts.',
    partsStatus: PartsStatus.waitingForParts,
  ),
];
