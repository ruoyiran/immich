import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/presentation/actions/action.widget.dart';
import 'package:immich_mobile/presentation/actions/upload.action.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/backup/asset_upload_progress.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/infrastructure/toast.provider.dart';
import 'package:immich_mobile/providers/timeline/multiselect.provider.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:immich_ui/immich_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../service.mocks.dart';
import '../../factories/local_asset_factory.dart';
import '../../factories/remote_asset_factory.dart';
import '../presentation_context.dart';

class MockTimelineService extends Mock implements TimelineService {}

void main() {
  late PresentationContext context;
  late MockForegroundUploadService uploadService;
  late TimelineService timelineService;

  setUp(() async {
    context = await PresentationContext.create();
    uploadService = context.service.upload;
    timelineService = MockTimelineService();
    when(() => timelineService.reload()).thenAnswer((_) async {});
    when(() => timelineService.markUploaded(any(), any())).thenReturn(true);
    when(() => context.service.backgroundSync.syncRemote(enqueue: true)).thenAnswer((_) async => true);
    when(() => context.repository.localAsset.repo.get(any())).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await context.dispose();
  });

  List<Override> uploadOverrides({TimelineService? timeline}) => [
    foregroundUploadServiceProvider.overrideWithValue(uploadService),
    backgroundSyncProvider.overrideWithValue(context.service.backgroundSync),
    localAssetRepository.overrideWithValue(context.repository.localAsset.repo),
    toastServiceProvider.overrideWithValue(context.service.toast),
    timelineServiceProvider.overrideWithValue(timeline ?? timelineService),
  ];

  Future<void> pumpUpload(WidgetTester tester, Set<BaseAsset> selection, {bool showProgress = false}) =>
      tester.pumpTestWidget(
        context,
        ActionIconButton(
          action: UploadAction(source: .timeline, showProgress: showProgress),
        ),
        overrides: [...context.selected(selection), ...uploadOverrides()],
      );

  Future<void> settleUpload(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const .new(seconds: 2));
    await tester.pumpAndSettle();
  }

  void answerUploadWith({Set<String> succeeded = const {}, Set<String> failed = const {}, Completer<void>? until}) {
    when(
      () => uploadService.uploadManual(
        any(),
        cancelToken: any(named: 'cancelToken'),
        callbacks: any(named: 'callbacks'),
      ),
    ).thenAnswer((invocation) async {
      if (until != null) {
        await until.future;
      }
      final callbacks = invocation.namedArguments[#callbacks] as UploadCallbacks;
      for (final id in succeeded) {
        callbacks.onSuccess?.call(id, id);
      }
      for (final id in failed) {
        callbacks.onError?.call(id, 'boom');
      }
    });
  }

  group('UploadAction', () {
    testWidgets('uploads the selected local assets', (tester) async {
      final asset = LocalAssetFactory.create();
      answerUploadWith(succeeded: {asset.id});

      await pumpUpload(tester, {asset});
      await tester.tap(find.byType(ImmichIconButton));
      await settleUpload(tester);

      final uploaded =
          verify(
                () => uploadService.uploadManual(
                  captureAny(),
                  cancelToken: any(named: 'cancelToken'),
                  callbacks: any(named: 'callbacks'),
                ),
              ).captured.single
              as List<LocalAsset>;
      expect(uploaded.map((a) => a.id), [asset.id]);
    });

    testWidgets('ignores assets that are already backed up', (tester) async {
      final notBackedUp = LocalAssetFactory.create();
      answerUploadWith(succeeded: {notBackedUp.id});

      await pumpUpload(tester, {notBackedUp, LocalAssetFactory.create(remoteId: 'already-there')});
      await tester.tap(find.byType(ImmichIconButton));
      await settleUpload(tester);

      final uploaded =
          verify(
                () => uploadService.uploadManual(
                  captureAny(),
                  cancelToken: any(named: 'cancelToken'),
                  callbacks: any(named: 'callbacks'),
                ),
              ).captured.single
              as List<LocalAsset>;
      expect(uploaded.map((a) => a.id), [notBackedUp.id]);
    });

    testWidgets('reports an error when an asset fails to upload', (tester) async {
      final asset = LocalAssetFactory.create();
      answerUploadWith(failed: {asset.id});

      await pumpUpload(tester, {asset});
      await tester.tap(find.byType(ImmichIconButton));
      await settleUpload(tester);

      final message = verify(() => context.service.toast.error(captureAny())).captured.single as String;
      expect(message, StaticTranslations.instance.scaffold_body_error_occurred);
    });

    testWidgets('treats a cancelled upload as deliberate, not a failure', (tester) async {
      final asset = LocalAssetFactory.create();
      when(
        () => uploadService.uploadManual(
          any(),
          cancelToken: any(named: 'cancelToken'),
          callbacks: any(named: 'callbacks'),
        ),
      ).thenAnswer((invocation) async {
        (invocation.namedArguments[#cancelToken] as Completer<void>).complete();
      });

      await pumpUpload(tester, {asset});
      await tester.tap(find.byType(ImmichIconButton));
      await settleUpload(tester);

      verifyNever(() => context.service.toast.error(any()));
    });

    testWidgets('shows the progress dialog while uploading and closes it after', (tester) async {
      final asset = LocalAssetFactory.create();
      final uploading = Completer<void>();
      answerUploadWith(succeeded: {asset.id}, until: uploading);

      await pumpUpload(tester, {asset}, showProgress: true);
      await tester.tap(find.byType(ImmichIconButton));
      await tester.pump();

      expect(find.text(StaticTranslations.instance.uploading), findsOneWidget);

      uploading.complete();
      await settleUpload(tester);

      expect(find.text(StaticTranslations.instance.uploading), findsNothing);
    });

    testWidgets('shows no dialog when not asked to', (tester) async {
      final asset = LocalAssetFactory.create();
      answerUploadWith(succeeded: {asset.id});

      await pumpUpload(tester, {asset});
      await tester.tap(find.byType(ImmichIconButton));
      await tester.pump();

      expect(find.text(StaticTranslations.instance.uploading), findsNothing);
      await settleUpload(tester);
    });

    testWidgets('is hidden for a remote asset, which has nothing to upload', (tester) async {
      await pumpUpload(tester, {RemoteAssetFactory.create()});

      expect(find.byType(ImmichIconButton), findsNothing);
    });

    testWidgets('is hidden when every local asset is already backed up', (tester) async {
      await pumpUpload(tester, {LocalAssetFactory.create(remoteId: 'already-there')});

      expect(find.byType(ImmichIconButton), findsNothing);
    });
  });

  group('uploadAssets', () {
    testWidgets('clears the tracked progress once the upload settles', (tester) async {
      final asset = LocalAssetFactory.create();
      answerUploadWith(succeeded: {asset.id});

      late WidgetRef capturedRef;
      await tester.pumpTestWidget(
        context,
        Consumer(
          builder: (_, ref, _) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
        overrides: uploadOverrides(),
      );

      await uploadAssets(tester.element(find.byType(SizedBox)), capturedRef, [asset]);
      await settleUpload(tester);

      expect(capturedRef.read(assetUploadProgressProvider), isEmpty);
      expect(capturedRef.read(manualUploadCancelTokenProvider), isNull);
    });

    testWidgets('links successful uploads locally and keeps only failed assets selected', (tester) async {
      final succeeded = LocalAssetFactory.create(id: 'succeeded');
      final failed = LocalAssetFactory.create(id: 'failed');
      final hashed = succeeded.copyWith(checksum: 'dGVzdC1jaGVja3N1bQ==');
      answerUploadWith(succeeded: {succeeded.id}, failed: {failed.id});
      when(() => context.repository.localAsset.repo.get(succeeded.id)).thenAnswer((_) async => hashed);
      when(
        () => context.repository.remoteAsset.repo.upsertUploadedAsset(
          remoteId: succeeded.id,
          ownerId: context.currentUser.id,
          source: hashed,
        ),
      ).thenAnswer((_) async {});

      late WidgetRef capturedRef;
      await tester.pumpTestWidget(
        context,
        Consumer(
          builder: (_, ref, _) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
        overrides: [
          ...context.selected({succeeded, failed}),
          ...uploadOverrides(),
        ],
      );

      await uploadAssets(tester.element(find.byType(SizedBox)), capturedRef, [succeeded, failed]);

      expect(capturedRef.read(multiSelectProvider).selectedAssets, {failed});
      verify(
        () => context.repository.remoteAsset.repo.upsertUploadedAsset(
          remoteId: succeeded.id,
          ownerId: context.currentUser.id,
          source: hashed,
        ),
      ).called(1);
      verifyNever(() => context.service.backgroundSync.syncRemote(enqueue: true));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('refreshes the current timeline after linking an uploaded asset', (tester) async {
      final asset = LocalAssetFactory.create(id: 'local');
      final hashed = asset.copyWith(checksum: 'dGVzdC1jaGVja3N1bQ==');
      var assetLoadCount = 0;
      final initialLoad = Completer<void>();
      final bucketController = StreamController<List<Bucket>>.broadcast(sync: true);
      final timeline = TimelineService((
        assetSource: (_, __) async {
          assetLoadCount++;
          if (assetLoadCount == 1) {
            initialLoad.complete();
            return [hashed];
          }
          return [hashed.copyWith(remoteId: asset.id)];
        },
        bucketSource: () => bucketController.stream,
        origin: TimelineOrigin.localAlbum,
      ));
      addTearDown(bucketController.close);
      addTearDown(timeline.dispose);
      answerUploadWith(succeeded: {asset.id});
      when(() => context.repository.localAsset.repo.get(asset.id)).thenAnswer((_) async => hashed);
      when(
        () => context.repository.remoteAsset.repo.upsertUploadedAsset(
          remoteId: asset.id,
          ownerId: context.currentUser.id,
          source: hashed,
        ),
      ).thenAnswer((_) async {});

      late WidgetRef capturedRef;
      await tester.pumpTestWidget(
        context,
        Consumer(
          builder: (_, ref, _) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
        overrides: [
          ...context.selected({asset}),
          ...uploadOverrides(timeline: timeline),
        ],
      );
      bucketController.add(const [Bucket(assetCount: 1)]);
      await initialLoad.future;
      await tester.pump();
      expect(timeline.getAsset(0).hasRemote, isFalse);

      await uploadAssets(tester.element(find.byType(SizedBox)), capturedRef, [asset]);

      expect(timeline.getAsset(0).remoteId, asset.id);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('updates each successful asset before the rest of the batch finishes', (tester) async {
      final first = LocalAssetFactory.create(id: 'first').copyWith(checksum: 'Zmlyc3Q=');
      final second = LocalAssetFactory.create(id: 'second').copyWith(checksum: 'c2Vjb25k');
      final firstSucceeded = Completer<void>();
      final finishBatch = Completer<void>();
      when(
        () => uploadService.uploadManual(
          any(),
          cancelToken: any(named: 'cancelToken'),
          callbacks: any(named: 'callbacks'),
        ),
      ).thenAnswer((invocation) async {
        final callbacks = invocation.namedArguments[#callbacks] as UploadCallbacks;
        callbacks.onSuccess?.call(first.id, 'remote-first');
        firstSucceeded.complete();
        await finishBatch.future;
        callbacks.onSuccess?.call(second.id, 'remote-second');
      });
      when(() => context.repository.localAsset.repo.get(first.id)).thenAnswer((_) async => first);
      when(() => context.repository.localAsset.repo.get(second.id)).thenAnswer((_) async => second);
      when(
        () => context.repository.remoteAsset.repo.upsertUploadedAsset(
          remoteId: any(named: 'remoteId'),
          ownerId: context.currentUser.id,
          source: any(named: 'source'),
        ),
      ).thenAnswer((_) async {});

      late WidgetRef capturedRef;
      await tester.pumpTestWidget(
        context,
        Consumer(
          builder: (_, ref, _) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
        overrides: [
          ...context.selected({first, second}),
          ...uploadOverrides(),
        ],
      );

      final upload = uploadAssets(tester.element(find.byType(SizedBox)), capturedRef, [first, second]);
      await firstSucceeded.future.timeout(const Duration(seconds: 2));
      await tester.pump();

      try {
        verify(() => timelineService.markUploaded(first.id, 'remote-first')).called(1);
        verifyNever(() => timelineService.markUploaded(second.id, any()));
        expect(capturedRef.read(assetUploadProgressProvider), isNot(contains(first.id)));
        expect(capturedRef.read(assetUploadProgressProvider), contains(second.id));
      } finally {
        finishBatch.complete();
        await upload;
      }
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('does not wait for local persistence after the server confirms the upload', (tester) async {
      final asset = LocalAssetFactory.create(id: 'uploaded').copyWith(checksum: 'dXBsb2FkZWQ=');
      final persistenceStarted = Completer<void>();
      final finishPersistence = Completer<void>();
      answerUploadWith(succeeded: {asset.id});
      when(() => context.repository.localAsset.repo.get(asset.id)).thenAnswer((_) async => asset);
      when(
        () => context.repository.remoteAsset.repo.upsertUploadedAsset(
          remoteId: asset.id,
          ownerId: context.currentUser.id,
          source: asset,
        ),
      ).thenAnswer((_) async {
        persistenceStarted.complete();
        await finishPersistence.future;
      });

      late WidgetRef capturedRef;
      await tester.pumpTestWidget(
        context,
        Consumer(
          builder: (_, ref, _) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
        overrides: [
          ...context.selected({asset}),
          ...uploadOverrides(),
        ],
      );

      final upload = uploadAssets(tester.element(find.byType(SizedBox)), capturedRef, [asset]);
      await persistenceStarted.future.timeout(const Duration(seconds: 2));
      try {
        await upload.timeout(const Duration(milliseconds: 100));
        expect(capturedRef.read(assetUploadProgressProvider), isEmpty);
        verify(() => timelineService.markUploaded(asset.id, asset.id)).called(1);
      } finally {
        finishPersistence.complete();
        await tester.pump();
      }
    });
  });
}
