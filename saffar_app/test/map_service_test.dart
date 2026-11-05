import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/config/map_config.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/services/map_service.dart';

void main() {
  group('MapConfig Unit Tests', () {
    test('Default tile URL points to standard OpenStreetMap or configured provider', () {
      final url = MapConfig.tileUrlTemplate;
      expect(url.isNotEmpty, isTrue);
      expect(url.contains('{z}') && url.contains('{x}') && url.contains('{y}'), isTrue);
    });

    test('Attribution text is properly defined and compliant with OSM license', () {
      final attr = MapConfig.attributionText;
      expect(attr.contains('OpenStreetMap contributors'), isTrue);
    });

    test('Brand colors for maps match Saffar Design System', () {
      expect(MapConfig.routeColor, equals(Palette.primary));
      expect(MapConfig.pickupPinColor, equals(Palette.success));
      expect(MapConfig.destinationPinColor, equals(Palette.error));
    });
  });

  group('MapService Unit Tests', () {
    final mapService = MapService.instance;

    test('Calculates compass bearing correctly between two coordinates', () {
      // Due North: from lat 12 to lat 13 at same lon -> bearing ~0°
      final northBearing = mapService.calculateBearing(
        const LatLng(12.0, 77.0),
        const LatLng(13.0, 77.0),
      );
      expect(northBearing, closeTo(0.0, 1.0));

      // Due East: from lon 77 to lon 78 at same lat -> bearing ~90°
      final eastBearing = mapService.calculateBearing(
        const LatLng(12.0, 77.0),
        const LatLng(12.0, 78.0),
      );
      expect(eastBearing, closeTo(90.0, 2.0));

      // Due South: from lat 13 to lat 12 at same lon -> bearing ~180°
      final southBearing = mapService.calculateBearing(
        const LatLng(13.0, 77.0),
        const LatLng(12.0, 77.0),
      );
      expect(southBearing, closeTo(180.0, 1.0));
    });

    test('Calculates Haversine distance in kilometers accurately', () {
      // Bangalore MG Road to Koramangala (approx 5.2 km)
      const p1 = LatLng(12.9716, 77.5946);
      const p2 = LatLng(12.9352, 77.6245);
      final distKm = mapService.calculateDistanceKm(p1, p2);
      expect(distKm, greaterThan(4.0));
      expect(distKm, lessThan(6.0));
    });

    test('Decodes Google encoded polyline string to LatLng points', () {
      // Encoded polyline string representing a short line segment
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final decoded = mapService.decodePolyline(encoded);
      expect(decoded.length, greaterThanOrEqualTo(2));
      expect(decoded.first.latitude, closeTo(38.5, 0.5));
      expect(decoded.first.longitude, closeTo(-120.2, 0.5));
    });
  });
}

