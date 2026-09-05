import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:runova/core/config/app_config.dart';
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
  String? _message;

  Future<void> _refreshTerritories() async {
    final controller = _controller;
    if (controller == null || _loading) return;
    _loading = true;
    try {
      final bounds = await controller.getVisibleRegion();
      final response = await ref.read(apiClientProvider).get<List<dynamic>>(
        '/v1/territories',
        queryParameters: {
          'min_lat': bounds.southwest.latitude,
          'max_lat': bounds.northeast.latitude,
          'min_lng': bounds.southwest.longitude,
          'max_lng': bounds.northeast.longitude,
        },
      );
      final items = response.data ?? [];
      final geoJson = {
        'type': 'FeatureCollection',
        'features': items
            .map(
              (raw) {
                final item = raw as Map<String, dynamic>;
                return {
                  'type': 'Feature',
                  'id': item['cell_id'],
                  'properties': {
                    'mine': item['is_current_user'],
                    'power': item['power'],
                    'owner': item['owner_username'],
                  },
                  'geometry': {
                    'type': 'Polygon',
                    'coordinates': [item['coordinates']],
                  },
                };
              },
            )
            .toList(),
      };
      if (!_sourceCreated) {
        await controller.addSource(_sourceId, GeojsonSourceProperties(data: geoJson));
        await controller.addFillLayer(
          _sourceId,
          _layerId,
          const FillLayerProperties(
            fillColor: [
              'case',
              ['get', 'mine'],
              '#35E37A',
              '#FF5964',
            ],
            fillOpacity: 0.48,
            fillOutlineColor: '#FFFFFF',
          ),
        );
        _sourceCreated = true;
      } else {
        await controller.setGeoJsonSource(_sourceId, geoJson);
      }
      if (mounted) setState(() => _message = '${items.length} territories visible');
    } on DioException {
      if (mounted) setState(() => _message = 'Sign in and start the Runova API');
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapLibreMap(
          styleString: AppConfig.mapStyleUrl,
          initialCameraPosition: const CameraPosition(target: _pilotLocation, zoom: 14),
          compassEnabled: true,
          myLocationEnabled: false,
          attributionButtonMargins: const Point(12, 96),
          onMapCreated: (controller) => _controller = controller,
          onStyleLoadedCallback: _refreshTerritories,
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
                    color: RunovaColors.background.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hexagon_rounded, color: RunovaColors.primary),
                        const SizedBox(width: 8),
                        Text(_message ?? 'Territory map',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                const _MapLegend(),
                const SizedBox(height: 82),
              ],
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
        color: RunovaColors.background.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendDot(color: RunovaColors.primary, label: 'Yours'),
            SizedBox(width: 14),
            _LegendDot(color: RunovaColors.enemy, label: 'Opponent'),
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
