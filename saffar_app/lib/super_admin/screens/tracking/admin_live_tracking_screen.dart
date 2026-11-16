import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/admin_theme.dart';
import '../../core/admin_api_service.dart';

class AdminLiveTrackingScreen extends StatefulWidget {
  const AdminLiveTrackingScreen({Key? key}) : super(key: key);

  @override
  State<AdminLiveTrackingScreen> createState() => _AdminLiveTrackingScreenState();
}

class _AdminLiveTrackingScreenState extends State<AdminLiveTrackingScreen> {
  final MapController _mapController = MapController();
  List<dynamic> _drivers = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  Timer? _pollingTimer;
  Map<String, dynamic>? _selectedDriver;

  final LatLng _defaultCenter = const LatLng(18.5204, 73.8567); // Pune / Mumbai region default

  @override
  void initState() {
    super.initState();
    _fetchLiveDrivers();
    // Poll every 10 seconds for real-time fleet movement
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchLiveDrivers(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveDrivers({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final list = await AdminApiService.instance.getLiveDrivers(
        category: _selectedCategory,
        status: _selectedStatus,
      );
      setState(() {
        _drivers = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!silent) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load live fleet: $e'), backgroundColor: AdminTheme.errorRed),
          );
        }
      }
    }
  }

  IconData _getVehicleIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler_rounded;
      case 'auto':
        return Icons.electric_rickshaw_rounded;
      case 'sedan':
      case 'prime sedan':
        return Icons.directions_car_filled_rounded;
      case 'car':
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    int availableCount = 0;
    int onTripCount = 0;
    for (var d in _drivers) {
      if (d['is_on_trip'] == true || d['status'] == 'on_trip') {
        onTripCount++;
      } else {
        availableCount++;
      }
    }

    final markers = _drivers.map((d) {
      final double lat = double.tryParse(d['lat']?.toString() ?? '') ?? _defaultCenter.latitude;
      final double lng = double.tryParse(d['lng']?.toString() ?? '') ?? _defaultCenter.longitude;
      final bool onTrip = d['is_on_trip'] == true || d['status'] == 'on_trip';
      final Color pinColor = onTrip ? AdminTheme.accentAmber : AdminTheme.successGreen;

      return Marker(
        point: LatLng(lat, lng),
        width: 48,
        height: 48,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedDriver = d;
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pinColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: pinColor.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: Icon(
                  _getVehicleIcon(d['category']),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              if (onTrip)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Fleet Tracking', style: AdminTheme.headingLarge),
                  const SizedBox(height: 4),
                  Text('Real-time GPS positions and status for all online drivers', style: AdminTheme.bodySecondary),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AdminTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AdminTheme.successGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AdminTheme.successGreen, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text('$availableCount Available', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.successGreen, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AdminTheme.accentAmber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AdminTheme.accentAmber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AdminTheme.accentAmber, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text('$onTripCount On Trip', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.accentAmber, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _fetchLiveDrivers(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.cardWhite,
                      foregroundColor: AdminTheme.textPrimary,
                      side: const BorderSide(color: AdminTheme.borderSubtle),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Filter toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AdminTheme.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTheme.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded, color: AdminTheme.textSecondary, size: 20),
                const SizedBox(width: 10),
                const Text('Vehicle Type:', style: TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedCategory,
                  underline: const SizedBox(),
                  items: ['All', 'Bike', 'Auto', 'Car', 'Prime Sedan']
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                      _fetchLiveDrivers();
                    }
                  },
                ),
                const SizedBox(width: 24),
                const Text('Trip Status:', style: TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedStatus,
                  underline: const SizedBox(),
                  items: ['All', 'online', 'on_trip']
                      .map((st) => DropdownMenuItem(value: st, child: Text(st == 'All' ? 'All Drivers' : st == 'online' ? 'Available Only' : 'On Trip Only')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedStatus = val);
                      _fetchLiveDrivers();
                    }
                  },
                ),
                const Spacer(),
                const Text(
                  'Auto-refreshing every 10s',
                  style: TextStyle(color: AdminTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Map Container
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _drivers.isNotEmpty && _drivers[0]['lat'] != null
                          ? LatLng(
                              double.tryParse(_drivers[0]['lat'].toString()) ?? _defaultCenter.latitude,
                              double.tryParse(_drivers[0]['lng'].toString()) ?? _defaultCenter.longitude,
                            )
                          : _defaultCenter,
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.saffar.superadmin',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                  // Loading indicator overlay
                  if (_isLoading)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AdminTheme.primaryOrange)),
                            SizedBox(width: 8),
                            Text('Locating fleet...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  // Floating Driver Details Card when a pin is selected
                  if (_selectedDriver != null)
                    Positioned(
                      bottom: 24,
                      left: 24,
                      child: Container(
                        width: 340,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AdminTheme.primaryOrange.withOpacity(0.15),
                                      child: const Icon(Icons.person, color: AdminTheme.primaryOrange),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedDriver!['name'] ?? 'Driver #${_selectedDriver!['id']}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text(
                                          _selectedDriver!['phone'] ?? 'No phone',
                                          style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20, color: AdminTheme.textSecondary),
                                  onPressed: () => setState(() => _selectedDriver = null),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Vehicle:', style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
                                Text(
                                  '${_selectedDriver!['vehicle_model'] ?? 'Standard'} (${_selectedDriver!['category'] ?? 'Car'})',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Plate Number:', style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
                                Text(
                                  _selectedDriver!['plate_number'] ?? '—',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('GPS Coordinates:', style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
                                Text(
                                  '${_selectedDriver!['lat']?.toString().substring(0, 7) ?? '—'}, ${_selectedDriver!['lng']?.toString().substring(0, 7) ?? '—'}',
                                  style: const TextStyle(fontSize: 12, color: AdminTheme.secondaryBlue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: (_selectedDriver!['is_on_trip'] == true || _selectedDriver!['status'] == 'on_trip')
                                    ? AdminTheme.accentAmber.withOpacity(0.12)
                                    : AdminTheme.successGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                (_selectedDriver!['is_on_trip'] == true || _selectedDriver!['status'] == 'on_trip')
                                    ? 'OCCUPIED ON TRIP'
                                    : 'ONLINE & READY FOR DISPATCH',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: (_selectedDriver!['is_on_trip'] == true || _selectedDriver!['status'] == 'on_trip')
                                      ? AdminTheme.accentAmber
                                      : AdminTheme.successGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

