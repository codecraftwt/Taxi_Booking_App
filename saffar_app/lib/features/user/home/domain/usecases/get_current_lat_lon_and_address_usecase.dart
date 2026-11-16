import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/location/data/repositories/location_repo.dart';
import 'package:saffar_app/features/search_places_and_get_route/data/repositories/search_places_repo.dart';
import 'package:latlong2/latlong.dart';

import 'package:saffar_app/core/models/address.dart';

class GetCurrentLatLngAndAddressUsecase {
  final SearchPlacesRepo _searchPlacesRepo = sl<SearchPlacesRepo>();
  final LocationRepo _locationRepo = sl<LocationRepo>();

  Future<Address?> call() async {
    try {
      final LatLng? currentPosition = await _locationRepo.getCurrentLatLng();

      if (currentPosition != null) {
        final double lat = currentPosition.latitude;
        final double lon = currentPosition.longitude;

        try {
          final Address address = await _searchPlacesRepo.getAddressFromLatLng(
            lat,
            lon,
          );
          return address;
        } catch (_) {
          // If reverse geocoding is slow or fails, still return the actual GPS coordinates
          return Address(
            place: 'Current Location',
            street: 'Live GPS Location',
            latLng: currentPosition,
          );
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
