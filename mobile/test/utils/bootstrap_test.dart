import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/utils/bootstrap.dart';

void main() {
  test('cleanupLegacyBackupTasks removes only legacy automatic backup groups in order', () async {
    final calls = <String>[];

    await cleanupLegacyBackupTasks(
      cancelAll: (group) async => calls.add('cancel:$group'),
      reset: (group) async => calls.add('reset:$group'),
      deleteRecords: (group) async => calls.add('delete:$group'),
    );

    expect(calls, [
      'cancel:backup_group',
      'reset:backup_group',
      'delete:backup_group',
      'cancel:backup_live_photo_group',
      'reset:backup_live_photo_group',
      'delete:backup_live_photo_group',
    ]);
    expect(calls.where((call) => call.contains('manual_upload_group')), isEmpty);
  });
}
