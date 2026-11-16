import 'package:flutter/material.dart';
import '../../core/admin_theme.dart';
import '../../core/admin_api_service.dart';

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({Key? key}) : super(key: key);

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _logs = [];
  List<dynamic> _staff = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final logsRes = await AdminApiService.instance.getAuditLogs(limit: 50);
      final staffRes = await AdminApiService.instance.getStaff();
      setState(() {
        _logs = logsRes;
        _staff = staffRes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load audit data: $e'), backgroundColor: AdminTheme.errorRed),
        );
      }
    }
  }

  void _showAddStaffDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'operations_manager';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Administrator / Staff', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Administrative Role', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'super_admin', child: Text('Super Admin (Full Access)')),
                    DropdownMenuItem(value: 'operations_manager', child: Text('Operations Manager (Drivers & Rides)')),
                    DropdownMenuItem(value: 'support_lead', child: Text('Support Lead (Read & Verify)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedRole = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primaryOrange),
              onPressed: () async {
                if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                final ok = await AdminApiService.instance.createStaff({
                  'name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'password': passCtrl.text.trim(),
                  'role': selectedRole,
                });
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Staff member created successfully.'), backgroundColor: AdminTheme.successGreen),
                    );
                    _fetchData();
                  }
                }
              },
              child: const Text('Create Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
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
                  const Text('System Audit & Staff Access', style: AdminTheme.headingLarge),
                  const SizedBox(height: 4),
                  const Text('Immutable security audit trails and administrative personnel management', style: AdminTheme.bodySecondary),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _showAddStaffDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('New Staff', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _fetchData,
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
            ],
          ),
          const SizedBox(height: 20),
          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AdminTheme.primaryOrange,
            unselectedLabelColor: AdminTheme.textSecondary,
            indicatorColor: AdminTheme.primaryOrange,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Security Audit Logs'),
              Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'Administrative Staff'),
            ],
          ),
          const SizedBox(height: 20),
          // Tab views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AdminTheme.primaryOrange))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Audit Logs Table
                      Container(
                        decoration: AdminTheme.elevatedCardDecoration,
                        child: _logs.isEmpty
                            ? const Center(child: Text('No audit events recorded yet.'))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Admin Actor', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Action Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Entity', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Target ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('IP Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _logs.map((log) {
                                      return DataRow(cells: [
                                        DataCell(Text(log['created_at'] != null ? log['created_at'].toString().replaceFirst('T', ' ').substring(0, 19) : '—')),
                                        DataCell(Text(log['admin_name'] ?? 'Admin #${log['admin_id']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AdminTheme.secondaryBlue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text((log['action'] ?? 'ACTION').toString().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.secondaryBlue)),
                                          ),
                                        ),
                                        DataCell(Text((log['entity_type'] ?? '—').toString())),
                                        DataCell(Text(log['entity_id']?.toString() ?? '—')),
                                        DataCell(Text(log['ip_address'] ?? '127.0.0.1')),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ),
                      ),
                      // Staff Table
                      Container(
                        decoration: AdminTheme.elevatedCardDecoration,
                        child: _staff.isEmpty
                            ? const Center(child: Text('No staff records found.'))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('Staff Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Created On', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _staff.map((s) {
                                      return DataRow(cells: [
                                        DataCell(Text(s['name'] ?? 'Staff', style: const TextStyle(fontWeight: FontWeight.w600))),
                                        DataCell(Text(s['email'] ?? '—')),
                                        DataCell(Text(s['phone'] ?? '—')),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AdminTheme.primaryOrange.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text((s['role'] ?? 'staff').toString().toUpperCase(), style: const TextStyle(color: AdminTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 11)),
                                          ),
                                        ),
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
                                        DataCell(Text(s['created_at'] != null ? s['created_at'].toString().split('T')[0] : '—')),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

