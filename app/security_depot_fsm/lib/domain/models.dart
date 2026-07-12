enum JobType {
  serviceCall,
  installation,
  project,
  maintenance,
  inspection,
}

enum GoogleConnectionStatus { disconnected, connected, expired }

class GoogleConnectionState {
  const GoogleConnectionState({
    required this.status,
    this.accountEmail,
    this.expiresAt,
  });
  final GoogleConnectionStatus status;
  final String? accountEmail;
  final DateTime? expiresAt;
  bool get isConnected => status == GoogleConnectionStatus.connected;
}

class SyncStatus {
  const SyncStatus({required this.status, this.lastSyncedAt, this.errorCode});
  final String status;
  final DateTime? lastSyncedAt;
  final String? errorCode;
  DateTime? get nextSyncAt => lastSyncedAt?.add(const Duration(seconds: 90));
}

enum ServiceCategory {
  intercom,
  accessControl,
  cameras,
  cableManagement,
  other
}

extension ServiceCategoryLabel on ServiceCategory {
  String get label => switch (this) {
        ServiceCategory.intercom => 'Intercom',
        ServiceCategory.accessControl => 'Access Control',
        ServiceCategory.cameras => 'Cameras/CCTV',
        ServiceCategory.cableManagement => 'Cable Management',
        ServiceCategory.other => 'Other',
      };
}

class EmailMessage {
  const EmailMessage({
    required this.id,
    required this.sender,
    required this.subject,
    required this.body,
    required this.receivedAt,
    required this.isRead,
    required this.labels,
    this.recipients = '',
    this.attachmentNames = const [],
    this.linkedJobId,
  });

  final String id;
  final String sender;
  final String recipients;
  final String subject;
  final String body;
  final DateTime receivedAt;
  final bool isRead;
  final List<String> labels;
  final List<String> attachmentNames;
  final String? linkedJobId;

  bool get isLinked => linkedJobId != null && linkedJobId!.isNotEmpty;
}

class ManagerNotification {
  const ManagerNotification(
      {required this.id,
      required this.kind,
      required this.title,
      required this.message,
      required this.createdAt,
      required this.isRead,
      this.jobId});
  final int id;
  final String kind;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? jobId;
}

class DispatchRequest {
  const DispatchRequest(
      {required this.emailId,
      required this.siteId,
      required this.title,
      required this.category,
      required this.priority,
      required this.technicianId,
      required this.start,
      required this.end,
      required this.instructions});
  final String emailId;
  final String siteId;
  final String title;
  final ServiceCategory category;
  final JobPriority priority;
  final String technicianId;
  final DateTime start;
  final DateTime end;
  final String instructions;
}

extension JobTypeLabel on JobType {
  String get label => switch (this) {
        JobType.serviceCall => 'Service Call',
        JobType.installation => 'Installation',
        JobType.project => 'Project',
        JobType.maintenance => 'Maintenance',
        JobType.inspection => 'Inspection',
      };
}

enum JobPriority {
  low,
  medium,
  high,
  urgent,
}

extension JobPriorityLabel on JobPriority {
  String get label => switch (this) {
        JobPriority.low => 'Low',
        JobPriority.medium => 'Medium',
        JobPriority.high => 'High',
        JobPriority.urgent => 'Urgent',
      };
}

enum JobStatus {
  newJob,
  scheduled,
  inProgress,
  waitingForParts,
  needReturnVisit,
  completed,
  needManagerReview,
}

extension JobStatusLabel on JobStatus {
  String get label => switch (this) {
        JobStatus.newJob => 'New',
        JobStatus.scheduled => 'Scheduled',
        JobStatus.inProgress => 'In Progress',
        JobStatus.waitingForParts => 'Waiting Parts',
        JobStatus.needReturnVisit => 'Need Return Visit',
        JobStatus.completed => 'Completed',
        JobStatus.needManagerReview => 'Manager Review',
      };
}

enum JobSource {
  email,
  calendar,
  slack,
  manual,
}

extension JobSourceLabel on JobSource {
  String get label => switch (this) {
        JobSource.email => 'Email',
        JobSource.calendar => 'Calendar',
        JobSource.slack => 'Slack',
        JobSource.manual => 'Manual',
      };
}

enum VisitStatus {
  completed,
  notCompleted,
  needReturnVisit,
  waitingForParts,
  couldNotAccessSite,
  needManagerReview,
}

