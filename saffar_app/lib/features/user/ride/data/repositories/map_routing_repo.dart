import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/constants/strings.dart';
import 'package:saffar_app/core/models/address.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/core/services/map_service.dart';
import 'package:saffar_app/features/user/data/repositories/user_repo.dart';

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.durationText,
    this.source = 'backend',
  });

  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  final String durationText;
  final String source;
}

class MapRoutingRepo {
  final Dio _dio = sl<Dio>();

  Map<String, dynamic> _authHeaders() {
    final headers = <String, dynamic>{};
    try {
      final userRepo = sl<UserRepo>();
      final token = userRepo.getTokenFromLocalStorage();
      if (token.isNotEmpty) {
        headers['authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers;
  }

  /// Calculates road route between origin and destination via backend proxy
  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
    String vehicleType = 'Auto',
  }) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/ride/route',
        queryParameters: {
          'origin_lat': origin.latitude,
          'origin_lon': origin.longitude,
          'dest_lat': destination.latitude,
          'dest_lon': destination.longitude,
          'vehicle_type': vehicleType,
        },
        options: Options(headers: _authHeaders()),
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        final rawPoints = data['points'] as List? ?? [];
        final points = rawPoints.map((p) {
          final lat = (p['latitude'] as num).toDouble();
          final lon = (p['longitude'] as num).toDouble();
          return LatLng(lat, lon);
        }).toList();

        final distanceKm = (data['distance_km'] as num?)?.toDouble() ?? 0.0;
        final durationMins = (data['duration_minutes'] as num?)?.toInt() ?? 5;
        final durationText = data['duration_text']?.toString() ?? '$durationMins mins';

        return RouteResult(
          points: points.isNotEmpty ? points : [origin, destination],
          distanceKm: distanceKm,
          durationMinutes: durationMins,
          durationText: durationText,
          source: data['source']?.toString() ?? 'backend',
        );
      }
    } catch (e) {
      debugPrint('Backend routing failed: $e, using local road model');
    }

    // Graceful offline fallback: interpolate coordinates
    final directDistance = MapService.instance.calculateDistanceKm(origin, destination);
    final distanceKm = directDistance * 1.25;
    final durationMins = (distanceKm * 2.5).ceil().clamp(3, 120);

    // Create 8 smooth intermediate waypoints
    final fallbackPoints = <LatLng>[origin];
    const int segments = 8;
    final dLat = destination.latitude - origin.latitude;
    final dLon = destination.longitude - origin.longitude;
    final perpLat = -dLon * 0.08;
    final perpLon = dLat * 0.08;

    for (int i = 1; i < segments; i++) {
      final t = i / segments;
      final curve = (i % 2 == 0 ? 1 : -0.7) * 0.5;
      fallbackPoints.add(
        LatLng(
          origin.latitude + t * dLat + curve * perpLat,
          origin.longitude + t * dLon + curve * perpLon,
        ),
      );
    }
    fallbackPoints.add(destination);

    return RouteResult(
      points: fallbackPoints,
      distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
      durationMinutes: durationMins,
      durationText: '$durationMins mins',
      source: 'client_fallback',
    );
  }

  /// Reverse geocode GPS coordinate into human-readable Address via backend proxy
  Future<Address?> reverseGeocode(LatLng location) async {
    try {
      final response = await _dio.get(
        '${Strings.baseApiUrl}/ride/geocode/reverse',
        queryParameters: {
          'lat': location.latitude,
          'lon': location.longitude,
        },
        options: Options(headers: _authHeaders()),
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        return Address(
          id: data['id']?.toString() ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
          place: data['place']?.toString() ?? 'Selected Location',
          street: data['street']?.toString() ?? data['address']?.toString() ?? 'Selected Location',
          latLng: location,
        );
      }
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
    }

    return Address(
      id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
      place: 'Pin (${location.latitude.toStringAsFixed(3)}, ${location.longitude.toStringAsFixed(3)})',
      street: 'Selected Map Location',
      latLng: location,
    );
  }
}

