import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/palette.dart';

/// Configuration and theme constants for Saffar flutter_map integration
class MapConfig {
  MapConfig._();

  /// Map Tile URL template.
  /// Defaults to OpenStreetMap standard tiles.
  /// Can be configured via .env [MAP_TILE_URL] (e.g. MapTiler, Stadia Maps, or self-hosted tile server).
  static String get tileUrlTemplate {
    if (dotenv.isInitialized) {
      final customUrl = dotenv.env['MAP_TILE_URL'];
      if (customUrl != null && customUrl.isNotEmpty) {
        final apiKey = dotenv.env['MAP_TILE_KEY'] ?? '';
        return customUrl.replaceAll('{key}', apiKey);
      }
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  /// Package name identifier sent in User-Agent header (required by OSM/MapTiler policies)
  static const String userAgentPackageName = 'com.saffar.app';

  /// Standard fallback location (Kolhapur / Maharashtra center)
  static const LatLng defaultCenter = LatLng(16.7050, 74.2433);

  /// Map zoom constraints
  static const double defaultZoom = 14.5;
  static const double activeTripZoom = 15.5;
  static const double minZoom = 3.0;
  static const double maxZoom = 19.0;

  /// Saffar Brand Palette Styling for Maps
  static const Color routeColor = Palette.primary; // #FF6B00 Orange
  static const Color routeBorderColor = Palette.secondary; // #173B67 Deep Blue
  static const Color pickupPinColor = Palette.success; // #20A46B Green
  static const Color destinationPinColor = Palette.error; // #E54848 Red
  static const Color driverMarkerColor = Palette.primary; // #FF6B00
  static const Color mapCardBackgroundColor = Palette.card; // #FFFFFF

  /// Attribution data required by tile providers
  static const String osmAttributionText = '© OpenStreetMap contributors';
  static const String mapTilerAttributionText = '© MapTiler © OpenStreetMap contributors';

  /// Get appropriate attribution text depending on active tile provider
  static String get attributionText {
    if (dotenv.isInitialized) {
      final customUrl = dotenv.env['MAP_TILE_URL'] ?? '';
      if (customUrl.contains('maptiler')) {
        return mapTilerAttributionText;
      }
    }
    return osmAttributionText;
  }
}
