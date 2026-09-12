import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:runova/core/config/app_config.dart';
import 'package:runova/features/territories/data/territory_geojson.dart';
import 'package:runova/core/network/api_client.dart';
import 'package:runova/core/theme/runova_theme.dart';

class TerritoryMapScreen extends ConsumerStatefulWidget {
  const TerritoryMapScreen({super.key});

  @override
  ConsumerState<TerritoryMapScreen> createState() => _TerritoryMapScreenState();
}

class _TerritoryMapScreenState extends ConsumerState<TerritoryMapScreen> {
  static const _pilotLocation = LatLng(12.8231, 80.0442);
  static const _sourceId = 'runova-territories';
  static const _layerId = 'runova-territory-fill';
  MapLibreMapController? _controller;
  bool _sourceCreated = false;
  bool _loading = false;
  bool _refreshPending = false;
  bool _styleReady = false;
  bool _locating = false;
  bool _locationEnabled = false;
  int _mapGeneration = 0;
  Timer? _loadTimer;
  Timer? _refreshTimer;
  CancelToken? _request;
  String? _mapError;
  String? _message;

  @override
  void initState() {
    super.initState();
    _watchMapLoad();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_refreshTerritories());
    });
  }

  void _watchMapLoad() {
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && !_styleReady) {
        setState(
          () =>
              _mapError = 'Map could not load. Check your internet connection.',
        );
      }
    });
  }

  void _retryMap() {
    _request?.cancel();
    setState(() {
      _mapGeneration++;
      _controller = null;
      _styleReady = false;
      _sourceCreated = false;
      _loading = false;
      _refreshPending = false;
      _mapError = null;
      _message = null;
    });
    _watchMapLoad();
  }

  void _onStyleLoaded() {
    _loadTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _styleReady = true;
      _sourceCreated = false;
      _mapError = null;
    });
    unawaited(_refreshTerritories());
  }

  Future<void> _locate() async {
    if (_locating || !_styleReady) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage(
          'Turn on your phone’s location services.',
          settings: true,
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Allow location access in app settings.',
          appSettings: true,
        );
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _showLocationMessage(
          'Location permission is needed to show your position.',
        );
        return;
      }
      setState(() => _locationEnabled = true);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted || !_styleReady) return;
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ),
      );
    } catch (_) {
      _showLocationMessage('Could not find your location. Try again outdoors.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationMessage(
    String message, {
    bool settings = false,
    bool appSettings = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: settings || appSettings
            ? SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  if (appSettings) {
                    unawaited(Geolocator.openAppSettings());
                  } else {
                    unawaited(Geolocator.openLocationSettings());
                  }
                },
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _loadTimer?.cancel();
    _request?.cancel();
    super.dispose();
  }

  Future<void> _refreshTerritories() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    if (_loading) {
      _refreshPending = true;
      return;
    }
    final generation = _mapGeneration;
    _loading = true;
    final request = CancelToken();
    _request = request;
    try {
      final bounds = await controller.getVisibleRegion();
      final response = await ref
          .read(apiClientProvider)
          .get<List<dynamic>>(
            '/v1/territories',
            cancelToken: request,
            queryParameters: {
              'min_lat': bounds.southwest.latitude,
              'max_lat': bounds.northeast.latitude,
              'min_lng': bounds.southwest.longitude,
              'max_lng': bounds.northeast.longitude,
            },
          );
      if (!mounted || generation != _mapGeneration) return;
      final items = response.data ?? [];
      final geoJson = territoryGeoJson(items);
      if (!_sourceCreated) {
        await controller.addSource(
          _sourceId,
          GeojsonSourceProperties(data: geoJson),
        );
        await controller.addFillLayer(
          _sourceId,
          _layerId,
          const FillLayerProperties(
            fillColor: ['get', 'color'],
            fillOpacity: 0.20,
            fillOutlineColor: '#FFFFFF',
          ),
        );
        _sourceCreated = true;
      } else {
        await controller.setGeoJsonSource(_sourceId, geoJson);
      }
      if (mounted && generation == _mapGeneration) {
        setState(() => _message = '${items.length} territories visible');
      }
    } catch (error) {
      if (mounted &&
          generation == _mapGeneration &&
          !(error is DioException && CancelToken.isCancel(error))) {
        setState(
          () => _message = 'Territories unavailable. Tap refresh to retry.',
        );
      }
    } finally {
      if (generation == _mapGeneration) {
        _loading = false;
        if (mounted && _refreshPending) {
          _refreshPending = false;
          unawaited(_refreshTerritories());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          key: ValueKey(_mapGeneration),
          styleString: AppConfig.mapStyleUrl,
          initialCameraPosition: const CameraPosition(
            target: _pilotLocation,
            zoom: 14,
          ),
          compassEnabled: true,
          myLocationEnabled: _locationEnabled,
          attributionButtonMargins: const Point(12, 12),
          onMapCreated: (controller) => _controller = controller,
          onStyleLoadedCallback: _onStyleLoaded,
          onCameraIdle: () => unawaited(_refreshTerritories()),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface
                        .withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.hexagon_rounded,
                          color: RunovaColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _message ?? 'Territory map',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh territories',
                          onPressed: _styleReady ? _refreshTerritories : null,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Run your own route',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'Walk or run a near-closed loop to claim its enclosed area. '
                          'No assigned tasks. Finish close to your start.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const Text(
                          'Green: yours. Red: someone else’s — no capture points. '
                          'Yellow: claim any portion for 2× area points. '
                          '48 hours without a verified walk/run releases your land.',
                          style: TextStyle(fontSize: 11),
                        ),
                        TextButton(
                          onPressed: () => context.go('/run'),
                          child: const Text('Walk / run'),
                        ),
                        const Text(
                          'Use safe public paths only.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const IgnorePointer(child: _MapLegend()),
                    FloatingActionButton.small(
                      heroTag: 'map-location',
                      tooltip: 'Show my location',
                      onPressed: _styleReady && !_locating ? _locate : null,
                      child: _locating
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ],
                ),
                const SizedBox(height: 42),
              ],
            ),
          ),
        ),
        if (!_styleReady)
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_mapError == null) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text('Loading map…'),
                    ] else ...[
                      const Icon(Icons.cloud_off),
                      const SizedBox(height: 12),
                      Text(_mapError!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _retryMap,
                        child: const Text('Retry map'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendDot(color: RunovaColors.primary, label: 'Yours'),
            SizedBox(width: 10),
            _LegendDot(color: Color(0xFFFFE066), label: 'Open'),
            SizedBox(width: 14),
            _LegendDot(color: RunovaColors.enemy, label: 'Others'),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 9),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
