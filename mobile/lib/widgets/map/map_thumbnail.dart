import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:immich_mobile/extensions/asyncvalue_extensions.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/maplibrecontroller_extensions.dart';
import 'package:immich_mobile/widgets/map/asset_marker_icon.dart';
import 'package:immich_mobile/widgets/map/map_backend.dart';
import 'package:immich_mobile/widgets/map/map_theme_override.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// A non-interactive thumbnail of a map in the given coordinates with optional markers.
///
/// User can provide either a [assetMarkerRemoteId] to display the asset's thumbnail or set
/// [showMarkerPin] to true which would display a marker pin instead. If both are provided,
/// [assetMarkerRemoteId] will take precedence.
class MapThumbnail extends StatefulWidget {
  final Function(Point<double>, LatLng)? onTap;
  final LatLng centre;
  final String? assetMarkerRemoteId;
  final String? assetThumbhash;
  final ImageProvider<Object>? assetMarkerImageProvider;
  final ImageProvider<Object>? mapImageProvider;
  final bool showMarkerPin;
  final double zoom;
  final double height;
  final double width;
  final ThemeMode? themeMode;
  final bool showAttribution;
  final MapThumbnailControllerCallback? onCreated;
  final VoidCallback? onStyleLoaded;
  final MapBackendConfig backendConfig;

  const MapThumbnail({
    super.key,
    required this.centre,
    this.height = 100,
    this.width = 100,
    this.onTap,
    this.zoom = 8,
    this.assetMarkerRemoteId,
    this.assetThumbhash,
    this.assetMarkerImageProvider,
    this.mapImageProvider,
    this.showMarkerPin = false,
    this.themeMode,
    this.showAttribution = true,
    this.onCreated,
    this.onStyleLoaded,
    this.backendConfig = MapBackendConfig.environment,
  });

  @override
  State<MapThumbnail> createState() => _MapThumbnailState();
}

class _MapThumbnailState extends State<MapThumbnail> {
  MapLibreMapController? _mapLibreController;
  late LatLng _centre;
  bool _mapReady = false;
  bool _amapFailed = false;
  bool _staticControllerNotified = false;

  MapBackend get _backend =>
      _amapFailed ? MapBackend.mapLibre : widget.backendConfig.resolve(platform: defaultTargetPlatform, isWeb: kIsWeb);

  @override
  void initState() {
    super.initState();
    _centre = widget.centre;
  }

  @override
  void didUpdateWidget(MapThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.centre != oldWidget.centre) {
      _centre = widget.centre;
      _mapReady = false;
    }
    if (widget.backendConfig != oldWidget.backendConfig) {
      _amapFailed = false;
      _mapReady = false;
      _staticControllerNotified = false;
    }
  }

  void _markReady() {
    if (!mounted || _mapReady) {
      return;
    }
    setState(() => _mapReady = true);
    widget.onStyleLoaded?.call();
  }

  void _onMapLibreCreated(MapLibreMapController controller) {
    _mapLibreController = controller;
    _mapReady = false;
    widget.onCreated?.call(_MapLibreThumbnailController(controller));
  }

  Future<void> _onMapLibreStyleLoaded() async {
    try {
      if (widget.showMarkerPin && _mapLibreController != null) {
        await _mapLibreController?.addMarkerAtLatLng(_centre);
      }
    } finally {
      // MapLibre currently provides no way to check whether its controller was disposed.
    }
    _markReady();
  }

  @override
  Widget build(BuildContext context) {
    if (_backend == MapBackend.amap) {
      return _buildFrame(context, _buildAmapStaticMap());
    }

    return MapThemeOverride(
      themeMode: widget.themeMode,
      mapBuilder: (style) => _buildFrame(
        context,
        style.widgetWhen(
          onData: (style) => MapLibreMap(
            initialCameraPosition: CameraPosition(target: _centre, zoom: widget.zoom),
            styleString: style,
            onMapCreated: _onMapLibreCreated,
            onStyleLoadedCallback: _onMapLibreStyleLoaded,
            onMapClick: widget.onTap,
            doubleClickZoomEnabled: false,
            dragEnabled: false,
            zoomGesturesEnabled: false,
            tiltGesturesEnabled: false,
            scrollGesturesEnabled: false,
            rotateGesturesEnabled: false,
            myLocationEnabled: false,
            attributionButtonMargins: widget.showAttribution == false ? const Point(-100, 0) : null,
          ),
        ),
      ),
    );
  }

  Widget _buildAmapStaticMap() {
    final mapUri = buildAmapStaticMapUri(
      key: widget.backendConfig.amapWebKey,
      latitude: _centre.latitude,
      longitude: _centre.longitude,
      zoom: widget.zoom,
      width: widget.width,
      height: widget.height,
      showMarker: widget.showMarkerPin && widget.assetMarkerRemoteId == null,
    );
    final imageProvider = widget.mapImageProvider ?? NetworkImage(mapUri.toString());
    if (!_staticControllerNotified) {
      _staticControllerNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onCreated?.call(_StaticMapThumbnailController(_moveStaticMap));
        }
      });
    }

    return Image(
      image: imageProvider,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return ColoredBox(color: context.colorScheme.surfaceContainerHighest);
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _markReady());
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        _markReady();
        return ColoredBox(color: context.colorScheme.surfaceContainerHighest);
      },
    );
  }

  Future<void> _moveStaticMap(double latitude, double longitude) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _centre = LatLng(latitude, longitude);
      _mapReady = false;
    });
  }

  Widget _buildFrame(BuildContext context, Widget map) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => widget.onTap?.call(Point(details.localPosition.dx, details.localPosition.dy), _centre),
      child: AnimatedContainer(
        duration: Durations.medium2,
        curve: Curves.easeOut,
        foregroundDecoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withAlpha(_mapReady ? 0 : 220),
          borderRadius: const BorderRadius.all(Radius.circular(15)),
        ),
        height: widget.height,
        width: widget.width,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          child: Stack(
            alignment: AlignmentGeometry.topCenter,
            children: [
              map,
              if (widget.assetMarkerRemoteId != null)
                Container(
                  width: widget.width,
                  height: widget.height / 2,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox.square(
                    dimension: widget.height / 2.5,
                    child: AssetMarkerIcon(
                      id: widget.assetMarkerRemoteId!,
                      thumbhash: widget.assetThumbhash,
                      imageProvider: widget.assetMarkerImageProvider,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLibreThumbnailController implements MapThumbnailController {
  final MapLibreMapController _controller;

  const _MapLibreThumbnailController(this._controller);

  @override
  Future<void> moveTo(double latitude, double longitude) {
    return _controller.moveCamera(CameraUpdate.newLatLng(LatLng(latitude, longitude)));
  }
}

class _StaticMapThumbnailController implements MapThumbnailController {
  final Future<void> Function(double latitude, double longitude) _moveTo;

  const _StaticMapThumbnailController(this._moveTo);

  @override
  Future<void> moveTo(double latitude, double longitude) => _moveTo(latitude, longitude);
}
