import 'package:flutter_test/flutter_test.dart';
import 'package:security_depot_fsm/domain/models.dart';

void main() {
  test('operations models expose service categories and linked email state',
      () {
    expect(ServiceCategory.cameras.label, 'Cameras/CCTV');
    final email = EmailMessage(
      id: 'mail-1',
      sender: 'client@example.com',
      subject: 'Camera offline',
      body: 'Lobby camera is down',
      receivedAt: DateTime(2026, 7, 11, 8),
      isRead: false,
      labels: const ['Inbox', 'Service'],
    );
    expect(email.isLinked, isFalse);
  });
  test('JobStatus exposes user-facing labels', () {
    expect(JobStatus.waitingForParts.label, 'Waiting Parts');
    expect(JobStatus.needReturnVisit.label, 'Need Return Visit');
  });

  test('Job identifies open and follow-up states', () {
    final job = Job(
      id: 'job_0001',
      title: 'Front Door Reader',
      siteId: 'site_0001',
      siteName: 'Bella Vista Condominiums',
      address: '200 Redstone Walk NE, Calgary, AB',
      type: JobType.serviceCall,
      priority: JobPriority.medium,
      status: JobStatus.waitingForParts,
      assignedTechnicianId: 'tech_roman',
      scheduledStart: DateTime.utc(2026, 5, 29, 16, 30),
      scheduledEnd: DateTime.utc(2026, 5, 29, 17, 30),
      description: 'Front door reader not working.',
      source: JobSource.email,
    );

    expect(job.isOpen, isTrue);
    expect(job.needsFollowUp, isTrue);
  });
}
