import 'package:flutter/material.dart';
import 'package:saffar_app/super_admin/core/admin_api_service.dart';
import 'package:saffar_app/super_admin/core/admin_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const AdminDashboardScreen({Key? key, this.onNavigate}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _summary;
  List<dynamic> _categoryBreakdown = [];
  List<dynamic> _recentDrivers = [];
  List<dynamic> _recentRides = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await AdminApiService.instance.getDashboardStats();
      setState(() {
        _summary = data['summary'];
        _categoryBreakdown = data['categoryBreakdown'] ?? [];
        _recentDrivers = data['recentDrivers'] ?? [];
        _recentRides = data['recentRides'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard metrics. Check server status.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AdminTheme.primaryOrange),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AdminTheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStats,
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primaryOrange),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final s = _summary ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Executive Dashboard',
                    style: TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time fleet operations, bookings & revenue insights across Maharashtra.',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AdminTheme.textPrimary,
                  elevation: 0,
                  side: const BorderSide(color: AdminTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Primary KPI Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 800
                      ? 2
                      : 1;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKpiCard(
                    title: 'Total Drivers',
                    value: '${s['totalDrivers'] ?? 0}',
                    subtitle: '${s['approvedDrivers'] ?? 0} Approved • ${s['pendingDrivers'] ?? 0} Pending',
                    icon: Icons.badge_outlined,
                    iconColor: AdminTheme.secondaryBlue,
                    onTap: () => widget.onNavigate?.call(1), // Drivers tab
                  ),
                  _buildKpiCard(
                    title: 'Online Drivers',
                    value: '${s['onlineDrivers'] ?? 0}',
                    subtitle: 'Ready for instant dispatch',
                    icon: Icons.sensors,
                    iconColor: AdminTheme.success,
                    badgeText: 'LIVE',
                    badgeColor: AdminTheme.successBg,
                    badgeTextColor: AdminTheme.success,
                    onTap: () => widget.onNavigate?.call(1), // Drivers tab
                  ),
                  _buildKpiCard(
                    title: 'Active Rides',
                    value: '${s['activeRides'] ?? 0}',
                    subtitle: '${s['completedRides'] ?? 0} Completed • ${s['cancelledRides'] ?? 0} Cancelled',
                    icon: Icons.navigation_outlined,
                    iconColor: AdminTheme.primaryOrange,
                    onTap: () => widget.onNavigate?.call(4), // Rides tab
                  ),
                  _buildKpiCard(
                    title: 'Total Gross Revenue',
                    value: '₹${s['totalRevenue'] ?? 0}',
                    subtitle: 'Today: ₹${s['todayRevenue'] ?? 0} • Commission: ₹${s['platformCommission'] ?? 0}',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    onTap: () => widget.onNavigate?.call(5), // Finance tab
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Secondary Quick Alert Banner (if pending documents)
          if ((s['pendingDocuments'] ?? 0) > 0)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AdminTheme.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminTheme.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions, color: AdminTheme.warning, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s['pendingDocuments']} Driver Document Verification(s) Awaiting Review',
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Drivers cannot accept passenger requests until required Driving License, RC, and Insurance documents are approved.',
                          style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => widget.onNavigate?.call(2), // Documents tab
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.warning,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('Review Documents'),
                  ),
                ],
              ),
            ),

          // Vehicle Category Distribution Row
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AdminTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehicle Category Distribution',
                  style: TextStyle(
                    color: AdminTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildCategoryBadge('🏍️ Bike', 'Bike', Colors.blue),
                    const SizedBox(width: 16),
                    _buildCategoryBadge('🛺 Auto', 'Auto', Colors.orange),
                    const SizedBox(width: 16),
                    _buildCategoryBadge('🚗 Car (Cab)', 'Car', Colors.green),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Two-column layout: Recent Drivers + Recent Rides
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recent Drivers
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AdminTheme.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Driver Registrations',
                            style: TextStyle(
                              color: AdminTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => widget.onNavigate?.call(1),
                            child: const Text('View All Drivers →', style: TextStyle(color: AdminTheme.primaryOrange)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_recentDrivers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No drivers registered yet.', style: TextStyle(color: AdminTheme.textSecondary))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentDrivers.length,
                          separatorBuilder: (_, __) => const Divider(color: AdminTheme.border, height: 16),
                          itemBuilder: (context, i) {
                            final d = _recentDrivers[i];
                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AdminTheme.secondaryBlue.withOpacity(0.1),
                                  child: Text(
                                    (d['name'] ?? 'D')[0].toUpperCase(),
                                    style: const TextStyle(color: AdminTheme.secondaryBlue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['name'] ?? 'Driver',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      Text(
                                        '${d['phone']} • ${d['category'] ?? 'Auto'} (${d['vehicle_number'] ?? ''})',
                                        style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusBadge(d['verification_status'] ?? 'pending'),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Recent Rides
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AdminTheme.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Platform Bookings',
                            style: TextStyle(
                              color: AdminTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => widget.onNavigate?.call(4),
                            child: const Text('View All Rides →', style: TextStyle(color: AdminTheme.primaryOrange)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_recentRides.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No bookings recorded yet.', style: TextStyle(color: AdminTheme.textSecondary))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentRides.length,
                          separatorBuilder: (_, __) => const Divider(color: AdminTheme.border, height: 16),
                          itemBuilder: (context, i) {
                            final r = _recentRides[i];
                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.local_taxi, color: AdminTheme.secondaryBlue, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${r['pickup_place'] ?? 'Pickup'} → ${r['drop_place'] ?? 'Destination'}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Customer: ${r['customer_name'] ?? 'Guest'} • Driver: ${r['driver_name'] ?? 'Assigning...'}',
                                        style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${r['price'] ?? 0}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.textPrimary),
                                    ),
                                    _buildRideStatusBadge(r['status'] ?? 'pending'),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
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

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AdminTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(badgeText, style: TextStyle(color: badgeTextColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else
                  Icon(icon, color: iconColor, size: 20),
              ],
            ),
            Text(value, style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String label, String categoryKey, Color color) {
    final catData = _categoryBreakdown.firstWhere(
      (c) => (c['category'] ?? '').toString().toLowerCase() == categoryKey.toLowerCase(),
      orElse: () => {'ride_count': 0, 'revenue': 0},
    );

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text('${catData['ride_count'] ?? 0} Total Trips', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text('₹${catData['revenue'] ?? 0} Volume', style: const TextStyle(fontSize: 11, color: AdminTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = AdminTheme.warningBg;
    Color text = AdminTheme.warning;
    if (status == 'approved') {
      bg = AdminTheme.successBg;
      text = AdminTheme.success;
    } else if (status == 'rejected') {
      bg = AdminTheme.errorBg;
      text = AdminTheme.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRideStatusBadge(String status) {
    Color text = AdminTheme.textSecondary;
    if (status == 'completed') text = AdminTheme.success;
    if (status == 'cancelled') text = AdminTheme.error;
    if (status == 'ongoing' || status == 'trip_started') text = AdminTheme.primaryOrange;
    return Text(status.toUpperCase(), style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold));
  }
}

