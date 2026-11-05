import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_cubit.dart';
import 'package:saffar_app/features/driver/presenter/cubits/driver_earnings_cubit.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_trip_earning_details_screen.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({Key? key}) : super(key: key);

  static const String routeName = '/driver_earnings';

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  String _selectedPeriod = 'today';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchEarnings();
  }

  void _fetchEarnings() {
    final token = context.read<DriverCubit>().state.token;
    if (token != null) {
      String? fromDateStr;
      String? toDateStr;
      if (_selectedPeriod == 'custom' && _selectedDateRange != null) {
        fromDateStr = _selectedDateRange!.start.toIso8601String().split('T')[0];
        toDateStr = _selectedDateRange!.end.toIso8601String().split('T')[0];
      }

      context.read<DriverEarningsCubit>().fetchEarningsSummary(
            token,
            period: _selectedPeriod,
            fromDate: fromDateStr,
            toDate: toDateStr,
          );
    }
  }

  Future<void> _pickCustomDateRange() async {
    final initialRange = _selectedDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Palette.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Palette.neutral,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _selectedPeriod = 'custom';
      });
      _fetchEarnings();
    }
  }

  String _formatDate(dynamic dateRaw) {
    if (dateRaw == null) return '';
    try {
      final dt = DateTime.parse(dateRaw.toString()).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]}, $hour:$min $ampm';
    } catch (_) {
      return dateRaw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Driver Earnings',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded, color: Palette.primary),
            tooltip: 'Custom Date Range',
            onPressed: _pickCustomDateRange,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _fetchEarnings(),
          color: Palette.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: Nums.horizontalPadding,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. High-Level 4 Metrics Grid (Today, Week, Month, Total)
                _buildOverviewCards(),

                const SizedBox(height: 18),

                // 2. Interactive Filter Selector
                _buildFilterSelector(),

                if (_selectedPeriod == 'custom' && _selectedDateRange != null) ...[
                  const SizedBox(height: 10),
                  _buildCustomDateBadge(),
                ],

                const SizedBox(height: 18),

                // 3. Active Period Summary Banner
                _buildPeriodSummaryBanner(),

                const SizedBox(height: 24),

                // 4. Trip Earnings History Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Trip Earnings History',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    BlocBuilder<DriverEarningsCubit, DriverEarningsState>(
                      builder: (context, state) {
                        return Text(
                          '${state.earningsHistory.length} completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 5. Trip Earnings List
                _buildEarningsList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return BlocBuilder<DriverEarningsCubit, DriverEarningsState>(
      builder: (context, state) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _overviewItem(
                    label: "Today's Earnings",
                    amount: state.todayEarnings,
                    trips: state.todayRides,
                    icon: Icons.today_rounded,
                    accentColor: const Color(0xFF2563EB),
                    isActive: _selectedPeriod == 'today',
                    onTap: () {
                      setState(() => _selectedPeriod = 'today');
                      _fetchEarnings();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _overviewItem(
                    label: 'This Week',
                    amount: state.weeklyEarnings,
                    trips: state.weeklyRides,
                    icon: Icons.date_range_rounded,
                    accentColor: const Color(0xFF7C3AED),
                    isActive: _selectedPeriod == 'this_week',
                    onTap: () {
                      setState(() => _selectedPeriod = 'this_week');
                      _fetchEarnings();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _overviewItem(
                    label: 'This Month',
                    amount: state.monthlyEarnings,
                    trips: state.monthlyRides,
                    icon: Icons.calendar_month_rounded,
                    accentColor: const Color(0xFF0D9488),
                    isActive: _selectedPeriod == 'this_month',
                    onTap: () {
                      setState(() => _selectedPeriod = 'this_month');
                      _fetchEarnings();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _overviewItem(
                    label: 'Total Net Earnings',
                    amount: state.allTimeEarnings,
                    trips: state.totalCompletedRides,
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: const Color(0xFF16A34A),
                    isActive: _selectedPeriod == 'all',
                    onTap: () {
                      setState(() => _selectedPeriod = 'all');
                      _fetchEarnings();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _overviewItem({
    required String label,
    required double amount,
    required int trips,
    required IconData icon,
    required Color accentColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? accentColor : Colors.grey.shade200,
            width: isActive ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                Text(
                  '$trips trips',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isActive ? accentColor : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _filterTab('Today', 'today'),
          _filterTab('This Week', 'this_week'),
          _filterTab('This Month', 'this_month'),
          _filterTab('Custom', 'custom', isCustom: true),
        ],
      ),
    );
  }

  Widget _filterTab(String label, String periodKey, {bool isCustom = false}) {
    final isSelected = _selectedPeriod == periodKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isCustom) {
            _pickCustomDateRange();
          } else {
            setState(() {
              _selectedPeriod = periodKey;
              _selectedDateRange = null;
            });
            _fetchEarnings();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCustom) ...[
                Icon(
                  Icons.calendar_month_outlined,
                  size: 13,
                  color: isSelected ? Palette.primary : Colors.grey.shade700,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Palette.primary : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateBadge() {
    final startStr = _selectedDateRange!.start.toIso8601String().split('T')[0];
    final endStr = _selectedDateRange!.end.toIso8601String().split('T')[0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 16, color: Palette.primary),
              const SizedBox(width: 8),
              Text(
                'Custom Range: $startStr to $endStr',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Palette.primary,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () {
              setState(() {
                _selectedPeriod = 'today';
                _selectedDateRange = null;
              });
              _fetchEarnings();
            },
            child: const Icon(Icons.close_rounded, size: 16, color: Palette.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSummaryBanner() {
    return BlocBuilder<DriverEarningsCubit, DriverEarningsState>(
      builder: (context, state) {
        String periodTitle;
        if (_selectedPeriod == 'today') {
          periodTitle = "TODAY'S NET EARNINGS";
        } else if (_selectedPeriod == 'this_week') {
          periodTitle = "THIS WEEK'S NET EARNINGS";
        } else if (_selectedPeriod == 'this_month') {
          periodTitle = "THIS MONTH'S NET EARNINGS";
        } else if (_selectedPeriod == 'custom') {
          periodTitle = "CUSTOM RANGE NET EARNINGS";
        } else {
          periodTitle = "TOTAL NET EARNINGS";
        }

        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                periodTitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹${state.netEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${state.completedRides} Rides Completed',
                      style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statItem('Gross Fare', '₹${state.grossEarnings.toStringAsFixed(2)}'),
                  _statItem(
                    'Platform Fee (15%)',
                    '- ₹${state.platformCommission.toStringAsFixed(2)}',
                    textColor: const Color(0xFFFBBF24),
                  ),
                  _statItem('Net Take-Home', '₹${state.netEarnings.toStringAsFixed(2)}', textColor: const Color(0xFF4ADE80)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String title, String value, {Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsList() {
    return BlocBuilder<DriverEarningsCubit, DriverEarningsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Palette.primary),
            ),
          );
        }

        if (state.error != null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Palette.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              state.error!,
              style: const TextStyle(color: Palette.error, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          );
        }

        if (state.earningsHistory.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'No completed rides in this period',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Palette.neutral),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completed trips with earnings will appear here.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.earningsHistory.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ride = Map<String, dynamic>.from(state.earningsHistory[index] as Map);
            final source = ride['source_address'] is Map ? Map<String, dynamic>.from(ride['source_address'] as Map) : null;
            final dest = ride['destination_address'] is Map ? Map<String, dynamic>.from(ride['destination_address'] as Map) : null;
            final passenger = ride['passenger'] is Map ? Map<String, dynamic>.from(ride['passenger'] as Map) : null;

            final rideId = ride['id']?.toString() ?? '';
            final bookingId = ride['booking_id']?.toString() ?? rideId;
            final gross = (ride['gross_fare'] as num?)?.toDouble() ?? 0.0;
            final net = (ride['net_earnings'] as num?)?.toDouble() ?? 0.0;
            final commission = (ride['platform_commission'] as num?)?.toDouble() ?? 0.0;
            final dateStr = _formatDate(ride['end_time'] ?? ride['start_time']);
            final paymentStatus = ride['payment_status']?.toString() ?? 'Paid';
            final paymentMethod = ride['payment_method']?.toString() ?? 'Paid via UPI';

            final pickupText = [source?['street'], source?['place']].filterEmpty();
            final destText = [dest?['street'], dest?['place']].filterEmpty();

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriverTripEarningDetailsScreen(
                      rideId: rideId,
                      bookingId: bookingId,
                      tripDate: dateStr,
                      grossFare: gross,
                      platformCommission: commission,
                      commissionRate: (ride['commission_rate'] as num?)?.toDouble() ?? 0.15,
                      netEarnings: net,
                      otherDeductions: (ride['other_deductions'] as num?)?.toDouble() ?? 0.0,
                      distanceKm: (ride['distance_km'] as num?)?.toDouble() ?? 0.0,
                      durationMinutes: (ride['duration_minutes'] as num?)?.toInt() ?? 0,
                      paymentStatus: paymentStatus,
                      paymentMethod: paymentMethod,
                      pickupAddress: pickupText.isNotEmpty ? pickupText : 'Pickup Spot',
                      destinationAddress: destText.isNotEmpty ? destText : 'Destination Spot',
                      passengerName: passenger?['name']?.toString() ?? 'Passenger',
                      vehicleType: ride['vehicle_type']?.toString() ?? 'Saffar Auto',
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Booking ID, Date, and Net Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF16A34A), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#$bookingId',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                                Text(
                                  dateStr,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+₹${net.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            Text(
                              'Gross: ₹${gross.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // Route Summary
                    Row(
                      children: [
                        const Icon(Icons.trip_origin_rounded, size: 14, color: Color(0xFF219653)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pickupText.isNotEmpty ? pickupText : 'Pickup Spot',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Palette.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            destText.isNotEmpty ? destText : 'Destination Spot',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Footer: Commission note & View details chevron
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Platform Fee: ₹${commission.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blueGrey),
                          ),
                        ),
                        const Row(
                          children: [
                            Text(
                              'Receipt',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Palette.primary),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 18, color: Palette.primary),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

extension _StringListExt on List<dynamic> {
  String filterEmpty() {
    return where((e) => e != null && e.toString().trim().isNotEmpty).map((e) => e.toString()).join(', ');
  }
}
