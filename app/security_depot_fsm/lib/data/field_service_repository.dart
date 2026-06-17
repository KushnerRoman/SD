import '../domain/models.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.newJobs,
    required this.inProgress,
    required this.waitingParts,
    required this.completed,
  });

  final int newJobs;
  final int inProgress;
  final int waitingParts;
  final int completed;
}

abstract class FieldServiceRepository {
  Future<List<Job>> getJobs();

  Future<void> addJob(Job job);

  Future<List<Site>> getSites();

  Future<void> addSite(Site site);

  Future<void> updateSite(Site site);

  Future<List<Technician>> getTechnicians();

  Future<void> addTechnician(Technician technician);

  Future<void> updateTechnician(Technician technician);

  Future<List<Visit>> getTodayVisits();

  Future<void> scheduleVisit(Visit visit);

  Future<DashboardSummary> getDashboardSummary();

  Future<void> updateJob(Job job);

  Future<void> saveVisitUpdate({
    required String visitId,
    required VisitStatus status,
    required String workDone,
    required PartsStatus partsStatus,
    String? technicianId,
    DateTime? start,
    DateTime? end,
  });
}
