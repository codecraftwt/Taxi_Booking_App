import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/config/map_config.dart';

class MapService {
  MapService._();
  static final MapService instance = MapService._();

  /// Build configured TileLayer with proper URL, headers and caching
  TileLayer buildTileLayer() {
    return TileLayer(
      urlTemplate: MapConfig.tileUrlTemplate,
      userAgentPackageName: MapConfig.userAgentPackageName,
      maxZoom: MapConfig.maxZoom,
      minZoom: MapConfig.minZoom,
      tileProvider: NetworkTileProvider(),
      errorTileCallback: (tile, error, stackTrace) {
        debugPrint('Tile loading warning for tile $tile: $error');
      },
    );
  }

  /// Fit the map viewport to enclose all coordinates comfortably with padding
  void fitCameraToBounds(
    MapController mapController,
    List<LatLng> points, {
    EdgeInsets padding = const EdgeInsets.all(50.0),
  }) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      mapController.move(points.first, MapConfig.defaultZoom);
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(points);
      final camera = mapController.camera;
      final mapCamera = CameraFit.bounds(
        bounds: bounds,
        padding: padding,
      ).fit(camera);

      mapController.move(mapCamera.center, mapCamera.zoom);
    } catch (e) {
      debugPrint('Error fitting camera bounds: $e');
      mapController.move(points.first, MapConfig.defaultZoom);
    }
  }

  /// Calculates bearing/heading in degrees (0 - 360) between two points
  double calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitudeInRad;
    final double lon1 = start.longitudeInRad;
    final double lat2 = end.latitudeInRad;
    final double lon2 = end.longitudeInRad;

    final double dLon = lon2 - lon1;
    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double radians = math.atan2(y, x);
    final double degrees = (radians * 180.0 / math.pi + 360.0) % 360.0;
    return degrees;
  }

  /// Calculates distance in kilometers between two points using Haversine
  double calculateDistanceKm(LatLng start, LatLng end) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, start, end);
  }

  /// Decodes Google-encoded polyline string to a List of LatLng
  List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final LatLng p = LatLng(lat / 1E5, lng / 1E5);
      poly.add(p);
    }
    return poly;
  }

  /// Builds a discreet map attribution widget complying with provider policies
  Widget buildAttributionWidget(BuildContext context) {
    return Positioned(
      bottom: 6,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          MapConfig.attributionText,
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

