import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/constants/strings.dart';
import 'package:saffar_app/core/models/address.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/user/data/repositories/user_repo.dart';

class SearchPlacesRepo {
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

  /// Gets addresses matching query via backend search endpoint
  Future<List<Address>> getSearchedAddresses(
    String searchText, {
    int page = 0,
  }) async {
    // 1. Primary: Saffar Backend Search Places Proxy (Database addresses + Popular locations)
    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/search_places',
        queryParameters: {'query': searchText},
        options: Options(
          headers: _authHeaders(),
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final list = data['places'] as List? ?? [];
        if (list.isNotEmpty) {
          final addresses = <Address>[];
          for (final item in list) {
            final double? lat = (item['lat'] as num?)?.toDouble();
            final double? lon = (item['lon'] as num?)?.toDouble();
            if (lat != null && lon != null) {
              addresses.add(
                Address(
                  id: item['id']?.toString() ?? 'addr_${DateTime.now().millisecondsSinceEpoch}_${addresses.length}',
                  place: item['place']?.toString() ?? 'Selected Location',
                  street: item['street']?.toString() ?? 'Selected Location',
                  latLng: LatLng(lat, lon),
                ),
              );
            }
          }
          if (addresses.isNotEmpty) {
            return addresses;
          }
        }
      }
    } catch (e) {
      debugPrint('Backend search places warning: $e');
    }

    // 2. Fallback: TomTom search if API key is present
    if (Strings.mapApiKey.isNotEmpty && Strings.mapApiKey != 'dummy_tomtom_api_key') {
      try {
        final encoded = Uri.encodeComponent(searchText);
        final Response response = await _dio.get(
          'https://api.tomtom.com/search/2/search/$encoded.json?key=${Strings.mapApiKey}&ofs=$page&limit=10',
        );

        final list = response.data['results'] as List? ?? [];
        return list.map((e) => Address.fromSearchPlacesApiResponseMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    return [];
  }

  /// Gets Address from latitude and longitude via backend reverse geocode endpoint
  Future<Address> getAddressFromLatLng(double lat, double lon) async {
    // 1. Primary: Saffar Backend Reverse Geocode Proxy
    try {
      final Response response = await _dio.get(
        '${Strings.baseApiUrl}/ride/geocode/reverse',
        queryParameters: {'lat': lat, 'lon': lon},
        options: Options(
          headers: _authHeaders(),
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          return Address(
            id: data['id']?.toString() ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
            place: data['place']?.toString() ?? 'Selected Location',
            street: data['street']?.toString() ?? data['address']?.toString() ?? 'Selected Location',
            latLng: LatLng(lat, lon),
          );
        }
      }
    } catch (e) {
      debugPrint('Backend reverse geocode warning: $e');
    }

    // 2. Fallback: TomTom Reverse Geocode if key available
    if (Strings.mapApiKey.isNotEmpty && Strings.mapApiKey != 'dummy_tomtom_api_key') {
      try {
        final Response response = await _dio.get(
          'https://api.tomtom.com/search/2/reverseGeocode/$lat,$lon.json?key=${Strings.mapApiKey}&radius=100',
        );
        final list = response.data['addresses'] as List? ?? [];
        if (list.isNotEmpty) {
          return Address.fromReverseGeocodeApiResponseMap(list[0] as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    // 3. Fallback coordinate descriptor
    return Address(
      id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
      place: 'Pin (${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)})',
      street: 'Location at ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
      latLng: LatLng(lat, lon),
    );
  }
}
