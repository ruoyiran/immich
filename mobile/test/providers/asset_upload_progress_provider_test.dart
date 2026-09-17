import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/providers/backup/asset_upload_progress.provider.dart';

void main() {
  test('cancelling the latest batch preserves earlier work and its cancellation entry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cancellations = container.read(manualUploadCancelTokenProvider.notifier);
    final first = Completer<void>();
    final second = Completer<void>();
    cancellations.register(first);
    cancellations.register(second);
    cancellations.cancelCurrent();
    expect(second.isCompleted, isTrue);
    expect(first.isCompleted, isFalse);
    expect(container.read(manualUploadCancelTokenProvider), same(first));
    cancellations.unregister(second);
    expect(container.read(manualUploadCancelTokenProvider), same(first));
    cancellations.cancelCurrent();
    expect(first.isCompleted, isTrue);
    expect(container.read(manualUploadCancelTokenProvider), isNull);
  });

  testWidgets('delayed batch cleanup preserves a newer processing attempt for the same asset', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final progress = container.read(assetUploadProgressProvider.notifier);
    progress.setProcessing('asset');
    progress.clearAssets(['asset'], delay: const Duration(seconds: 2));
    progress.remove('asset');
    progress.setProcessing('asset');
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(assetUploadProgressProvider)['asset']?.phase, AssetUploadPhase.processing);
  });

  testWidgets('delayed batch cleanup preserves a newer failed attempt and other batches', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final progress = container.read(assetUploadProgressProvider.notifier);
    progress.setError('asset');
    progress.clearAssets(['asset'], delay: const Duration(seconds: 2));
    progress.setProgress('other', 0.5);
    progress.setError('asset');
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(assetUploadProgressProvider)['asset']?.phase, AssetUploadPhase.error);
    expect(container.read(assetUploadProgressProvider)['other']?.value, 0.5);
  });
}
