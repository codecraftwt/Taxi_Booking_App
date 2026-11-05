import 'dart:async';
import 'package:flutter/material.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/ride/data/repositories/ride_repo.dart';

class PlaceItem {
  final String id;
  final String place;
  final String street;
  final String type;
  final String distanceKm;
  final int durationMins;
  final double? lat;
  final double? lon;

  const PlaceItem({
    required this.id,
    required this.place,
    required this.street,
    this.type = 'popular',
    this.distanceKm = '5.0 km',
    this.durationMins = 15,
    this.lat,
    this.lon,
  });

  factory PlaceItem.fromMap(Map<String, dynamic> map) {
    return PlaceItem(
      id: map['id']?.toString() ?? '',
      place: map['place']?.toString() ?? 'Selected Location',
      street: map['street']?.toString() ?? '',
      type: map['type']?.toString() ?? 'popular',
      distanceKm: map['distance_km']?.toString() ?? '4.5 km',
      durationMins: int.tryParse(map['duration_mins']?.toString() ?? '15') ?? 15,
      lat: (map['lat'] as num?)?.toDouble(),
      lon: (map['lon'] as num?)?.toDouble(),
    );
  }
}

typedef OnLocationSelectedCallback = void Function(
  String pickup,
  String destination,
  String distance,
  String duration, {
  double? destLat,
  double? destLon,
});

class ChooseLocationModal extends StatefulWidget {
  final String initialPickup;
  final String? initialDestination;
  final bool focusDestination;
  final OnLocationSelectedCallback onLocationSelected;

  const ChooseLocationModal({
    Key? key,
    this.initialPickup = 'Current Location',
    this.initialDestination,
    this.focusDestination = true,
    required this.onLocationSelected,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    String initialPickup = 'Current Location',
    String? initialDestination,
    bool focusDestination = true,
    required OnLocationSelectedCallback onLocationSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChooseLocationModal(
        initialPickup: initialPickup,
        initialDestination: initialDestination,
        focusDestination: focusDestination,
        onLocationSelected: onLocationSelected,
      ),
    );
  }

  @override
  State<ChooseLocationModal> createState() => _ChooseLocationModalState();
}

class _ChooseLocationModalState extends State<ChooseLocationModal> {
  late final TextEditingController _pickupController;
  late final TextEditingController _destController;
  late final FocusNode _destFocusNode;
  late final FocusNode _pickupFocusNode;

  final RideRepo _rideRepo = sl<RideRepo>();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<PlaceItem> _placesList = [];

  Map<String, dynamic>? _savedPlacesData;

