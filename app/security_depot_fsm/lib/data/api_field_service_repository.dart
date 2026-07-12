import 'dart:convert';

import 'package:http/http.dart' as http;

import 'field_service_repository.dart';
import '../domain/models.dart';

class ApiFieldServiceRepository extends FieldServiceRepository {
  ApiFieldServiceRepository({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;

  @override
  Future<GoogleConnectionState> getGoogleConnection() async {
    final json = await _getMap('/google/connection');
    final value = _readString(json, 'status');
    return GoogleConnectionState(
      status: switch (value) {
        'connected' => GoogleConnectionStatus.connected,
        'expired' => GoogleConnectionStatus.expired,
        _ => GoogleConnectionStatus.disconnected,
      },
      accountEmail: _readString(json, 'account_email').isEmpty
          ? null
          : _readString(json, 'account_email'),
      expiresAt: DateTime.tryParse(_readString(json, 'expires_at'))?.toLocal(),
    );
  }

  @override
  Future<Uri> startGoogleConnection() async =>
      baseUrl.resolve('/auth/google/start');

  @override
  Future<void> disconnectGoogle() async {
    await _post('/auth/google/disconnect', {});
  }

  @override
  Future<SyncStatus> getGoogleSyncStatus() async {
    final json = await _getMap('/google/sync-status');
    return SyncStatus(
      status: _readString(json, 'status'),
      lastSyncedAt:
          DateTime.tryParse(_readString(json, 'last_synced_at'))?.toLocal(),
      errorCode: _readString(json, 'error_code').isEmpty
          ? null
          : _readString(json, 'error_code'),
    );
  }

  @override
  Future<SyncStatus> syncGoogleNow() async {
    final result = await _postMap('/google/sync', {});
    final previous = await getGoogleSyncStatus();
    return SyncStatus(
        status: _readString(result, 'status'),
        lastSyncedAt: previous.lastSyncedAt,
        errorCode: previous.errorCode,
        gmailAdded: _readInt(result, 'added'),
        gmailUpdated: _readInt(result, 'updated'),
        gmailDeleted: _readInt(result, 'deleted'),
        calendarDelivered: _readInt(result, 'calendar_delivered'));
  }

  @override
  Future<List<EmailMessage>> getEmails() async =>
      (await _getList('/emails')).map(_emailFromJson).toList();

  @override
  Future<void> dispatchFromEmail(DispatchRequest request) async {
    await _post('/dispatch/from-email', {
      'email_id': request.emailId,
      'site_id': request.siteId,
      'title': request.title,
      'category': request.category.label,
      'priority': request.priority.label,
      'technician_id': request.technicianId,
      'scheduled_start': request.start.toIso8601String(),
      'scheduled_end': request.end.toIso8601String(),
      'instructions': request.instructions,
    });
  }

  @override
  Future<List<ManagerNotification>> getNotifications() async =>
      (await _getList('/notifications')).map(_notificationFromJson).toList();

  @override
  Future<void> submitTechnicianReport(
      {required String visitId,
      required VisitStatus status,
      required int durationMinutes,
      required String workPerformed,
      String materialsUsed = '',
      String followUpNotes = ''}) async {
    final reportStatus = switch (status) {
      VisitStatus.completed => 'Completed',
      VisitStatus.needReturnVisit => 'Return Required',
      _ => 'Incomplete',
    };
    await _post('/visits/$visitId/report', {
      'status': reportStatus,
      'duration_minutes': durationMinutes,
      'work_performed': workPerformed,
      'materials_used': materialsUsed,
      'follow_up_notes': followUpNotes,
    });
  }

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    final json = await _getMap('/dashboard/summary');
    return DashboardSummary(
      newJobs: _readInt(json, 'new_jobs'),
      inProgress: _readInt(json, 'in_progress'),
      waitingParts: _readInt(json, 'waiting_parts'),
      completed: _readInt(json, 'completed'),
    );
  }

  @override
  Future<List<Job>> getJobs() async {
    final json = await _getList('/jobs');
    return json.map(_jobFromJson).toList();
  }

  @override
  Future<void> addJob(Job job) async {
    final response = await _client.post(
      baseUrl.resolve('/jobs'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(_jobToJson(job)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'API POST /jobs failed: ${response.statusCode} ${response.body}');
    }
  }

  @override
  Future<List<Site>> getSites() async {
    final json = await _getList('/sites');
    return json.map(_siteFromJson).toList();
  }

  @override
  Future<void> addSite(Site site) async {
    final response = await _client.post(
      baseUrl.resolve('/sites'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'id': site.id, ..._siteToJson(site)}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'API POST /sites failed: ${response.statusCode} ${response.body}');
    }
  }

  @override
  Future<void> updateSite(Site site) async {
    final response = await _client.patch(
      baseUrl.resolve('/sites/${site.id}'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(_siteToJson(site)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'API PATCH /sites/${site.id} failed: ${response.statusCode} ${response.body}');
    }
  }

  @override
  Future<List<Technician>> getTechnicians() async {
    final json = await _getList('/technicians');
    return json.map(_technicianFromJson).toList();
  }

  @override
  Future<void> addTechnician(Technician technician) async {
    final response = await _client.post(
      baseUrl.resolve('/technicians'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(_technicianToJson(technician)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'API POST /technicians failed: ${response.statusCode} ${response.body}');
    }
  }

  @override
  Future<void> updateTechnician(Technician technician) async {
    final response = await _client.patch(
      baseUrl.resolve('/technicians/${technician.id}'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(_technicianToJson(technician)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'API PATCH /technicians/${technician.id} failed: ${response.statusCode} ${response.body}');
    }
  }

  @override
  Future<List<Visit>> getTodayVisits() async {
    final json = await _getList('/visits');
    return json.map(_visitFromJson).toList();
  }

  @override
  Future<void> scheduleVisit(Visit visit) async {
    final response = await _client.post(
      baseUrl.resolve('/visits'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(_visitToJson(visit)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'API POST /visits failed: ${response.statusCode} ${response.body}');
    }
  }

  @override
  Future<void> updateJob(Job job) async {
    final response = await _client.patch(
      baseUrl.resolve('/jobs/${job.id}'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'site_id': job.siteId,
        'site_name': job.siteName,
        'title': job.title,
        'description': job.description,
        'details': job.description,
        'status': job.status.label,
        'priority': job.priority.label,
        'assigned_technician_id': job.assignedTechnicianId,
        'first_seen_date':
            job.scheduledStart.toIso8601String().split('T').first,
        'last_seen_date': job.scheduledEnd.toIso8601String().split('T').first,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'API PATCH /jobs/${job.id} failed: ${response.statusCode} ${response.body}');
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
    final response = await _client.patch(
      baseUrl.resolve('/visits/$visitId'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'status': status.label,
        'work_summary': workDone,
        'parts_status': partsStatus.label,
        if (technicianId != null) 'technician_id': technicianId,
        if (start != null) 'start_datetime': start.toIso8601String(),
        if (end != null) 'end_datetime': end.toIso8601String(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'API PATCH /visits/$visitId failed: ${response.statusCode} ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final response = await _client.get(baseUrl.resolve(path));
    if (response.statusCode != 200) {
      throw StateError(
          'API GET $path failed: ${response.statusCode} ${response.body}');
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final response = await _client.get(baseUrl.resolve(path));
    if (response.statusCode != 200) {
      throw StateError(
          'API GET $path failed: ${response.statusCode} ${response.body}');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    await _postMap(path, body);
  }

  Future<Map<String, dynamic>> _postMap(
      String path, Map<String, dynamic> body) async {
    final response = await _client.post(baseUrl.resolve(path),
        headers: {'content-type': 'application/json'}, body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body);
      final detail =
          decoded is Map<String, dynamic> ? decoded['detail'] : response.body;
      throw StateError(detail?.toString() ?? 'Request failed');
    }
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

EmailMessage _emailFromJson(Map<String, dynamic> json) => EmailMessage(
      id: _readString(json, 'id'),
      sender: _readString(json, 'sender'),
      recipients: _readString(json, 'recipients'),
      subject: _readString(json, 'subject'),
      body: _readString(json, 'body'),
      receivedAt: _dateTimeFromText(_readString(json, 'received_at')),
      isRead: _readBool(json, 'is_read'),
      labels: _readString(json, 'labels')
          .split(',')
          .where((value) => value.isNotEmpty)
          .toList(),
      attachmentNames: _readString(json, 'attachment_names')
          .split(',')
          .where((value) => value.isNotEmpty)
          .toList(),
      linkedJobId: _readString(json, 'linked_job_id').isEmpty
          ? null
          : _readString(json, 'linked_job_id'),
    );

ManagerNotification _notificationFromJson(Map<String, dynamic> json) =>
    ManagerNotification(
      id: _readInt(json, 'id'),
      kind: _readString(json, 'kind'),
      title: _readString(json, 'title'),
      message: _readString(json, 'message'),
      createdAt: _dateTimeFromText(_readString(json, 'created_at')),
      isRead: _readBool(json, 'is_read'),
      jobId: _readString(json, 'job_id').isEmpty
          ? null
          : _readString(json, 'job_id'),
    );

Site _siteFromJson(Map<String, dynamic> json) {
  return Site(
    id: _readString(json, 'id'),
    name: _readString(json, 'name'),
    address: _readString(json, 'address'),
    slackChannel: _readString(json, 'slack_channel').isEmpty
        ? null
        : _readString(json, 'slack_channel'),
    notes:
        _readBool(json, 'needs_manual_review') ? 'Needs manual review' : null,
  );
}

Map<String, dynamic> _siteToJson(Site site) {
  return {
    'name': site.name,
    'address': site.address,
    'slack_channel': site.slackChannel ?? '',
    'notes': site.notes ?? '',
  };
}

Technician _technicianFromJson(Map<String, dynamic> json) {
  return Technician(
    id: _readString(json, 'id'),
    name: _readString(json, 'name'),
    email: _readString(json, 'email'),
    initials: _readString(json, 'initials'),
  );
}

Map<String, dynamic> _technicianToJson(Technician technician) {
  return {
    'id': technician.id,
    'name': technician.name,
    'email': technician.email,
    'initials': technician.initials,
  };
}

Job _jobFromJson(Map<String, dynamic> json) {
  final details = _readString(json, 'details');
  final description =
      details.isNotEmpty ? details : _readString(json, 'description');
  return Job(
    id: _readString(json, 'id'),
    title: _readString(json, 'title'),
    siteId: _readString(json, 'site_id'),
    siteName: _readString(json, 'site_name'),
    address: '',
    type: _jobTypeFromText(_readString(json, 'job_type')),
    priority: _priorityFromText(_readString(json, 'priority')),
    status: _jobStatusFromText(_readString(json, 'status')),
    assignedTechnicianId: _readString(json, 'assigned_technician_id').isEmpty
        ? 'tech_roman'
        : _readString(json, 'assigned_technician_id'),
    scheduledStart: _dateFromText(_readString(json, 'first_seen_date')),
    scheduledEnd: _dateFromText(_readString(json, 'last_seen_date'))
        .add(const Duration(hours: 1)),
    description: description,
    source: JobSource.calendar,
  );
}

Map<String, dynamic> _jobToJson(Job job) {
  return {
    'id': job.id,
    'site_id': job.siteId,
    'site_name': job.siteName,
    'job_number': '',
    'title': job.title,
    'job_type': job.type.label,
    'priority': job.priority.label,
    'status': job.status.label,
    'assigned_technician_id': job.assignedTechnicianId,
    'first_seen_date': job.scheduledStart.toIso8601String().split('T').first,
    'last_seen_date': job.scheduledEnd.toIso8601String().split('T').first,
    'description': job.description,
    'details': job.description,
  };
}

Visit _visitFromJson(Map<String, dynamic> json) {
  final start = _dateTimeFromText(_readString(json, 'start_datetime'));
  final end = _dateTimeFromText(_readString(json, 'end_datetime'));
  return Visit(
    id: _readString(json, 'id'),
    jobId: _readString(json, 'job_id'),
    siteId: _readString(json, 'site_id'),
    technicianId: _readString(json, 'technician_id').isEmpty
        ? 'tech_roman'
        : _readString(json, 'technician_id'),
    start: start,
    end: end.isAfter(start) ? end : start.add(const Duration(hours: 1)),
    status: _visitStatusFromText(_readString(json, 'status')),
    workDone: _readString(json, 'work_summary'),
    partsStatus: _partsStatusFromText(_readString(json, 'parts_status')),
  );
}

Map<String, dynamic> _visitToJson(Visit visit) {
  return {
    'id': visit.id,
    'job_id': visit.jobId,
    'site_id': visit.siteId,
    'technician_id': visit.technicianId,
    'start_datetime': visit.start.toIso8601String(),
    'end_datetime': visit.end.toIso8601String(),
    'status': visit.status.label,
    'work_summary': visit.workDone,
    'parts_status': visit.partsStatus.label,
  };
}

String _readString(Map<String, dynamic> json, String key) =>
    (json[key] ?? '').toString();

int _readInt(Map<String, dynamic> json, String key) =>
    int.tryParse(_readString(json, key)) ?? 0;

bool _readBool(Map<String, dynamic> json, String key) =>
    json[key] == true || _readString(json, key).toUpperCase() == 'TRUE';

DateTime _dateFromText(String value) =>
    DateTime.tryParse(value) ?? DateTime(2026, 5, 29, 9);

DateTime _dateTimeFromText(String value) =>
    DateTime.tryParse(value)?.toLocal() ?? DateTime(2026, 5, 29, 9);

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
