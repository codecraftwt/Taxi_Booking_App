import 'package:location/location.dart';
import 'package:saffar_app/features/location/data/enums/location_permission_status.dart';
import 'package:latlong2/latlong.dart';

class LocationRepo {
  final Location _location = Location();

  /// Gets location permission status
  Future<LocationPermissionStatus> getLocationPermissionStatus() async {
    final PermissionStatus permissionStatus = await _location.hasPermission();

    switch (permissionStatus) {
      case PermissionStatus.granted:
        return LocationPermissionStatus.granted;
      case PermissionStatus.grantedLimited:
        return LocationPermissionStatus.granted;
      case PermissionStatus.denied:
        return LocationPermissionStatus.denied;
      case PermissionStatus.deniedForever:
        return LocationPermissionStatus.deniedForever;
    }
  }

  /// Shows dialog to request permission from the user
  Future<LocationPermissionStatus> requestPermission() async {
    final PermissionStatus permissionStatus =
        await _location.requestPermission();

    switch (permissionStatus) {
      case PermissionStatus.granted:
        return LocationPermissionStatus.granted;
      case PermissionStatus.grantedLimited:
        return LocationPermissionStatus.granted;
      case PermissionStatus.denied:
        return LocationPermissionStatus.denied;
      case PermissionStatus.deniedForever:
        return LocationPermissionStatus.deniedForever;
    }
  }

  /// Checks if location is enabled
  Future<bool> islocationEnabled() {
    return _location.serviceEnabled();
  }

  /// Shows the dialog box to request current location of user
  Future<bool> requestEnableLocation() {
    return _location.requestService();
  }

  /// Gets the user's current GPS location.
  /// Automatically checks and requests service enablement and runtime permissions.
  Future<LatLng?> getCurrentLatLng() async {
    try {
      // 1. Ensure GPS service is turned on
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return null;
      }

      // 2. Ensure location permission is granted
      PermissionStatus permissionStatus = await _location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus != PermissionStatus.granted &&
            permissionStatus != PermissionStatus.grantedLimited) {
          return null;
        }
      }
      if (permissionStatus == PermissionStatus.deniedForever) {
        return null;
      }

      // 3. Acquire current location fix
      final LocationData locationData = await _location.getLocation();

      if (locationData.latitude != null && locationData.longitude != null) {
        return LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