  @override
  void initState() {
    super.initState();
    _pickupController = TextEditingController(text: widget.initialPickup);
    _destController = TextEditingController(text: widget.initialDestination ?? '');
    _destFocusNode = FocusNode();
    _pickupFocusNode = FocusNode();

    // Auto-focus appropriate field after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.focusDestination) {
        _destFocusNode.requestFocus();
      } else {
        _pickupFocusNode.requestFocus();
      }
    });

    _loadInitialSavedAndRecentPlaces();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pickupController.dispose();
    _destController.dispose();
    _destFocusNode.dispose();
    _pickupFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSavedAndRecentPlaces() async {
    setState(() => _isLoading = true);
    try {
      final saved = await _rideRepo.getSavedAndRecentPlaces();
      final places = await _rideRepo.searchPlaces('');

      if (mounted) {
        setState(() {
          _savedPlacesData = saved;
          _placesList = places.map((m) => PlaceItem.fromMap(m)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoading = true);
      try {
        final results = await _rideRepo.searchPlaces(query.trim());
        if (mounted) {
          setState(() {
            _placesList = results.map((m) => PlaceItem.fromMap(m)).toList();
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  void _swapPickupAndDestination() {
    final temp = _pickupController.text;
    setState(() {
      _pickupController.text = _destController.text;
      _destController.text = temp;
    });
  }

  void _confirmSelection(PlaceItem selected) {
    final pickup = _pickupController.text.trim().isNotEmpty
        ? _pickupController.text.trim()
        : 'Current Location';
    final destination = selected.place.isNotEmpty
        ? '${selected.place}, ${selected.street}'
        : selected.street;

    Navigator.pop(context);

    widget.onLocationSelected(
      pickup,
      destination,
      selected.distanceKm,
      '${selected.durationMins} mins',
      destLat: selected.lat,
      destLon: selected.lon,
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'work':
        return Icons.business_center_rounded;
      case 'airport':
        return Icons.flight_takeoff_rounded;
      case 'metro':
      case 'train':
        return Icons.train_rounded;
      case 'mall':
        return Icons.shopping_bag_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'recent':
        return Icons.history_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  Color _getIconBgColor(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return const Color(0xFFE0F2FE);
      case 'work':
        return const Color(0xFFFEF3C7);
      case 'airport':
        return const Color(0xFFEEF2FF);
      case 'metro':
      case 'train':
        return const Color(0xFFECFDF5);
      case 'mall':
        return const Color(0xFFFCE7F3);
      case 'recent':
        return const Color(0xFFF1F5F9);
      default:
        return const Color(0xFFFFEDD5);
    }
  }

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return const Color(0xFF0284C7);
      case 'work':
        return const Color(0xFFD97706);
      case 'airport':
        return const Color(0xFF4F46E5);
      case 'metro':
      case 'train':
        return const Color(0xFF059669);
      case 'mall':
        return const Color(0xFFDB2777);
      case 'recent':
        return const Color(0xFF64748B);
      default:
        return Palette.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 16,
        right: 16,
        bottom: bottomInset > 0 ? bottomInset + 10 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header: Title & Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan Your Journey',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Palette.neutral,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Choose pickup and destination locations',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dual Location Input Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Pickup Location Field
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pickupController,
                        focusNode: _pickupFocusNode,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Palette.neutral,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter pickup point...',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_pickupController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _pickupController.clear()),
                        child: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),

                // Destination Location Field + Swap Button
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Palette.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _destController,
                        focusNode: _destFocusNode,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Palette.neutral,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Where would you like to go?',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                            color: Color(0xFF94A3B8),
                          ),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_destController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _destController.clear();
                            _onSearchChanged('');
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    GestureDetector(
                      onTap: _swapPickupAndDestination,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          size: 16,
                          color: Palette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickCategoryChip(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFE0F2FE),
                  onTap: () {
                    final home = _savedPlacesData?['home'];
                    final p = PlaceItem(
                      id: home?['id'] ?? 'home',
                      place: home?['place'] ?? 'Home',
                      street: home?['street'] ?? '12 Elm Street, Indiranagar',
                      type: 'home',
                      distanceKm: home?['distance_km'] ?? '3.5 km',
                      durationMins: home?['duration_mins'] ?? 11,
                    );
                    _confirmSelection(p);
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickCategoryChip(
                  icon: Icons.business_center_rounded,
                  label: 'Office',
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  onTap: () {
                    final office = _savedPlacesData?['office'];
                    final p = PlaceItem(
                      id: office?['id'] ?? 'office',
                      place: office?['place'] ?? 'Office (Work)',
                      street: office?['street'] ?? 'Tech Park BD, Tower C',
                      type: 'work',
                      distanceKm: office?['distance_km'] ?? '8.4 km',
                      durationMins: office?['duration_mins'] ?? 22,
                    );
                    _confirmSelection(p);
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickCategoryChip(
                  icon: Icons.flight_takeoff_rounded,
                  label: 'Airport',
                  color: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFEEF2FF),
                  onTap: () {
                    _destController.text = 'Airport';
                    _onSearchChanged('Airport');
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickCategoryChip(
                  icon: Icons.train_rounded,
                  label: 'Metro',
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                  onTap: () {
                    _destController.text = 'Metro';
                    _onSearchChanged('Metro');
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickCategoryChip(
                  icon: Icons.history_rounded,
                  label: 'Recent',
                  color: const Color(0xFF64748B),
                  bgColor: const Color(0xFFF1F5F9),
                  onTap: () {
                    final recentList = _savedPlacesData?['recent'] as List<dynamic>?;
                    if (recentList != null && recentList.isNotEmpty) {
                      final r = recentList.first as Map<String, dynamic>;
                      _confirmSelection(PlaceItem.fromMap(r));
                    } else {
                      _destController.clear();
                      FocusScope.of(context).requestFocus(_destFocusNode);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Section Header: Available Destinations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _destController.text.isEmpty
                    ? 'SUGGESTED & RECENT PLACES'
                    : 'SEARCH RESULTS',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Palette.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Scrollable List of Destinations
          Expanded(
            child: _placesList.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No matching places found for "${_destController.text}"',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try searching for airport, metro, mall or office.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _placesList.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (ctx, index) {
                      final place = _placesList[index];
                      final icon = _getIconForType(place.type);
                      final iconBg = _getIconBgColor(place.type);
                      final iconColor = _getIconColor(place.type);

                      return InkWell(
                        onTap: () => _confirmSelection(place),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: iconBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, color: iconColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place.place,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Palette.neutral,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      place.street,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      place.distanceKm,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Palette.neutral,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${place.durationMins} mins',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCategoryChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
