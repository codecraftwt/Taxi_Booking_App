import 'package:flutter/material.dart';
import '../../core/admin_theme.dart';
import '../../core/admin_api_service.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({Key? key}) : super(key: key);

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCustomers = 0;
  List<dynamic> _customers = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final res = await AdminApiService.instance.getCustomers(
        search: _searchQuery,
        page: _currentPage,
        limit: 15,
      );
      setState(() {
        _customers = res['customers'] ?? [];
        _totalPages = res['pagination']?['totalPages'] ?? 1;
        _totalCustomers = res['pagination']?['total'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load customers: $e'), backgroundColor: AdminTheme.errorRed),
        );
      }
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
                  const Text('Customer Directory', style: AdminTheme.headingLarge),
                  const SizedBox(height: 4),
                  Text('All registered passenger accounts ($_totalCustomers total)', style: AdminTheme.bodySecondary),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _fetchCustomers,
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
          // Search box
          SizedBox(
            width: 340,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by customer name or phone...',
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
                _fetchCustomers();
              },
            ),
          ),
          const SizedBox(height: 20),
          // Table
          Expanded(
            child: Container(
              decoration: AdminTheme.elevatedCardDecoration,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AdminTheme.primaryOrange))
                  : _customers.isEmpty
                      ? const Center(child: Text('No customers found.'))
                      : Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Rides Taken', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Total Spend', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Registered On', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _customers.map((c) {
                                      final name = '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();
                                      final displayName = name.isNotEmpty ? name : 'User #${c['id']}';
                                      return DataRow(cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: AdminTheme.primaryOrange.withOpacity(0.12),
                                                child: Text(
                                                  displayName[0].toUpperCase(),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.primaryOrange),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(c['phone'] ?? '—')),
                                        DataCell(Text(c['email'] ?? '—')),
                                        DataCell(Text('${c['total_rides'] ?? 0}')),
                                        DataCell(Text('₹${c['total_spent'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(c['created_at'] != null ? c['created_at'].toString().split('T')[0] : '—')),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AdminTheme.successGreen.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Text('ACTIVE', style: TextStyle(color: AdminTheme.successGreen, fontWeight: FontWeight.bold, fontSize: 11)),
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

