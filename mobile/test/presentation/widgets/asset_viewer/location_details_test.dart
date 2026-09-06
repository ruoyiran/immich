import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/models/map/map_state.model.dart';
import 'package:immich_mobile/presentation/actions/action.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_details/location_details.widget.dart';
import 'package:immich_mobile/providers/locale_provider.dart';
import 'package:immich_mobile/providers/map/map_state.provider.dart';
import 'package:immich_mobile/providers/theme.provider.dart';
import 'package:immich_mobile/theme/theme_data.dart';
import 'package:immich_mobile/utils/asset_filter.dart';

import '../../../modules/map/map_mocks.dart';
import '../../../unit/factories/remote_asset_factory.dart';
import '../../../widget_tester_extensions.dart';

void main() {
  testWidgets('shows available place fields when city is missing', (tester) async {
    await pumpLocationDetails(
      tester,
      const ExifInfo(latitude: 31.2304, longitude: 121.4737, state: '上海市', country: '中国'),
    );

    expect(find.text('上海市, 中国'), findsOneWidget);
  });

  testWidgets('trims and deduplicates place fields', (tester) async {
    await pumpLocationDetails(
      tester,
      const ExifInfo(
        latitude: 31.2304,
        longitude: 121.4737,
        district: ' 浦东新区 ',
        city: '上海市',
        state: ' 上海市 ',
        country: '中国',
      ),
    );

    expect(find.text('浦东新区, 上海市, 中国'), findsOneWidget);
  });

  testWidgets('prefers the detailed reverse-geocoded display name', (tester) async {
    await pumpLocationDetails(
      tester,
      const ExifInfo(
        latitude: 31.2304,
        longitude: 121.4737,
        district: '浦东新区',
        city: '上海市',
        state: '上海市',
        country: '中国',
        placeDisplayName: '上海市浦东新区川沙新镇川沙路 100 号',
      ),
    );

    expect(find.text('上海市浦东新区川沙新镇川沙路 100 号'), findsOneWidget);
    expect(find.text('浦东新区, 上海市, 中国'), findsNothing);
  });
}

Future<void> pumpLocationDetails(WidgetTester tester, ExifInfo exifInfo) async {
  final asset = RemoteAssetFactory.create();
  final light = ColorScheme.fromSeed(seedColor: Colors.blue);
  final dark = ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark);

  await tester.pumpConsumerWidget(
    SingleChildScrollView(
      child: LocationDetails(asset: asset, exifInfo: exifInfo),
    ),
    overrides: [
      immichThemeProvider.overrideWith((_) => ImmichTheme(light: light, dark: dark)),
      localeProvider.overrideWithValue(const Locale('zh')),
      mapStateNotifierProvider.overrideWith(
        () => MockMapStateNotifier(
          const MapState(
            lightStyleFetched: AsyncData('{"version":8,"sources":{},"layers":[]}'),
            darkStyleFetched: AsyncData('{"version":8,"sources":{},"layers":[]}'),
          ),
        ),
      ),
      ownedAssetsActionProvider(ActionSource.viewer).overrideWithValue(const AssetFilter<RemoteAsset>({})),
    ],
  );
}
