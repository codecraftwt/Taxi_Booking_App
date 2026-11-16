import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:saffar_app/core/constants/strings.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Real-time WebSocket connection manager for Customer/Rider app
class CustomerSocketService {
  CustomerSocketService._();
  static final CustomerSocketService instance = CustomerSocketService._();

  IO.Socket? _socket;
  String? _currentUserId;
  String? _currentRideId;

  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<LatLng?> driverLocationNotifier = ValueNotifier<LatLng?>(null);
  final ValueNotifier<double> driverHeadingNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String?> rideStatusNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<Map<String, dynamic>?> tripCompletedNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<String?> cancellationNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<Map<String, dynamic>?> driverDetailsNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<Map<String, dynamic>?> searchProgressNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<String?> noDriversNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<Map<String, dynamic>?> fareUpdatedNotifier = ValueNotifier<Map<String, dynamic>?>(null);

  bool get isConnected => _socket?.connected ?? false;

  /// Connect customer to Socket.IO with Bearer authentication
  void connect(String userId, [String? token]) {
    if (_socket != null && _currentUserId == userId && _socket!.connected) {
      return;
    }

    _currentUserId = userId;
    disconnect();

    try {
      final socketUrl = Strings.socketUrl;
      debugPrint('[CustomerSocket] Connecting passenger $userId to $socketUrl');

      final optionsBuilder = IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000);

      if (token != null && token.isNotEmpty) {
        optionsBuilder.setAuth({'token': token});
      }

      _socket = IO.io(socketUrl, optionsBuilder.build());

      _socket?.onConnect((_) {
        debugPrint('[CustomerSocket] Passenger connected successfully');
        isConnectedNotifier.value = true;
        _socket?.emit('join_user', {'user_id': userId});

        if (_currentRideId != null) {
          _socket?.emit('join_ride', {'ride_id': _currentRideId});
        }
      });

      _socket?.onDisconnect((_) {
        debugPrint('[CustomerSocket] Disconnected from server');
        isConnectedNotifier.value = false;
      });

      _socket?.onConnectError((err) {
        debugPrint('[CustomerSocket] Connection error: $err');
        isConnectedNotifier.value = false;
      });

      // ── Event Listeners ───────────────────────────────────

      // 0. Progressive search & radius expansion progress
      void handleSearchProgress(dynamic data) {
        debugPrint('[CustomerSocket] Event: ride.searching: $data');
        if (data is Map) {
          searchProgressNotifier.value = Map<String, dynamic>.from(data);
          rideStatusNotifier.value = 'searching';
        }
      }
      _socket?.on('ride_searching', handleSearchProgress);
      _socket?.on('ride.searching', handleSearchProgress);

      // 0b. Exhaustion / No drivers found
      void handleNoDrivers(dynamic data) {
        debugPrint('[CustomerSocket] Event: ride.no_drivers_found: $data');
        rideStatusNotifier.value = 'no_drivers_found';
        if (data is Map) {
          noDriversNotifier.value = data['message']?.toString() ?? 'No drivers found nearby.';
        }
      }
      _socket?.on('no_drivers_found', handleNoDrivers);
      _socket?.on('ride.no_drivers_found', handleNoDrivers);

      // 1. Driver accepted booking
      void handleDriverAccepted(dynamic data) {
        debugPrint('[CustomerSocket] Event: ride_accepted: $data');
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          rideStatusNotifier.value = 'accepted';
          searchProgressNotifier.value = null;
          if (payload['driver'] != null) {
            driverDetailsNotifier.value = Map<String, dynamic>.from(payload['driver']);
          }
        }
      }
      _socket?.on('ride_accepted', handleDriverAccepted);
      _socket?.on('ride.driver_assigned', handleDriverAccepted);

      // 2. Driver approaching pickup
      _socket?.on('driver_reaching_pickup', (data) {
        debugPrint('[CustomerSocket] Event: driver_reaching_pickup');
        rideStatusNotifier.value = 'reaching_pickup';
      });

      // 3. Driver arrived at pickup
      _socket?.on('driver_arrived', (data) {
        debugPrint('[CustomerSocket] Event: driver_arrived');
        rideStatusNotifier.value = 'arrived';
      });

      // 4. Trip started after OTP verified
      _socket?.on('trip_started', (data) {
        debugPrint('[CustomerSocket] Event: trip_started');
        rideStatusNotifier.value = 'in_progress';
      });

      // 5. Driver live GPS telemetry broadcast
      void handleDriverLocationUpdate(dynamic data) {
        if (data is Map) {
          final lat = (data['latitude'] as num?)?.toDouble() ?? (data['lat'] as num?)?.toDouble();
          final lon = (data['longitude'] as num?)?.toDouble() ?? (data['lng'] as num?)?.toDouble() ?? (data['lon'] as num?)?.toDouble();
          final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;

          if (lat != null && lon != null) {
            driverLocationNotifier.value = LatLng(lat, lon);
            driverHeadingNotifier.value = heading;
          }
        }
      }
      _socket?.on('driver_location_update', handleDriverLocationUpdate);
      _socket?.on('ride:driver:location', handleDriverLocationUpdate);

      // 6. Trip concluded at destination
      _socket?.on('trip_completed', (data) {
        debugPrint('[CustomerSocket] Event: trip_completed: $data');
        rideStatusNotifier.value = 'completed';
        if (data is Map) {
          tripCompletedNotifier.value = Map<String, dynamic>.from(data);
        }
      });

      // 7. Dynamic fare pricing update broadcast from Super Admin
      _socket?.on('fare_config_updated', (data) {
        debugPrint('[CustomerSocket] Event: fare_config_updated: $data');
        if (data is Map) {
          fareUpdatedNotifier.value = Map<String, dynamic>.from(data);
        }
      });

      // 7. Ride cancelled
      _socket?.on('ride_cancelled', (data) {
        debugPrint('[CustomerSocket] Event: ride_cancelled: $data');
        rideStatusNotifier.value = 'cancelled';
        if (data is Map) {
          cancellationNotifier.value = data['reason']?.toString() ?? 'Ride was cancelled';
        }
      });
    } catch (e) {
      debugPrint('[CustomerSocket] Init error: $e');
    }
  }

  /// Subscribe to a specific ride tracking room
  void joinRide(String rideId) {
    _currentRideId = rideId;
    if (_socket != null && _socket!.connected) {
      _socket?.emit('join_ride', {'ride_id': rideId});
    }
  }

  /// Disconnect socket cleanly
  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      isConnectedNotifier.value = false;
    } catch (_) {}
  }
}

