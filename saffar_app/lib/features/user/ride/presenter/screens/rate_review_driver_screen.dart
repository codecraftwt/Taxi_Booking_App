import 'package:flutter/material.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/core/service_locator.dart';
import 'package:saffar_app/features/home/presenter/screens/home.dart';
import 'package:saffar_app/features/ride/data/repositories/ride_repo.dart';
import 'package:saffar_app/features/user/presenter/screens/user_support_screen.dart';

class RateReviewDriverScreen extends StatefulWidget {
  const RateReviewDriverScreen({
    Key? key,
    this.rideId = '',
    this.driverId = '',
    this.driverName = 'Driver',
    this.vehicleModel = 'Vehicle',
    this.vehicleNumber = '',
    this.driverRating = '5.0',
    this.totalTrips = '',
    this.pickupAddress = '',
    this.dropAddress = '',
    this.farePaid = '',
    this.paymentMethod = 'Paid',
    this.distance = '',
    this.duration = '',
  }) : super(key: key);

  static const String routeName = '/rate_driver';

  final String rideId;
  final String driverId;
  final String driverName;
  final String vehicleModel;
  final String vehicleNumber;
  final String driverRating;
  final String totalTrips;
  final String pickupAddress;
  final String dropAddress;
  final String farePaid;
  final String paymentMethod;
  final String distance;
  final String duration;

  @override
  State<RateReviewDriverScreen> createState() => _RateReviewDriverScreenState();
}

class _RateReviewDriverScreenState extends State<RateReviewDriverScreen> {
  final RideRepo _rideRepo = sl<RideRepo>();
  final TextEditingController _noteController = TextEditingController();

  double _rating = 5.0;
  final Set<String> _selectedTags = {
    'Smooth & Safe Driving',
    'Polite & Friendly',
    'Clean & Sanitized',
  };

  // Tip management
  String _selectedTipOption = '₹20';
  double _tipAmount = 20.0;
  bool _isSubmitting = false;
  bool _isLoadingDetails = false;

  // Ride details fetched dynamically from backend
  late String _rideId;
  late String _driverId;
  late String _driverName;
  late String _vehicleModel;
  late String _vehicleNumber;
  late String _driverRating;
  late String _totalTrips;
  late String _pickupAddress;
  late String _dropAddress;
  late String _farePaid;
  late String _paymentMethod;
  late String _distance;
  late String _duration;

  final List<Map<String, dynamic>> _tagOptions = const [
    {'name': 'Smooth & Safe Driving', 'icon': Icons.security_rounded},
    {'name': 'Polite & Friendly', 'icon': Icons.sentiment_very_satisfied_rounded},
    {'name': 'Perfect Navigation', 'icon': Icons.explore_outlined},
    {'name': 'Clean & Sanitized', 'icon': Icons.clean_hands_outlined},
    {'name': 'On-Time Arrival', 'icon': Icons.access_time_rounded},
    {'name': 'Pleasant Music', 'icon': Icons.music_note_rounded},
  ];

  final List<String> _tipOptions = const ['None', '₹10', '₹20', '₹50', 'Custom'];

