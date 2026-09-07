import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/utils/debug_print.dart';
import 'package:immich_mobile/widgets/map/map_backend.dart';
import 'package:immich_mobile/widgets/map/map_launch_uri.dart';
import 'package:immich_mobile/widgets/map/map_thumbnail.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, canLaunchUrl, launchUrl;

class ExifMap extends StatelessWidget {
  final ExifInfo exifInfo;
  // TODO: Pass in a BaseAsset instead of the ID and thumbhash when removing old timeline
  // This is currently structured this way because of the old timeline implementation
  // reusing this component
  final String? markerId;
  final String? markerAssetThumbhash;
  final MapThumbnailControllerCallback? onMapCreated;

  const ExifMap({super.key, required this.exifInfo, this.markerAssetThumbhash, this.markerId, this.onMapCreated});

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = exifInfo.hasCoordinates;
    Future<Uri?> createCoordinatesUri() async {
      if (!hasCoordinates) {
        return null;
      }

      final double latitude = exifInfo.latitude!;
      final double longitude = exifInfo.longitude!;

      const zoomLevel = 16;
      final platform = Platform.isAndroid
          ? MapLaunchPlatform.android
          : Platform.isIOS
          ? MapLaunchPlatform.ios
          : MapLaunchPlatform.other;
      final uris = buildMapLaunchUris(
        latitude: latitude,
        longitude: longitude,
        zoom: zoomLevel,
        platform: platform,
        label: exifInfo.placeDisplayName,
      );

      final amapUri = uris.amapUri;
      if (amapUri != null && await canLaunchUrl(amapUri)) {
        return amapUri;
      }

      return uris.fallbackUri;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return MapThumbnail(
          centre: LatLng(exifInfo.latitude ?? 0, exifInfo.longitude ?? 0),
          height: 150,
          width: constraints.maxWidth,
          zoom: 12.0,
          assetMarkerRemoteId: markerId,
          assetThumbhash: markerAssetThumbhash,
          showMarkerPin: markerId == null,
          onTap: (tapPosition, latLong) async {
            final Uri? uri = await createCoordinatesUri();

            if (uri == null) {
              return;
            }

            dPrint(() => 'Opening Map Uri: $uri');
            unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
          },
          onCreated: onMapCreated,
        );
      },
    );
  }
}
