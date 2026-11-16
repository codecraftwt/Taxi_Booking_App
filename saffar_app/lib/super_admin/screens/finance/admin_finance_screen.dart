import 'package:flutter/material.dart';
import '../../core/admin_theme.dart';
import '../../core/admin_api_service.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({Key? key}) : super(key: key);

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _overview = {};
  List<dynamic> _settlements = [];

  @override
  void initState() {
    super.initState();
    _fetchFinanceData();
  }

  Future<void> _fetchFinanceData() async {
    setState(() => _isLoading = true);
    try {
      final overviewRes = await AdminApiService.instance.getFinanceOverview();
      final settlementsRes = await AdminApiService.instance.getSettlements();
      setState(() {
        _overview = overviewRes;
        _settlements = settlementsRes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load financial records: $e'), backgroundColor: AdminTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grossVolume = _overview['grossRevenue'] ?? _overview['totalVolume'] ?? 0;
    final commissionRevenue = _overview['commissionRevenue'] ?? _overview['netPlatformCommission'] ?? 0;
    final driverPayouts = _overview['driverPayouts'] ?? _overview['totalDriverPayouts'] ?? 0;
    final pendingSettlements = _overview['pendingSettlementsCount'] ?? 0;

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
                  const Text('Finance & Settlements Ledger', style: AdminTheme.headingLarge),
                  const SizedBox(height: 4),
                  const Text('Platform gross volume, 20% platform commission, and driver settlement ledger', style: AdminTheme.bodySecondary),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _fetchFinanceData,
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
          const SizedBox(height: 24),
          // Finance KPI cards
          Row(
            children: [
              Expanded(child: _buildFinanceCard('Gross Booking Volume', '₹$grossVolume', Icons.account_balance_wallet_rounded, AdminTheme.secondaryBlue)),
              const SizedBox(width: 18),
              Expanded(child: _buildFinanceCard('Saffar Commission (Take-Rate)', '₹$commissionRevenue', Icons.monetization_on_rounded, AdminTheme.primaryOrange)),
              const SizedBox(width: 18),
              Expanded(child: _buildFinanceCard('Total Driver Payouts', '₹$driverPayouts', Icons.payments_rounded, AdminTheme.successGreen)),
              const SizedBox(width: 18),
              Expanded(child: _buildFinanceCard('Pending Settlements', '$pendingSettlements Drivers', Icons.pending_actions_rounded, AdminTheme.accentAmber)),
            ],
          ),
          const SizedBox(height: 28),
          // Settlements Table
          Expanded(
            child: Container(
              decoration: AdminTheme.elevatedCardDecoration,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AdminTheme.primaryOrange))
                  : _settlements.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 48, color: AdminTheme.successGreen),
                              SizedBox(height: 12),
                              Text('All driver balances are currently settled.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text('Driver Settlement Records', style: AdminTheme.headingSmall),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('Driver Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Driver Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Gross Earnings', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Platform Cut', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Net Payable', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _settlements.map((s) {
                                      final isSettled = s['status'] == 'completed';
                                      return DataRow(cells: [
                                        DataCell(Text(s['driver_name'] ?? 'Driver #${s['driver_id']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataCell(Text(s['driver_phone'] ?? '—')),
                                        DataCell(Text('₹${s['gross_amount'] ?? 0}')),
                                        DataCell(Text('₹${s['commission_deducted'] ?? 0}', style: const TextStyle(color: AdminTheme.primaryOrange))),
                                        DataCell(Text('₹${s['net_payable'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.successGreen))),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (isSettled ? AdminTheme.successGreen : AdminTheme.accentAmber).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              (s['status'] ?? 'pending').toString().toUpperCase(),
                                              style: TextStyle(
                                                color: isSettled ? AdminTheme.successGreen : AdminTheme.accentAmber,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          isSettled
                                              ? const Icon(Icons.check, color: AdminTheme.successGreen, size: 20)
                                              : ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AdminTheme.successGreen,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  onPressed: () {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Settlement payment initiated.'), backgroundColor: AdminTheme.successGreen),
                                                    );
                                                  },
                                                  child: const Text('Disburse', style: TextStyle(fontSize: 12)),
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

  Widget _buildFinanceCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AdminTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

