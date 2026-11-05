import 'package:flutter/foundation.dart';
import 'package:saffar_app/core/constants/strings.dart';
import 'package:saffar_app/core/models/ride_request.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class DriverSocketService {
  DriverSocketService._();
  static final DriverSocketService instance = DriverSocketService._();

  IO.Socket? _socket;
  String? _currentDriverId;

  final ValueNotifier<RideRequest?> incomingRequestNotifier = ValueNotifier<RideRequest?>(null);
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> alertNotificationNotifier = ValueNotifier<String?>(null);

  bool get isConnected => _socket?.connected ?? false;
  RideRequest? get currentIncomingRequest => incomingRequestNotifier.value;

  /// Connect to Socket.IO and listen for driver ride dispatches
  void connect(String driverId) {
    if (_socket != null && _currentDriverId == driverId && _socket!.connected) {
      return;
    }

    _currentDriverId = driverId;
    disconnect();

    try {
      final socketUrl = Strings.socketUrl;
      debugPrint('[Socket] Connecting driver $driverId to $socketUrl');

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(2000)
            .build(),
      );

      _socket?.onConnect((_) {
        debugPrint('[Socket] Driver connected to Socket.IO server');
        isConnectedNotifier.value = true;
        _socket?.emit('join_driver', {'driver_id': driverId});
      });

      _socket?.onDisconnect((_) {
        debugPrint('[Socket] Driver disconnected from Socket.IO server');
        isConnectedNotifier.value = false;
      });

      _socket?.onConnectError((err) {
        debugPrint('[Socket] Connection error: $err');
        isConnectedNotifier.value = false;
      });

      // Handle incoming ride booking request
      void handleIncomingOffer(dynamic data) {
        debugPrint('[Socket] Received ride offer: $data');
        if (data is Map) {
          try {
            final request = RideRequest.fromMap(Map<String, dynamic>.from(data));
            incomingRequestNotifier.value = request;
          } catch (e) {
            debugPrint('[Socket] Error parsing RideRequest: $e');
          }
        }
      }
      _socket?.on('new_ride_request', handleIncomingOffer);
      _socket?.on('ride.offer_received', handleIncomingOffer);

      // Handle offer expired / timed out
      void handleOfferExpired(dynamic data) {
        debugPrint('[Socket] Received ride_offer_expired: $data');
        final current = incomingRequestNotifier.value;
        if (current != null && data is Map && data['ride_id']?.toString() == current.rideId) {
          incomingRequestNotifier.value = null;
          alertNotificationNotifier.value = 'Ride offer timed out';
        }
      }
      _socket?.on('ride_offer_expired', handleOfferExpired);
      _socket?.on('ride.offer_expired', handleOfferExpired);

      // Handle offer cancelled by customer
      void handleOfferCancelled(dynamic data) {
        debugPrint('[Socket] Received ride_offer_cancelled: $data');
        final current = incomingRequestNotifier.value;
        if (current != null && data is Map && data['ride_id']?.toString() == current.rideId) {
          incomingRequestNotifier.value = null;
          alertNotificationNotifier.value = data['reason']?.toString() ?? 'Rider cancelled the request';
        }
      }
      _socket?.on('ride_offer_cancelled', handleOfferCancelled);
      _socket?.on('ride.offer_cancelled', handleOfferCancelled);

      // Handle when ride was accepted by another driver or expired
      _socket?.on('ride_taken', (data) {
        debugPrint('[Socket] Received ride_taken: $data');
        final current = incomingRequestNotifier.value;
        if (current != null && data is Map && data['ride_id']?.toString() == current.rideId) {
          incomingRequestNotifier.value = null;
          alertNotificationNotifier.value = 'Ride was accepted by another driver';
        }
      });

      // Handle when user cancelled the ride booking
      _socket?.on('ride_cancelled', (data) {
        debugPrint('[Socket] Received ride_cancelled: $data');
        final current = incomingRequestNotifier.value;
        if (current != null && data is Map && data['ride_id']?.toString() == current.rideId) {
          incomingRequestNotifier.value = null;
          alertNotificationNotifier.value = 'Rider cancelled the request';
        }
      });
    } catch (e) {
      debugPrint('[Socket] Init error: $e');
    }
  }

  void setIncomingRequest(RideRequest? req) {
    incomingRequestNotifier.value = req;
  }

  void clearCurrentRequest() {
    incomingRequestNotifier.value = null;
  }

  /// Accept an incoming offer via WebSocket
  void acceptOffer(String rideId) {
    if (_socket != null && _socket!.connected && _currentDriverId != null) {
      _socket?.emit('accept_offer', {
        'ride_id': rideId,
        'driver_id': _currentDriverId,
      });
    }
  }

  /// Reject an incoming offer via WebSocket
  void rejectOffer(String rideId) {
    if (_socket != null && _socket!.connected && _currentDriverId != null) {
      _socket?.emit('reject_offer', {
        'ride_id': rideId,
        'driver_id': _currentDriverId,
      });
    }
    incomingRequestNotifier.value = null;
  }

  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    isConnectedNotifier.value = false;
  }
}

