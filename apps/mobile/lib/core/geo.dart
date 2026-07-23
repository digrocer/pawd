import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// A resolved location: coordinates + ISO country + display city.
class GeoResult {
  final double lat;
  final double lng;
  final String? country; // ISO-3166 alpha-2
  final String? city;
  const GeoResult(this.lat, this.lng, this.country, this.city);
}

/// Free geocoding via the OS geocoder — no paid Maps API key required.
class Geo {
  /// Device GPS → coordinates + reverse-geocoded country/city.
  /// Returns null if permission denied or GPS unavailable.
  static Future<GeoResult?> current() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final rev = await _reverse(pos.latitude, pos.longitude);
      return GeoResult(pos.latitude, pos.longitude, rev?.$1, rev?.$2);
    } catch (_) {
      return null;
    }
  }

  /// Forward-geocode a typed city/area → coordinates + country. Null if not found.
  static Future<GeoResult?> fromQuery(String query) async {
    try {
      final locs = await locationFromAddress(query);
      if (locs.isEmpty) return null;
      final l = locs.first;
      final rev = await _reverse(l.latitude, l.longitude);
      return GeoResult(l.latitude, l.longitude, rev?.$1, rev?.$2 ?? query);
    } catch (_) {
      return null;
    }
  }

  static Future<(String?, String?)?> _reverse(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final m = marks.first;
      final city = [m.locality, m.administrativeArea].where((s) => (s ?? '').isNotEmpty).join(', ');
      return (m.isoCountryCode, city.isEmpty ? null : city);
    } catch (_) {
      return null;
    }
  }
}
