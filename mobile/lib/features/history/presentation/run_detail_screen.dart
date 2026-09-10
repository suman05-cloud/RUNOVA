import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:runova/core/config/app_config.dart';
import 'package:runova/features/history/data/run_history_repository.dart';

class RunDetailScreen extends ConsumerStatefulWidget {
  const RunDetailScreen({super.key, required this.runId, this.summary = false});
  final String runId;
  final bool summary;
  @override
  ConsumerState<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends ConsumerState<RunDetailScreen> {
  List<dynamic>? _route;
  bool _loadingRoute = false;
  String? _routeError;
  Future<void> _loadRoute() async {
    setState(() {
      _loadingRoute = true;
      _routeError = null;
    });
    try {
      final data = await ref
          .read(historyRepositoryProvider)
          .detail(widget.runId, route: true);
      if (mounted) {
        setState(() {
          _route = data['route_points'] as List<dynamic>;
          if (data['route_truncated'] == true) {
            _routeError = 'Showing the first 5,000 samples.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _routeError = 'Could not load your route. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(runDetailProvider(widget.runId));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.summary ? 'Run complete' : 'Run details'),
        leading: IconButton(
          onPressed: () => context.go(widget.summary ? '/' : '/history'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(runDetailProvider(widget.runId)),
            child: const Text('Could not load this run. Retry'),
          ),
        ),
        data: (run) {
          final distance = (run['distance_meters'] as num).toDouble();
          final moving = (run['moving_seconds'] as num).toInt();
          final changes = (run['territory_changes'] as List<dynamic>?) ?? [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${(distance / 1000).toStringAsFixed(2)} km',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              Text(
                '${run['activity_type'] ?? 'Pending evaluation'} · ${run['validation_status']}',
              ),
              const SizedBox(height: 16),
              Text('Duration: ${durationLabel(run['elapsed_seconds'] as int)}'),
              Text(
                'Moving: ${durationLabel(moving)} · Pace: ${paceLabel(distance, moving)}',
              ),
              Text(
                'Trust: ${run['trust_score'] ?? 'Pending'} · +${run['xp_earned']} XP',
              ),
              Text('Current level: ${run['level'] ?? 1}'),
              const SizedBox(height: 20),
              Text(
                '${changes.length} territory changes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ...changes.map((raw) {
                final change = raw as Map<String, dynamic>;
                return ListTile(
                  title: Text(change['action'] as String),
                  subtitle: Text(change['cell_id'] as String),
                  trailing: Text(
                    '${change['power_before']} → ${change['power_after']}',
                  ),
                );
              }),
              const SizedBox(height: 16),
              if (_route == null)
                OutlinedButton.icon(
                  onPressed: _loadingRoute ? null : _loadRoute,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(
                    _loadingRoute ? 'Loading…' : 'Show my private route',
                  ),
                ),
              if (_route != null && _route!.length >= 2)
                SizedBox(height: 300, child: _RouteMap(points: _route!)),
              if (_route != null && _route!.length < 2)
                const Text('Not enough GPS points to draw a route.'),
              if (_routeError != null) Text(_routeError!),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }
}

String durationLabel(int seconds) =>
    '${seconds ~/ 3600}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
String paceLabel(double meters, int seconds) {
  if (meters <= 0 || seconds <= 0) return '—';
  final paceSeconds = (seconds / (meters / 1000)).round();
  return '${paceSeconds ~/ 60}:${(paceSeconds % 60).toString().padLeft(2, '0')} /km';
}

class _RouteMap extends StatefulWidget {
  const _RouteMap({required this.points});
  final List<dynamic> points;
  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  MapLibreMapController? _controller;
  @override
  Widget build(BuildContext context) {
    final coordinates = widget.points
        .map(
          (raw) => [
            (raw['longitude'] as num).toDouble(),
            (raw['latitude'] as num).toDouble(),
          ],
        )
        .toList();
    return MapLibreMap(
      styleString: AppConfig.mapStyleUrl,
      initialCameraPosition: CameraPosition(
        target: LatLng(coordinates.first[1], coordinates.first[0]),
        zoom: 15,
      ),
      onMapCreated: (controller) => _controller = controller,
      onStyleLoadedCallback: () async {
        final controller = _controller!;
        await controller.addSource(
          'private-route',
          GeojsonSourceProperties(
            data: {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {'type': 'LineString', 'coordinates': coordinates},
            },
          ),
        );
        await controller.addLineLayer(
          'private-route',
          'route-line',
          const LineLayerProperties(lineColor: '#35E37A', lineWidth: 4),
        );
        final lats = coordinates.map((p) => p[1]).toList()..sort();
        final lngs = coordinates.map((p) => p[0]).toList()..sort();
        if (lats.first != lats.last || lngs.first != lngs.last) {
          await controller.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(lats.first, lngs.first),
                northeast: LatLng(lats.last, lngs.last),
              ),
              left: 24,
              right: 24,
              top: 24,
              bottom: 24,
            ),
          );
        }
      },
    );
  }
}
