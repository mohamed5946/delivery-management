// Parses the Flex share text DeliveryFlow stores in an order's
// `notes` field into a destination: a written address (notes-only)
// plus coordinates (the EXACT navigation target).
//
// Accepted share formats (all seen in the field):
//   * `geo:30.0444,31.2357` / `geo:30.0444,31.2357?q=...`
//   * `geo:0,0?q=<address>` — address only, no coordinates
//   * Google Maps URL — `?q=lat,lng`, `?query=lat,lng`,
//     `/place/.../@lat,lng,17z`, or `?q=<address>`
//   * plain text `address @ lat,lng` (the Flex share form)
//   * bare `lat,lng`
//
// NO geocoding, ever: when the text carries no coordinates the
// result has none, and the UI says so plainly. Coordinates are
// validated to real lat/lng ranges; a pair outside them (e.g.
// `0,0` used as a placeholder) is treated as "no coordinates".
// Pure functions — unit-testable without a backend.

/// A parsed order destination.
class ParsedDestination {
  const ParsedDestination({required this.address, this.lat, this.lng});

  /// The written address, notes-only. Empty when the share carried
  /// coordinates alone.
  final String address;

  /// Exact navigation target, or null when the share had none.
  final double? lat;
  final double? lng;

  bool get hasCoords => lat != null && lng != null;

  /// `30.04440, 31.23570` — empty when there are no coordinates.
  String get coordsLabel => hasCoords
      ? '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'
      : '';
}

bool _validLat(double v) => v >= -90 && v <= 90;
bool _validLng(double v) => v >= -180 && v <= 180;

/// A coordinate pair: both in range, and not the `0,0` placeholder
/// geo intents use when they carry an address query instead.
({double lat, double lng})? _pair(double lat, double lng) {
  if (!_validLat(lat) || !_validLng(lng)) return null;
  if (lat == 0 && lng == 0) return null;
  return (lat: lat, lng: lng);
}

final _coordPair =
    RegExp(r'(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)');

/// The last valid coordinate-pair match in [text], or null.
/// (String.lastIndexOf with a RegExp is wrong here: it returns the
/// latest match *start*, so `30.04440` would match again at the `0`.)
RegExpMatch? _lastCoordMatch(String text) {
  RegExpMatch? found;
  for (final m in _coordPair.allMatches(text)) {
    final lat = double.tryParse(m.group(1)!);
    final lng = double.tryParse(m.group(2)!);
    if (lat == null || lng == null) continue;
    if (_pair(lat, lng) != null) found = m;
  }
  return found;
}

({double lat, double lng})? _lastPair(String text) {
  final m = _lastCoordMatch(text);
  if (m == null) return null;
  return (
    lat: double.parse(m.group(1)!),
    lng: double.parse(m.group(2)!),
  );
}

String _decode(String raw) {
  try {
    return Uri.decodeComponent(raw.replaceAll('+', ' '));
  } catch (_) {
    return raw;
  }
}

/// Reads one query param without Uri.splitQueryString (which throws
/// on raw non-ASCII / spaces — real geo shares carry raw Arabic).
String? _queryParam(String query, String key) {
  for (final part in query.split('&')) {
    final eq = part.indexOf('=');
    if (eq < 0) continue;
    if (part.substring(0, eq) == key) {
      return _decode(part.substring(eq + 1));
    }
  }
  return null;
}

/// Strips a trailing coordinate pair (and the `@`/separator before
/// it) from [text], leaving the written address.
String _addressWithoutCoords(String text) {
  final m = _lastCoordMatch(text);
  var address = m == null ? text : text.substring(0, m.start);
  address = address.trim();
  // Drop a dangling separator left behind by the removed pair.
  while (address.endsWith('@') ||
      address.endsWith('-') ||
      address.endsWith('—') ||
      address.endsWith(',') ||
      address.endsWith(':')) {
    address = address.substring(0, address.length - 1).trim();
  }
  return address;
}

/// Parses Flex share text into [ParsedDestination].
ParsedDestination parseDestination(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const ParsedDestination(address: '');

  // ── 1. geo: intent ──────────────────────────────────────────
  // geo:lat,lng  |  geo:lat,lng?q=...  |  geo:0,0?q=address
  if (text.toLowerCase().startsWith('geo:')) {
    final withoutScheme = text.substring(4);
    final queryIdx = withoutScheme.indexOf('?');
    final coordsPart =
        queryIdx >= 0 ? withoutScheme.substring(0, queryIdx) : withoutScheme;
    final query =
        queryIdx >= 0 ? withoutScheme.substring(queryIdx + 1) : '';
    final address = _queryParam(query, 'q') ?? '';
    final parts = coordsPart.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        final pair = _pair(lat, lng);
        if (pair != null) {
          return ParsedDestination(
            address: address,
            lat: pair.lat,
            lng: pair.lng,
          );
        }
      }
    }
    // geo:0,0?q=address (or an unparsable pair): address only.
    return ParsedDestination(address: address);
  }

  // ── 2. Google Maps URL ──────────────────────────────────────
  // ?q=lat,lng | ?query=lat,lng | /@lat,lng,17z | ?q=address
  if (text.startsWith('http://') || text.startsWith('https://')) {
    final uri = Uri.tryParse(text);
    if (uri != null) {
      final q = uri.queryParameters['q'] ?? uri.queryParameters['query'];
      if (q != null) {
        final pair = _lastPair(q);
        if (pair != null) {
          return ParsedDestination(
            address: '',
            lat: pair.lat,
            lng: pair.lng,
          );
        }
        return ParsedDestination(address: _decode(q));
      }
      // /place/.../@lat,lng,17z — coordinates live in the path.
      final at = RegExp(r'@(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)')
          .firstMatch(uri.path);
      if (at != null) {
        final lat = double.tryParse(at.group(1)!);
        final lng = double.tryParse(at.group(2)!);
        if (lat != null && lng != null) {
          final pair = _pair(lat, lng);
          if (pair != null) {
            return ParsedDestination(
              address: '',
              lat: pair.lat,
              lng: pair.lng,
            );
          }
        }
      }
    }
    // Short links (maps.app.goo.gl/...) carry nothing readable:
    // no coordinates, no address — the raw text is all we have.
    return ParsedDestination(address: text);
  }

  // ── 3. Plain text: "address @ lat,lng" or bare "lat,lng" ────
  final pair = _lastPair(text);
  if (pair != null) {
    return ParsedDestination(
      address: _addressWithoutCoords(text),
      lat: pair.lat,
      lng: pair.lng,
    );
  }
  return ParsedDestination(address: text);
}