  @override
  void initState() {
    super.initState();
    _rideId = widget.rideId;
    _driverId = widget.driverId;
    _driverName = widget.driverName;
    _vehicleModel = widget.vehicleModel;
    _vehicleNumber = widget.vehicleNumber;
    _driverRating = widget.driverRating;
    _totalTrips = widget.totalTrips;
    _pickupAddress = widget.pickupAddress;
    _dropAddress = widget.dropAddress;
    _farePaid = widget.farePaid;
    _paymentMethod = widget.paymentMethod;
    _distance = widget.distance;
    _duration = widget.duration;

    _fetchBackendReviewDetails();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchBackendReviewDetails() async {
    setState(() => _isLoadingDetails = true);
    try {
      final data = await _rideRepo.getReviewDetails(rideId: _rideId);
      if (mounted && data.isNotEmpty) {
        setState(() {
          if (data['ride_id'] != null) _rideId = data['ride_id'].toString();
          if (data['vehicle_type'] != null) _vehicleModel = data['vehicle_type'].toString();
          if (data['vehicle_number'] != null) _vehicleNumber = data['vehicle_number'].toString();
          if (data['distance_km'] != null) _distance = data['distance_km'].toString();
          if (data['duration_mins'] != null) _duration = data['duration_mins'].toString();
          if (data['pickup_address'] != null) _pickupAddress = data['pickup_address'].toString();
          if (data['drop_address'] != null) _dropAddress = data['drop_address'].toString();
          if (data['fare_paid'] != null) _farePaid = '₹${data['fare_paid']}';
          if (data['payment_method'] != null) _paymentMethod = 'Paid ${data['payment_method']}';

          if (data['driver'] != null && data['driver'] is Map) {
            final d = data['driver'] as Map;
            if (d['id'] != null) _driverId = d['id'].toString();
            if (d['name'] != null) _driverName = d['name'].toString();
            if (d['vehicle_model'] != null) _vehicleModel = d['vehicle_model'].toString();
            if (d['rating'] != null) _driverRating = d['rating'].toString();
            if (d['total_trips'] != null) _totalTrips = d['total_trips'].toString();
          }
        });
      }
    } catch (_) {
      // Keep initial fallback values matching Stitch mockup
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  void _onTipSelected(String option) {
    setState(() {
      _selectedTipOption = option;
      if (option == 'None') {
        _tipAmount = 0.0;
      } else if (option == '₹10') {
        _tipAmount = 10.0;
      } else if (option == '₹20') {
        _tipAmount = 20.0;
      } else if (option == '₹50') {
        _tipAmount = 50.0;
      } else if (option == 'Custom') {
        _showCustomTipDialog();
      }
    });
  }

  void _showCustomTipDialog() {
    final customController = TextEditingController(text: _tipAmount.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Enter Custom Tip',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: TextField(
          controller: customController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: 'Enter amount',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final val = double.tryParse(customController.text) ?? 0.0;
              setState(() {
                _tipAmount = val;
                _selectedTipOption = val > 0 ? '₹${val.toInt()}' : 'None';
              });
              Navigator.pop(ctx);
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getRatingFeedbackText() {
    if (_rating >= 4.8) return 'Excellent Ride! ${_rating.toStringAsFixed(1)}';
    if (_rating >= 4.0) return 'Great Ride! ${_rating.toStringAsFixed(1)}';
    if (_rating >= 3.0) return 'Good Ride ${_rating.toStringAsFixed(1)}';
    if (_rating >= 2.0) return 'Fair Experience ${_rating.toStringAsFixed(1)}';
    return 'Needs Improvement ${_rating.toStringAsFixed(1)}';
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);
    try {
      final res = await _rideRepo.rateDriver(
        rideId: _rideId,
        driverId: _driverId,
        rating: _rating,
        tags: _selectedTags.toList(),
        tipAmount: _tipAmount,
        note: _noteController.text.trim(),
      );

      if (mounted) {
        final message = res['message'] ?? 'Rating submitted successfully!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Palette.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showReceiptBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trip Receipt',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Palette.neutral),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PAID',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildReceiptRow('Base Fare', '₹40.00'),
            _buildReceiptRow('Distance Fare (8.4 km)', '₹73.00'),
            _buildReceiptRow('Promotion Discount', '-₹30.00', isGreen: true),
            _buildReceiptRow('Taxes & Surcharges', '₹30.00'),
            const Divider(height: 24),
            _buildReceiptRow('Total Charged', _farePaid, isBold: true),
            const SizedBox(height: 8),
            Text(
              _paymentMethod,
              style: const TextStyle(color: Palette.neutralVariant, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isGreen = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 15 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? Palette.neutral : Palette.neutralVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 17 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isGreen
                  ? const Color(0xFF10B981)
                  : (isBold ? Palette.primary : Palette.neutral),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(),

            if (_isLoadingDetails)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Color(0xFFEDF2F7),
                valueColor: AlwaysStoppedAnimation<Color>(Palette.primary),
              ),

            // Content Scroll
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  children: [
                    // Trip Completed Card
                    _buildTripCompletedCard(),
                    const SizedBox(height: 16),

                    // Driver Feedback Card
                    _buildDriverFeedbackCard(),
                    const SizedBox(height: 16),

                    // Compliments Section
                    _buildComplimentsSection(),
                    const SizedBox(height: 16),

                    // Tip Driver Card
                    _buildTipDriverCard(),
                    const SizedBox(height: 16),

                    // Leave Personal Note
                    _buildPersonalNoteCard(),
                    const SizedBox(height: 16),

                    // Need Help / Assist Card
                    _buildRiderAssistCard(),
                    const SizedBox(height: 24),

                    // Action Buttons
                    _buildActionButtons(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1)),
      ),
      child: Row(
        children: [
          // Back button
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: Palette.neutral),
            ),
          ),
          const SizedBox(width: 12),

          // Saffar Brand Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Palette.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.near_me_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),

          // Title
          const Expanded(
            child: Text(
              'Ride Completed',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Palette.neutral,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // User Avatar
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFE2E8F0),
            backgroundImage: NetworkImage(
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCompletedCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: TRIP COMPLETED & Skip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 15),
                    SizedBox(width: 5),
                    Text(
                      'TRIP COMPLETED',
                      style: TextStyle(
                        color: Color(0xFF047857),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (r) => false),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Vehicle & Plate Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.electric_rickshaw_rounded, color: Palette.primary, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                _vehicleModel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Palette.neutral,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _vehicleNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A8A),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$_distance • $_duration',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Pickup and Drop Address
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Pickup
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pickupAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Palette.neutral,
                        ),
                      ),
                    ),
                  ],
                ),
                // Connector line
                Container(
                  margin: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2,
                    height: 14,
                    color: const Color(0xFFCBD5E1),
                  ),
                ),
                // Drop
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Palette.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dropAddress,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Palette.neutral,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Paid & Receipt
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Color(0xFF475569)),
                  const SizedBox(width: 6),
                  Text(
                    '$_farePaid $_paymentMethod',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Palette.neutral,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _showReceiptBottomSheet,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'Receipt',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Palette.primary,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Palette.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverFeedbackCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          // Driver Avatar with Verified Check
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Driver Name
          Text(
            _driverName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Palette.neutral,
            ),
          ),
          const SizedBox(height: 4),

          // Vehicle model & rating info
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_vehicleModel • ',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFA800)),
              const SizedBox(width: 2),
              Text(
                '$_driverRating • ',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Palette.neutral,
                ),
              ),
              Text(
                _totalTrips,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Question
          Text(
            'How was your ride experience with $_driverName?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Star Rating Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1.0;
              final isFilled = _rating >= starValue;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = starValue;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    Icons.star_rounded,
                    size: 40,
                    color: isFilled ? const Color(0xFFFFA800) : const Color(0xFFE2E8F0),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Rating Feedback Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getRatingFeedbackText(),
              style: const TextStyle(
                color: Color(0xFFC2410C),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplimentsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'What made your trip great?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Palette.neutral,
                ),
              ),
              Text(
                'Tap to tag',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Wrap of chips
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _tagOptions.map((tag) {
              final name = tag['name'] as String;
              final icon = tag['icon'] as IconData;
              final isSelected = _selectedTags.contains(name);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTags.remove(name);
                    } else {
                      _selectedTags.add(name);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Palette.primary : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? Palette.primary : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTipDriverCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFF4F46E5), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a Tip for $_driverName',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Palette.neutral,
                    ),
                  ),
                  const Text(
                    '100% of tips go directly to your driver',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tip Options Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _tipOptions.map((opt) {
              final isSelected = _selectedTipOption == opt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => _onTipSelected(opt),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Palette.primary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Palette.primary : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Confirmation indicator text
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _tipAmount > 0
                      ? '₹${_tipAmount.toInt()} will be charged to Saffar Wallet upon submission'
                      : 'No tip selected for this trip',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalNoteCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Leave a personal note',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Palette.neutral,
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _noteController,
                builder: (context, val, _) {
                  return Text(
                    '${val.text.length}/240',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Text Field
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: 240,
            style: const TextStyle(fontSize: 14, color: Palette.neutral),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Was there something memorable $_driverName did? Let him know here...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Palette.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderAssistCard() {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, UserSupportScreen.routeName),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFF4F46E5), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need help or left an item behind?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Palette.neutral,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Contact 24/7 Saffar Rider Assist',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569), size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Primary Orange Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.primary,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isSubmitting ? null : _submitRating,
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Submit Rating & Finish',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),

        // Remind Me Later
        InkWell(
          onTap: () => Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (r) => false),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Remind Me Later',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
