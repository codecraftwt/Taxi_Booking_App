import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/palette.dart';

class MapMarkerWidgets {
  MapMarkerWidgets._();

  /// Center "YOU" marker with pulse circle and badge
  static Marker buildUserLocationMarker(LatLng position) {
    return Marker(
      point: position,
      width: 70,
      height: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0CC),
              shape: BoxShape.circle,
              border: Border.all(color: Palette.primary, width: 2),
            ),
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Palette.secondary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Palette.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: Palette.neutral,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'YOU',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pickup pin (Green with pin stem)
  static Marker buildPickupMarker(LatLng position, {String label = 'PICKUP'}) {
    return Marker(
      point: position,
      width: 80,
      height: 60,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Palette.success,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Palette.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Destination pin (Red with pin stem)
  static Marker buildDestinationMarker(LatLng position, {String label = 'DROP-OFF'}) {
    return Marker(
      point: position,
      width: 80,
      height: 60,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Palette.error,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Palette.error,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Vehicle Marker with category icon, ETA pill, and optional rotation heading
  static Marker buildVehicleMarker({
    required LatLng position,
    required String category,
    String eta = '3m',
    double heading = 0.0,
    bool isHighlighted = false,
  }) {
    IconData iconData = Icons.electric_rickshaw;
    final catLower = category.toLowerCase();
    if (catLower.contains('bike')) {
      iconData = Icons.two_wheeler;
    } else if (catLower.contains('car') || catLower.contains('sedan') || catLower.contains('mini')) {
      iconData = Icons.directions_car;
    }

    return Marker(
      point: position,
      width: 60,
      height: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ETA badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: isHighlighted ? Palette.primary : Palette.secondary,
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              eta,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Vehicle icon in circular badge with subtle rotation
          Transform.rotate(
            angle: heading * (math.pi / 180.0),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isHighlighted ? Palette.primary : Palette.secondary,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                iconData,
                color: isHighlighted ? Palette.primary : Palette.secondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Moving driver navigation marker with prominent compass arrow
  static Marker buildDriverLiveMarker({
    required LatLng position,
    required double heading,
    String category = 'Auto',
  }) {
    IconData icon = Icons.electric_rickshaw;
    if (category.toLowerCase().contains('bike')) icon = Icons.two_wheeler;
    if (category.toLowerCase().contains('car')) icon = Icons.directions_car;

    return Marker(
      point: position,
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Directional pointer / halo
          Transform.rotate(
            angle: heading * (math.pi / 180.0),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Palette.primary.withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Align(
                alignment: Alignment.topCenter,
                child: Icon(Icons.arrow_drop_up, color: Palette.primary, size: 18),
              ),
            ),
          ),
          // Center Vehicle Disc
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Palette.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

