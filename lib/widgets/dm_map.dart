// Shared OpenStreetMap view (flutter_map + OSM tiles, no API key).
//
// Used by the drivers map tab and the order destination mini-map.
// Tile failures are logged to the diagnostics log with the exact
// failure reason (generic wording, no secrets) — a failed tile
// never crashes the screen, it just leaves that tile blank.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/diagnostics.dart';

/// Cairo fallback centre: shown when there is nothing to focus on
/// yet (no driver locations, no destination coordinates). It is a
/// map default, never a driver or customer location.
const dmMapCairoCenter = LatLng(30.0444, 31.2357);

/// OSM tile template — no API key, same as DeliveryFlow.
const _tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

class DmMapView extends StatelessWidget {
  const DmMapView({
    super.key,
    required this.center,
    this.zoom = 13,
    this.markers = const [],
    this.interactive = true,
    this.controller,
    this.onMapReady,
  });

  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final bool interactive;
  final MapController? controller;
  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: interactive
            ? const InteractionOptions()
            : const InteractionOptions(flags: InteractiveFlag.none),
        onMapReady: onMapReady,
      ),
      children: [
        TileLayer(
          urlTemplate: _tileUrlTemplate,
          userAgentPackageName: 'com.valor.deliverymanagement',
          errorTileCallback: (tile, error, stackTrace) {
            diagnosticsLog.add('map', 'tile load failed: $error');
          },
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}

/// A driver pin: a round avatar with the driver's initial, ringed
/// in the app blue. The caller wraps it in a tap handler.
class DmDriverPin extends StatelessWidget {
  const DmDriverPin({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A84FF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label.isEmpty ? '؟' : label[0],
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// A destination pin: the app-blue teardrop used for an order's
/// exact navigation target.
class DmDestinationPin extends StatelessWidget {
  const DmDestinationPin({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.location_on_rounded,
      color: Color(0xFF0A84FF),
      size: 40,
    );
  }
}
