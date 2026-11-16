import 'package:flutter/material.dart';
import '../../core/admin_theme.dart';
import '../../core/admin_api_service.dart';

class AdminRidesScreen extends StatefulWidget {
  const AdminRidesScreen({Key? key}) : super(key: key);

  @override
  State<AdminRidesScreen> createState() => _AdminRidesScreenState();
}

class _AdminRidesScreenState extends State<AdminRidesScreen> {
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRides = 0;
  List<dynamic> _rides = [];

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _statusTabs = [
    {'label': 'All Rides', 'value': 'all'},
    {'label': 'Active / In Progress', 'value': 'in_progress'},
    {'label': 'Requested', 'value': 'requested'},
    {'label': 'Completed', 'value': 'completed'},
    {'label': 'Cancelled', 'value': 'cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRides();
  }

  Future<void> _fetchRides() async {
    setState(() => _isLoading = true);
    try {
      final res = await AdminApiService.instance.getRides(
        status: _selectedStatus,
        search: _searchQuery,
        page: _currentPage,
        limit: 15,
      );
      setState(() {
        _rides = res['rides'] ?? [];
        _totalPages = res['pagination']?['totalPages'] ?? 1;
        _totalRides = res['pagination']?['total'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load rides: $e'), backgroundColor: AdminTheme.errorRed),
        );
      }
    }
  }

  void _viewRideDetails(Map<String, dynamic> ride) {
    final rideId = ride['id'].toString();
    final status = ride['status'] ?? 'unknown';
    final rider = ride['rider_name'] ?? 'Customer #${ride['user_id']}';
    final driver = ride['driver_name'] ?? (ride['driver_id'] != null ? 'Driver #${ride['driver_id']}' : 'Unassigned');
    final pickup = ride['source_address'] ?? 'Source point';
    final destination = ride['destination_address'] ?? 'Destination point';
    final fare = ride['fare_amount'] ?? ride['estimated_fare'] ?? 0;
    final otp = ride['otp'] ?? '—';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AdminTheme.cardWhite,
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ride #$rideId', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Status: ${status.toString().toUpperCase()} • OTP: $otp', style: const TextStyle(color: AdminTheme.textSecondary)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AdminTheme.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 28),
              // Route
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.radio_button_checked, color: AdminTheme.successGreen, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PICKUP LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.textSecondary)),
                              Text(pickup, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 9.0),
                      child: SizedBox(height: 18, child: VerticalDivider(thickness: 2, color: AdminTheme.borderSubtle)),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: AdminTheme.errorRed, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DROP-OFF LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.textSecondary)),
                              Text(destination, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Rider & Driver Info
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AdminTheme.borderSubtle),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('RIDER / CUSTOMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(rider, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(ride['rider_phone'] ?? '—', style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AdminTheme.borderSubtle),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ASSIGNED DRIVER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(driver, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(ride['driver_phone'] ?? '—', style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Fare & Payment
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.primaryOrange.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL TRIP FARE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.textSecondary)),
                        Text('₹$fare', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdminTheme.primaryOrange)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('PAYMENT METHOD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.textSecondary)),
                        Text(
                          (ride['payment_method'] ?? 'CASH').toString().toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Admin Actions
              if (status != 'completed' && status != 'cancelled')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.errorRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.cancel_rounded, size: 18),
                    label: const Text('Admin Force Cancel Ride', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _cancelRidePrompt(rideId),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _cancelRidePrompt(String rideId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Force Cancel Ride #$rideId'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the cancellation reason for the audit trail:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'e.g. Passenger no-show, driver vehicle breakdown', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Dismiss')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.errorRed),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              final ok = await AdminApiService.instance.cancelRide(rideId, reasonController.text.trim());
              if (context.mounted) {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // pop details modal too
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ride cancelled by Super Admin.'), backgroundColor: AdminTheme.errorRed),
                  );
                  _fetchRides();
                }
              }
            },
            child: const Text('Confirm Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AdminTheme.successGreen;
      case 'in_progress':
      case 'started':
      case 'arrived':
        return AdminTheme.secondaryBlue;
      case 'requested':
      case 'accepted':
        return AdminTheme.accentAmber;
      case 'cancelled':
      default:
        return AdminTheme.errorRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rides & Booking Operations', style: AdminTheme.headingLarge),
                  const SizedBox(height: 4),
                  Text('Monitor, inspect, and manage all passenger trips ($_totalRides total)', style: AdminTheme.bodySecondary),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _fetchRides,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.cardWhite,
                  foregroundColor: AdminTheme.textPrimary,
                  side: const BorderSide(color: AdminTheme.borderSubtle),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Filter Tabs & Search
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  children: _statusTabs.map((tab) {
                    final isSelected = _selectedStatus == tab['value'];
                    return ChoiceChip(
                      label: Text(tab['label']!),
                      selected: isSelected,
                      selectedColor: AdminTheme.primaryOrange,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AdminTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      backgroundColor: AdminTheme.cardWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? AdminTheme.primaryOrange : AdminTheme.borderSubtle),
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedStatus = tab['value']!;
                            _currentPage = 1;
                          });
                          _fetchRides();
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by ride ID, rider...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AdminTheme.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminTheme.borderSubtle)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (v) {
                    setState(() {
                      _searchQuery = v.trim();
                      _currentPage = 1;
                    });
                    _fetchRides();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Table
          Expanded(
            child: Container(
              decoration: AdminTheme.elevatedCardDecoration,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AdminTheme.primaryOrange))
                  : _rides.isEmpty
                      ? const Center(child: Text('No rides match your filter criteria.'))
                      : Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('Ride ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Driver', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Fare', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Created At', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _rides.map((ride) {
                                      final status = (ride['status'] ?? 'unknown').toString();
                                      final badgeColor = _getStatusColor(status);
                                      return DataRow(cells: [
                                        DataCell(Text('#${ride['id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.secondaryBlue))),
                                        DataCell(Text(ride['rider_name'] ?? 'Rider #${ride['user_id']}')),
                                        DataCell(Text(ride['driver_name'] ?? (ride['driver_id'] != null ? 'Driver #${ride['driver_id']}' : 'Unassigned'))),
                                        DataCell(Text((ride['vehicle_category'] ?? 'Car').toString().toUpperCase())),
                                        DataCell(Text('₹${ride['fare_amount'] ?? ride['estimated_fare'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(ride['created_at'] != null ? ride['created_at'].toString().split('T')[0] : '—')),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.remove_red_eye_outlined, color: AdminTheme.primaryOrange, size: 20),
                                            tooltip: 'View Details',
                                            onPressed: () => _viewRideDetails(ride),
                                          ),
                                        ),
                                      ]);
                                    }).toList(),
                                  ),
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