extension VisitStatusLabel on VisitStatus {
  String get label => switch (this) {
        VisitStatus.completed => 'Completed',
        VisitStatus.notCompleted => 'Not Completed',
        VisitStatus.needReturnVisit => 'Need Return Visit',
        VisitStatus.waitingForParts => 'Waiting for Parts',
        VisitStatus.couldNotAccessSite => 'Could Not Access Site',
        VisitStatus.needManagerReview => 'Need Manager Review',
      };
}

enum PartsStatus {
  noPartsUsed,
  partsUsed,
  partsNeeded,
  waitingForParts,
  partsPickedUp,
  needToOrder,
}

extension PartsStatusLabel on PartsStatus {
  String get label => switch (this) {
        PartsStatus.noPartsUsed => 'No Parts Used',
        PartsStatus.partsUsed => 'Parts Used',
        PartsStatus.partsNeeded => 'Parts Needed',
        PartsStatus.waitingForParts => 'Waiting for Parts',
        PartsStatus.partsPickedUp => 'Parts Picked Up',
        PartsStatus.needToOrder => 'Need to Order',
      };
}

class Technician {
  const Technician({
    required this.id,
    required this.name,
    required this.email,
    required this.initials,
  });

  final String id;
  final String name;
  final String email;
  final String initials;

  Technician copyWith({
    String? name,
    String? email,
    String? initials,
  }) {
    return Technician(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      initials: initials ?? this.initials,
    );
  }
}

class Site {
  const Site({
    required this.id,
    required this.name,
    required this.address,
    this.slackChannel,
    this.notes,
  });

  final String id;
  final String name;
  final String address;
  final String? slackChannel;
  final String? notes;

  Site copyWith({
    String? name,
    String? address,
    String? slackChannel,
    String? notes,
  }) {
    return Site(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      slackChannel: slackChannel ?? this.slackChannel,
      notes: notes ?? this.notes,
    );
  }
}

class Job {
  const Job({
    required this.id,
    required this.title,
    required this.siteId,
    required this.siteName,
    required this.address,
    required this.type,
    required this.priority,
    required this.status,
    required this.assignedTechnicianId,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.description,
    required this.source,
  });

  final String id;
  final String title;
  final String siteId;
  final String siteName;
  final String address;
  final JobType type;
  final JobPriority priority;
  final JobStatus status;
  final String assignedTechnicianId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String description;
  final JobSource source;

  bool get isOpen => status != JobStatus.completed;

  bool get needsFollowUp =>
      status == JobStatus.waitingForParts ||
      status == JobStatus.needReturnVisit ||
      status == JobStatus.needManagerReview;

  Job copyWith({
    String? title,
    String? siteId,
    String? siteName,
    String? address,
    JobType? type,
    JobPriority? priority,
    JobStatus? status,
    String? assignedTechnicianId,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? description,
    JobSource? source,
  }) {
    return Job(
      id: id,
      title: title ?? this.title,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      address: address ?? this.address,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedTechnicianId: assignedTechnicianId ?? this.assignedTechnicianId,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      description: description ?? this.description,
      source: source ?? this.source,
    );
  }
}

class Visit {
  const Visit({
    required this.id,
    required this.jobId,
    required this.siteId,
    required this.technicianId,
    required this.start,
    required this.end,
    required this.status,
    required this.workDone,
    required this.partsStatus,
  });

  final String id;
  final String jobId;
  final String siteId;
  final String technicianId;
  final DateTime start;
  final DateTime end;
  final VisitStatus status;
  final String workDone;
  final PartsStatus partsStatus;

  int get durationMinutes => end.difference(start).inMinutes;

  Visit copyWith({
    String? jobId,
    String? siteId,
    String? technicianId,
    DateTime? start,
    DateTime? end,
    VisitStatus? status,
    String? workDone,
    PartsStatus? partsStatus,
  }) {
    return Visit(
      id: id,
      jobId: jobId ?? this.jobId,
      siteId: siteId ?? this.siteId,
      technicianId: technicianId ?? this.technicianId,
      start: start ?? this.start,
      end: end ?? this.end,
      status: status ?? this.status,
      workDone: workDone ?? this.workDone,
      partsStatus: partsStatus ?? this.partsStatus,
    );
  }
}
