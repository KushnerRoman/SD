import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:security_depot_fsm/data/api_field_service_repository.dart';
import 'package:security_depot_fsm/domain/models.dart';

void main() {
  test('API repository maps jobs and preserves details', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/jobs') {
        return http.Response(
            '''
[
  {
    "id": "job_1",
    "site_id": "site_1",
    "site_name": "Bella Vista",
    "job_number": "J1",
    "title": "Reader issue",
    "job_type": "Service Call",
    "priority": "Urgent",
    "status": "In Progress",
    "assigned_technician_id": "tech_dex",
    "first_seen_date": "2026-05-29",
    "last_seen_date": "2026-05-29",
    "description": "Short description",
    "details": "Full calendar details",
    "needs_parts": true,
    "needs_return_visit": false,
    "needs_manager_review": false,
    "confidence": "medium",
    "calendar_details": []
  }
]
''',
            200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('not found', 404);
    });

    final repository = ApiFieldServiceRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'), client: client);
    final jobs = await repository.getJobs();

    expect(jobs.single.id, 'job_1');
    expect(jobs.single.status, JobStatus.inProgress);
    expect(jobs.single.priority, JobPriority.urgent);
    expect(jobs.single.description, contains('Full calendar details'));
  });

  test('API repository posts and patches technicians', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '{"id":"tech_sam","name":"Sam","email":"sam@securitydepot.ca","initials":"SM"}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = ApiFieldServiceRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'), client: client);

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

    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, '/technicians');
    expect(requests[1].method, 'PATCH');
    expect(requests[1].url.path, '/technicians/tech_sam');
    expect(requests[1].body, contains('Sam Installer'));
  });

  test('API repository patches sites and visits', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    });
    final repository = ApiFieldServiceRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'), client: client);

    await repository.updateSite(const Site(
      id: 'site_1',
      name: 'Edited Site',
      address: '123 Edited Street',
      slackChannel: '#edited',
      notes: 'Confirmed',
    ));
    await repository.saveVisitUpdate(
      visitId: 'visit_1',
      status: VisitStatus.completed,
      workDone: 'Finished work',
      partsStatus: PartsStatus.partsUsed,
      technicianId: 'tech_dex',
      start: DateTime(2026, 6, 1, 14),
      end: DateTime(2026, 6, 1, 15),
    );

    expect(requests[0].method, 'PATCH');
    expect(requests[0].url.path, '/sites/site_1');
    expect(requests[0].body, contains('Edited Site'));
    expect(requests[1].method, 'PATCH');
    expect(requests[1].url.path, '/visits/visit_1');
    expect(requests[1].body, contains('Finished work'));
    expect(requests[1].body, contains('tech_dex'));
    expect(requests[1].body, contains('2026-06-01T14:00:00'));
  });

  test('API repository posts jobs and sites', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    });
    final repository = ApiFieldServiceRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'), client: client);

    await repository.addSite(const Site(
        id: 'site_manual', name: 'Manual Site', address: '99 Manual Road'));
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

    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, '/sites');
    expect(requests[1].method, 'POST');
    expect(requests[1].url.path, '/jobs');
    expect(requests[1].body, contains('Manual service call'));
  });

  test('API repository schedules visits', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    });
    final repository = ApiFieldServiceRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'), client: client);

    await repository.scheduleVisit(Visit(
      id: 'visit_job_manual',
      jobId: 'job_manual',
      siteId: 'site_manual',
      technicianId: 'tech_dex',
      start: DateTime(2026, 6, 1, 14),
      end: DateTime(2026, 6, 1, 15),
      status: VisitStatus.notCompleted,
      workDone: '',
      partsStatus: PartsStatus.noPartsUsed,
    ));

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/visits');
    expect(requests.single.body, contains('visit_job_manual'));
    expect(requests.single.body, contains('tech_dex'));
  });

  test('API repository maps mixed inbox and dispatches from email', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/emails') {
        return http.Response(
            '[{"id":"mail-1","sender":"client@example.com","recipients":"service@example.com","subject":"Camera offline","body":"Lobby camera is down","received_at":"2026-07-11T08:00:00","labels":"Inbox,Service","is_read":false,"attachment_names":"","linked_job_id":null}]',
            200);
      }
      return http.Response('{}', 200);
    });
    final repository = ApiFieldServiceRepository(
        baseUrl: Uri.parse('http://127.0.0.1:8000'), client: client);
    final emails = await repository.getEmails();
    await repository.dispatchFromEmail(DispatchRequest(
      emailId: 'mail-1',
      siteId: 'site-1',
      title: 'Camera offline',
      category: ServiceCategory.cameras,
      priority: JobPriority.urgent,
      technicianId: 'tech-1',
      start: DateTime(2026, 7, 13, 9),
      end: DateTime(2026, 7, 13, 10),
      instructions: 'Restore camera',
    ));
    expect(emails.single.labels, contains('Service'));
    expect(requests.last.url.path, '/dispatch/from-email');
    expect(requests.last.body, contains('Cameras/CCTV'));
  });
}
