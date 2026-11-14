// Drivers map — the 5th shell tab (v1.0.5).
//
// Shows the REGISTERED drivers' last-known locations on an
// OpenStreetMap map (flutter_map, no API key). Tapping a driver
// marker — or the driver in the list below the map — opens that
// driver's details (the existing DriverDetailScreen).
//
// HONEST DATA NOTE: DeliveryFlow writes NO driver locations to
// Firestore today (users/{uid} carries no lastLat / lastLng /
// lastLocationAtMillis), so in the field every driver reads
// "مفيش موقع لسه" until a future driver-app update starts writing
// locations. A location is NEVER invented, guessed, or defaulted
// — the map centres on Cairo only as an empty-map default, and the
// screen says plainly that no locations exist yet.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/diagnostics.dart';
import '../../core/strings.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../widgets/dm_map.dart';
import '../../widgets/entrance.dart';
import '../../widgets/glass.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../team/team_screen.dart';

String _locationTimeLabel(int? millis) {
  if (millis == null || millis <= 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class DriversMapScreen extends StatefulWidget {
  const DriversMapScreen({
    super.key,
    required this.backend,
    required this.managerUid,
    required this.entryGeneration,
  });

  final ManagerBackend backend;
  final String managerUid;
  final int entryGeneration;

  @override
  State<DriversMapScreen> createState() => _DriversMapScreenState();
}

class _DriversMapScreenState extends State<DriversMapScreen> {
  final _mapController = MapController();
  List<ManagerAccount> _drivers = const [];
  var _loaded = false;
  var _mapReady = false;
  String? _liveError;
  String? _fittedKey;
  StreamSubscription<List<ManagerAccount>>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _subscribe() {
    _sub?.cancel();
    _liveError = null;
    _sub = widget.backend.watchUsers().listen(
      (users) {
        if (!mounted) return;
        final drivers = visibleTeamUsers(users)
            .where((u) => !u.isManager)
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        setState(() {
          _drivers = drivers;
          _loaded = true;
        });
      },
      onError: (Object e) {
        diagnosticsLog.add('live', 'drivers map stream error: $e');
        if (!mounted) return;
        setState(
          () => _liveError = DmStrings.of(context).liveStoppedGeneric,
        );
      },
    );
  }

  void _openDriver(ManagerAccount driver) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverDetailScreen(
          backend: widget.backend,
          managerUid: widget.managerUid,
          account: driver,
        ),
      ),
    );
  }

  /// Fits the camera to the located drivers once per distinct set
  /// of locations (a single driver centres at street zoom). Never
  /// runs before the map is ready, and never re-fits on every
  /// rebuild — a manager who panned away is not yanked back.
  void _fitIfNeeded(List<ManagerAccount> located) {
    if (!_mapReady || located.isEmpty) return;
    final key = located
        .map((d) => '${d.uid}@${d.lastLat},${d.lastLng}')
        .join('|');
    if (key == _fittedKey) return;
    _fittedKey = key;
    final points = [
      for (final d in located) LatLng(d.lastLat!, d.lastLng!),
    ];
    if (points.length == 1) {
      _mapController.move(points.first, 15);
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = DmStrings.of(context);
    final located = [for (final d in _drivers) if (d.hasLocation) d];
    final markers = [
      for (final d in located)
        Marker(
          point: LatLng(d.lastLat!, d.lastLng!),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _openDriver(d),
            child: DmDriverPin(label: d.displayName),
          ),
        ),
    ];
    if (located.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _fitIfNeeded(located),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: GlassTokens.screenPadding.copyWith(bottom: 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  s.driversMapTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  setState(() => _liveError = null);
                  _subscribe();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: GlassTokens.screenPadding.copyWith(top: 0, bottom: 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 340,
              child: DmMapView(
                center: located.isNotEmpty
                    ? LatLng(located.first.lastLat!, located.first.lastLng!)
                    : dmMapCairoCenter,
                zoom: located.isNotEmpty ? 13 : 11,
                markers: markers,
                controller: _mapController,
                onMapReady: () {
                  _mapReady = true;
                  _fitIfNeeded(located);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            padding: GlassTokens.screenPadding.copyWith(top: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_liveError != null)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_liveError!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            setState(() => _liveError = null);
                            _subscribe();
                          },
                          child: Text(s.reconnect),
                        ),
                      ],
                    ),
                  ),
                if (!_loaded)
                  const ListSkeleton()
                else if (_drivers.isEmpty)
                  GlassCard(child: Text(s.noDriversRegistered))
                else ...[
                  if (located.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        child: Text(
                          s.noDriverLocationsNote,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  for (var i = 0; i < _drivers.length; i++)
                    SlideUpItem(
                      index: i,
                      generation: widget.entryGeneration,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DriverLocationRow(
                          driver: _drivers[i],
                          onTap: () => _openDriver(_drivers[i]),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One driver row under the map: name + location state. A driver
/// with no location shows "مفيش موقع لسه" — never a guessed pin.
class _DriverLocationRow extends StatelessWidget {
  const _DriverLocationRow({required this.driver, required this.onTap});

  final ManagerAccount driver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = DmStrings.of(context);
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                GlassTokens.primaryBlue.withValues(alpha: 0.12),
            child: Text(
              driver.displayName.isEmpty ? '؟' : driver.displayName[0],
              style: const TextStyle(
                color: GlassTokens.primaryBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  driver.hasLocation
                      ? s.driverLocationLine(
                          driver.lastLat!.toStringAsFixed(5),
                          driver.lastLng!.toStringAsFixed(5),
                          _locationTimeLabel(driver.lastLocationAtMillis),
                        )
                      : s.noLocationYet,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            driver.hasLocation
                ? Icons.location_on_rounded
                : Icons.location_off_rounded,
            color: driver.hasLocation
                ? GlassTokens.primaryBlue
                : Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ),
          ),
        ],
      ),
    );
  }
}
