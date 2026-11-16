import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:saffar_app/super_admin/core/admin_api_service.dart';
import 'package:saffar_app/super_admin/core/admin_theme.dart';

class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({Key? key}) : super(key: key);

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  final List<String> _tabs = [
    'all',
    'pending',
    'approved',
    'online',
    'offline',
    'on_trip',
    'suspended',
    'rejected',
  ];

  final List<String> _tabLabels = [
    'All Drivers',
    'Pending Approval',
    'Approved',
    'Online (Live)',
    'Offline',
    'On Trip',
    'Suspended',
    'Rejected',
  ];

  String _selectedCategory = 'All';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalDrivers = 0;
  bool _isLoading = true;
  List<dynamic> _drivers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _currentPage = 1;
        _fetchDrivers();
      }
    });
    _fetchDrivers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDrivers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentTab = _tabs[_tabController.index];
      final res = await AdminApiService.instance.getDrivers(
        status: currentTab,
        category: _selectedCategory,
        search: _searchController.text.trim(),
        page: _currentPage,
        limit: 12,
      );

      setState(() {
        _drivers = res['drivers'] ?? [];
        final pagination = res['pagination'] ?? {};
        _totalDrivers = pagination['total'] ?? 0;
        _totalPages = pagination['totalPages'] ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load driver records: $e';
        _isLoading = false;
      });
    }
  }

  void _openDriverDetails(String driverId) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _DriverDetailsDialog(
        driverId: driverId,
        onStatusUpdated: _fetchDrivers,
        onDeleteRequested: (id, name) => _confirmDeleteSingleDriver(id, name),
      ),
    );
  }

  void _confirmDeleteAllDrivers() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AdminTheme.errorRed),
            SizedBox(width: 8),
            Text('Delete All Drivers?'),
          ],
        ),
        content: const Text(
          'This action will permanently delete ALL drivers, vehicles, and related driver documents from the PostgreSQL database.\n\nAre you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              final ok = await AdminApiService.instance.deleteAllDrivers();
              if (mounted) {
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All drivers permanently deleted.'),
                      backgroundColor: AdminTheme.errorRed,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete drivers.'),
                      backgroundColor: AdminTheme.errorRed,
                    ),
                  );
                }
                _fetchDrivers();
              }
            },
            child: const Text('Yes, Delete All Drivers'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSingleDriver(String driverId, String driverName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Driver $driverName?'),
        content: Text('Are you sure you want to permanently delete driver #$driverId and all associated vehicles and documents?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.errorRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await AdminApiService.instance.deleteDriver(driverId);
              if (mounted) {
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Driver $driverName permanently deleted.'), backgroundColor: AdminTheme.errorRed),
                  );
                  _fetchDrivers();
                }
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Stats summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver & Fleet Management',
                    style: TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete operational control, compliance verification & account management for all drivers.',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _confirmDeleteAllDrivers,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('Purge All Drivers', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.errorRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _fetchDrivers,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AdminTheme.textPrimary,
                      side: const BorderSide(color: AdminTheme.border),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search & Filter Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AdminTheme.cardDecoration,
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) {
                      _currentPage = 1;
                      _fetchDrivers();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by driver name, phone, email, or vehicle registration number...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AdminTheme.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _fetchDrivers();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Category Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      items: ['All', 'Bike', 'Auto', 'Car', 'Prime Sedan']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? 'All Vehicle Types' : c, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                          _currentPage = 1;
                          _fetchDrivers();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    _currentPage = 1;
                    _fetchDrivers();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminTheme.border),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AdminTheme.primaryOrange,
              unselectedLabelColor: AdminTheme.textSecondary,
              indicatorColor: AdminTheme.primaryOrange,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: _tabLabels.map((lbl) => Tab(text: lbl)).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Drivers Table
          Expanded(
            child: Container(
              decoration: AdminTheme.cardDecoration,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AdminTheme.primaryOrange))
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!, style: const TextStyle(color: AdminTheme.error)))
                      : _drivers.isEmpty
                          ? const Center(
                              child: Text(
                                'No drivers found matching current filters.',
                                style: TextStyle(color: AdminTheme.textSecondary, fontSize: 14),
                              ),
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: MaterialStateProperty.all(AdminTheme.background),
                                        columnSpacing: 24,
                                        dataRowMinHeight: 52,
                                        dataRowMaxHeight: 64,
                                        columns: const [
                                          DataColumn(label: Text('Driver', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Presence', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Rating', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Trips', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                        rows: _drivers.map((d) {
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 18,
                                                      backgroundColor: AdminTheme.secondaryBlue.withOpacity(0.1),
                                                      child: Text(
                                                        (d['name'] ?? 'D')[0].toUpperCase(),
                                                        style: const TextStyle(
                                                          color: AdminTheme.secondaryBlue,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(d['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                        Text('ID: ${d['id']}', style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(d['phone'] ?? '-', style: const TextStyle(fontSize: 13)),
                                                    if (d['email'] != null)
                                                      Text(d['email'], style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11)),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(d['vehicle_number'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                    Text(d['vehicle_name'] ?? '', style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 11)),
                                                  ],
                                                ),
                                              ),
                                              DataCell(_buildCategoryPill(d['category'] ?? 'Auto')),
                                              DataCell(_buildVerificationPill(d['verification_status'] ?? 'pending', d['active'] == true)),
                                              DataCell(_buildPresencePill(d['is_online'] == true)),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      d['rating'] != null ? double.parse(d['rating'].toString()).toStringAsFixed(1) : '5.0',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(Text('${d['completed_rides'] ?? 0} rides', style: const TextStyle(fontSize: 12))),
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    ElevatedButton(
                                                      onPressed: () => _openDriverDetails(d['id']),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: AdminTheme.secondaryBlue,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        elevation: 0,
                                                      ),
                                                      child: const Text('View Profile', style: TextStyle(fontSize: 12)),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline_rounded, color: AdminTheme.errorRed, size: 18),
                                                      tooltip: 'Delete Driver',
                                                      onPressed: () => _confirmDeleteSingleDriver(d['id'].toString(), d['name'] ?? 'Driver'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),

                                // Pagination Footer
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: const BoxDecoration(
                                    border: Border(top: BorderSide(color: AdminTheme.border)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Showing $_drivers.length of $_totalDrivers total drivers',
                                        style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chevron_left, size: 20),
                                            onPressed: _currentPage > 1
                                                ? () {
                                                    setState(() => _currentPage--);
                                                    _fetchDrivers();
                                                  }
                                                : null,
                                          ),
                                          Text('Page $_currentPage of $_totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.chevron_right, size: 20),
                                            onPressed: _currentPage < _totalPages
                                                ? () {
                                                    setState(() => _currentPage++);
                                                    _fetchDrivers();
                                                  }
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ],
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

  Widget _buildCategoryPill(String category) {
    Color color = Colors.orange;
    if (category == 'Bike') color = Colors.blue;
    if (category == 'Car' || category == 'Prime Sedan') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(category, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildVerificationPill(String status, bool active) {
    if (!active) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AdminTheme.errorBg, borderRadius: BorderRadius.circular(6)),
        child: const Text('SUSPENDED', style: TextStyle(color: AdminTheme.error, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
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

  Widget _buildPresencePill(bool isOnline) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOnline ? AdminTheme.success : AdminTheme.textMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isOnline ? 'ONLINE' : 'OFFLINE',
          style: TextStyle(
            color: isOnline ? AdminTheme.success : AdminTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// DRIVER DETAILS COMPREHENSIVE DIALOG
// ---------------------------------------------------------------------------

class _DriverDetailsDialog extends StatefulWidget {
  final String driverId;
  final VoidCallback onStatusUpdated;
  final void Function(String id, String name)? onDeleteRequested;

  const _DriverDetailsDialog({
    Key? key,
    required this.driverId,
    required this.onStatusUpdated,
    this.onDeleteRequested,
  }) : super(key: key);

  @override
  State<_DriverDetailsDialog> createState() => _DriverDetailsDialogState();
}

class _DriverDetailsDialogState extends State<_DriverDetailsDialog> with SingleTickerProviderStateMixin {
  late TabController _dialogTabController;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _driverData;

  @override
  void initState() {
    super.initState();
    _dialogTabController = TabController(length: 4, vsync: this);
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await AdminApiService.instance.getDriverDetails(widget.driverId);
      setState(() {
        _driverData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load driver profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String action) async {
    String? reason;
    if (action == 'reject' || action == 'suspend') {
      final reasonController = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${action == 'reject' ? 'Reject' : 'Suspend'} Driver Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Please specify a mandatory reason for ${action}ing this driver:'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g., Expired vehicle insurance document / repeated customer complaint...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.error),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
      reason = reasonController.text.trim();
    }

    try {
      final success = await AdminApiService.instance.updateDriverStatus(widget.driverId, action, reason: reason);
      if (success) {
        widget.onStatusUpdated();
        _loadDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Driver status updated to $action successfully.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AdminTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 860,
        height: 680,
        padding: const EdgeInsets.all(28),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AdminTheme.primaryOrange))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AdminTheme.error)))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final d = _driverData?['driver'] ?? {};
    final v = _driverData?['vehicle'] ?? {};
    final docs = List<dynamic>.from(_driverData?['documents'] ?? []);
    final fin = _driverData?['financialSummary'] ?? {};
    final isSuspended = d['active'] == false;
    final isApproved = d['verification_status'] == 'approved' && !isSuspended;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AdminTheme.secondaryBlue,
                  child: Text(
                    (d['name'] ?? 'D')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(d['name'] ?? 'Driver Name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isApproved ? AdminTheme.successBg : isSuspended ? AdminTheme.errorBg : AdminTheme.warningBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isSuspended ? 'SUSPENDED' : (d['verification_status'] ?? 'pending').toString().toUpperCase(),
                            style: TextStyle(
                              color: isApproved ? AdminTheme.success : isSuspended ? AdminTheme.error : AdminTheme.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Driver ID: ${d['id']} • Registered: ${d['created_at']?.toString().split('T')[0] ?? 'N/A'}',
                        style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Action Buttons Row
        Row(
          children: [
            if (!isApproved)
              ElevatedButton.icon(
                onPressed: () => _updateStatus('approve'),
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Approve Driver'),
                style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.success, foregroundColor: Colors.white, elevation: 0),
              ),
            const SizedBox(width: 10),
            if (!isSuspended)
              OutlinedButton.icon(
                onPressed: () => _updateStatus('suspend'),
                icon: const Icon(Icons.block, size: 16),
                label: const Text('Suspend Account'),
                style: OutlinedButton.styleFrom(foregroundColor: AdminTheme.error, side: const BorderSide(color: AdminTheme.error)),
              )
            else
              ElevatedButton.icon(
                onPressed: () => _updateStatus('activate'),
                icon: const Icon(Icons.lock_open, size: 16),
                label: const Text('Activate Account'),
                style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.success, foregroundColor: Colors.white, elevation: 0),
              ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _updateStatus('reject'),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Reject Verification'),
              style: OutlinedButton.styleFrom(foregroundColor: AdminTheme.warning, side: const BorderSide(color: AdminTheme.warning)),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onDeleteRequested?.call(d['id'].toString(), d['name'] ?? 'Driver');
              },
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: const Text('Delete Driver'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminTheme.errorRed,
                side: const BorderSide(color: AdminTheme.errorRed),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tabs
        TabBar(
          controller: _dialogTabController,
          labelColor: AdminTheme.primaryOrange,
          unselectedLabelColor: AdminTheme.textSecondary,
          indicatorColor: AdminTheme.primaryOrange,
          tabs: const [
            Tab(text: 'Personal Information'),
            Tab(text: 'Vehicle Details'),
            Tab(text: 'Documents & Verification'),
            Tab(text: 'Financials & Performance'),
          ],
        ),
        const SizedBox(height: 16),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _dialogTabController,
            children: [
              // 1. Personal Info
              ListView(
                children: [
                  _infoRow('Full Name', d['name'] ?? '-'),
                  _infoRow('Mobile Number', d['phone'] ?? '-'),
                  _infoRow('Email Address', d['email'] ?? 'Not provided'),
                  _infoRow('Permanent Address', d['address'] ?? 'Maharashtra, India'),
                  _infoRow('Account Status', isSuspended ? 'Suspended' : 'Active'),
                  _infoRow('Live Presence', d['is_online'] == true ? 'Online (Ready for Rides)' : 'Offline'),
                  _infoRow('Driver Rating', '${d['avg_rating'] ?? 5.0} / 5.0 ⭐'),
                ],
              ),

              // 2. Vehicle Details
              ListView(
                children: [
                  _infoRow('Category', v['category'] ?? d['vehicle_name'] ?? 'Auto'),
                  _infoRow('Vehicle Model', v['model'] ?? d['vehicle_name'] ?? '-'),
                  _infoRow('Registration Number', v['registration_number'] ?? d['vehicle_number'] ?? '-'),
                  _infoRow('Vehicle Color', v['color'] ?? 'Yellow & Black'),
                  _infoRow('Active in Dispatch', v['is_active'] == true ? 'Yes' : 'No'),
                  _infoRow('Compliance Status', (v['verification_status'] ?? 'pending').toString().toUpperCase()),
                ],
              ),

              // 3. Documents
              docs.isEmpty
                  ? const Center(child: Text('No uploaded documents found for this driver.', style: TextStyle(color: AdminTheme.textSecondary)))
                  : ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 20),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AdminTheme.background, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.description, color: AdminTheme.secondaryBlue),
                          ),
                          title: Text(doc['document_type'].toString().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Number: ${doc['document_number'] ?? 'N/A'} • Status: ${doc['verification_status']}'),
                              if (doc['document_url'] != null && doc['document_url'].toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => Dialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    doc['document_type'].toString().replaceAll('_', ' ').toUpperCase(),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.close),
                                                    onPressed: () => Navigator.pop(ctx),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              doc['document_url'].toString().startsWith('data:image')
                                                  ? Image.memory(
                                                      base64Decode(doc['document_url'].toString().split(',').last),
                                                      fit: BoxFit.contain,
                                                      height: 320,
                                                    )
                                                  : Image.network(
                                                      doc['document_url'].toString(),
                                                      fit: BoxFit.contain,
                                                      height: 320,
                                                      errorBuilder: (_, __, ___) => const Text('Document uploaded (preview not available)'),
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('View Document Photo 🔍',
                                      style: TextStyle(color: AdminTheme.secondaryBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: doc['verification_status'] == 'approved' ? AdminTheme.successBg : AdminTheme.warningBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              doc['verification_status'].toString().toUpperCase(),
                              style: TextStyle(
                                color: doc['verification_status'] == 'approved' ? AdminTheme.success : AdminTheme.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

              // 4. Financials & Performance
              ListView(
                children: [
                  _infoRow('Completed Rides', '${d['total_rides_count'] ?? 0}'),
                  _infoRow('Cancelled Rides', '${d['cancelled_rides_count'] ?? 0}'),
                  _infoRow('Total Gross Fare', '₹${fin['grossEarnings'] ?? 0}'),
                  _infoRow('Platform Commission (15%)', '₹${fin['platformCommission'] ?? 0}'),
                  _infoRow('Driver Net Payout', '₹${fin['netEarnings'] ?? 0}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(label, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AdminTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

