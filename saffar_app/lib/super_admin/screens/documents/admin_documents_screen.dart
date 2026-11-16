import 'package:flutter/material.dart';
import '../../core/admin_theme.dart';
import '../../core/admin_api_service.dart';

class AdminDocumentsScreen extends StatefulWidget {
  const AdminDocumentsScreen({Key? key}) : super(key: key);

  @override
  State<AdminDocumentsScreen> createState() => _AdminDocumentsScreenState();
}

class _AdminDocumentsScreenState extends State<AdminDocumentsScreen> {
  bool _isLoading = true;
  String _selectedStatus = 'pending';
  String? _selectedDocType;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalDocs = 0;
  List<dynamic> _documents = [];

  final List<Map<String, String>> _statusTabs = [
    {'label': 'Pending Review', 'value': 'pending'},
    {'label': 'Approved', 'value': 'approved'},
    {'label': 'Rejected', 'value': 'rejected'},
    {'label': 'All Documents', 'value': 'all'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() => _isLoading = true);
    try {
      final res = await AdminApiService.instance.getDocuments(
        status: _selectedStatus,
        documentType: _selectedDocType,
        page: _currentPage,
        limit: 15,
      );
      setState(() {
        _documents = res['documents'] ?? [];
        _totalPages = res['pagination']?['totalPages'] ?? 1;
        _totalDocs = res['pagination']?['total'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load documents: $e'), backgroundColor: AdminTheme.errorRed),
        );
      }
    }
  }

  void _reviewDocument(Map<String, dynamic> doc) {
    final docId = doc['id'].toString();
    final driverName = doc['driver_name'] ?? 'Driver #${doc['driver_id']}';
    final docType = doc['document_type'] ?? 'Document';
    final docUrl = doc['document_url'] ?? '';
    final status = doc['verification_status'] ?? 'pending';

    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: AdminTheme.cardWhite,
            child: Container(
              width: 750,
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
                          Text(
                            'Review $docType',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted by $driverName • Driver ID: #${doc['driver_id']}',
                            style: const TextStyle(fontSize: 13, color: AdminTheme.textSecondary),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AdminTheme.textSecondary),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // Image Preview
                  Container(
                    height: 340,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminTheme.borderSubtle),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: docUrl.isNotEmpty
                        ? Image.network(
                            docUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.broken_image_rounded, size: 56, color: AdminTheme.textSecondary),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Document Preview: $docType',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'URL: $docUrl',
                                    style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.description_rounded, size: 56, color: AdminTheme.primaryOrange),
                                const SizedBox(height: 12),
                                Text('Document file uploaded: $docType', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('No public preview available', style: TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  if (status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AdminTheme.errorRed,
                              side: const BorderSide(color: AdminTheme.errorRed),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Reject Document', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              _showRejectDialog(docId, driverName, docType);
                              Navigator.of(ctx).pop();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.successGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Approve Document', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final success = await AdminApiService.instance.verifyDocument(docId, 'approved');
                              if (context.mounted) {
                                Navigator.of(ctx).pop();
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Document approved successfully!'),
                                      backgroundColor: AdminTheme.successGreen,
                                    ),
                                  );
                                  _fetchDocuments();
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: status == 'approved' ? AdminTheme.successGreen.withOpacity(0.1) : AdminTheme.errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == 'approved' ? Icons.check_circle : Icons.cancel,
                            color: status == 'approved' ? AdminTheme.successGreen : AdminTheme.errorRed,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Document is already marked as ${status.toUpperCase()}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: status == 'approved' ? AdminTheme.successGreen : AdminTheme.errorRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showRejectDialog(String docId, String driverName, String docType) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject $docType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide reason for rejecting driver $driverName\'s document:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Blurry photo, expired license, details not matching',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.errorRed),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              final ok = await AdminApiService.instance.verifyDocument(
                docId,
                'rejected',
                rejectionReason: reasonController.text.trim(),
              );
              if (context.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document rejected with feedback.'), backgroundColor: AdminTheme.errorRed),
                  );
                  _fetchDocuments();
                }
              }
            },
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
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
                  const Text('Document Verification Queue', style: AdminTheme.headingLarge),
                  const SizedBox(height: 4),
                  Text('Review uploaded driver licenses, RC, insurance and permits ($_totalDocs total)', style: AdminTheme.bodySecondary),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _fetchDocuments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.cardWhite,
                  foregroundColor: AdminTheme.textPrimary,
                  side: const BorderSide(color: AdminTheme.borderSubtle),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh Queue', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Filter Tabs
          Row(
            children: _statusTabs.map((tab) {
              final isSelected = _selectedStatus == tab['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ChoiceChip(
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
                      _fetchDocuments();
                    }
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Table Card
          Expanded(
            child: Container(
              decoration: AdminTheme.elevatedCardDecoration,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AdminTheme.primaryOrange))
                  : _documents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 64, color: AdminTheme.successGreen),
                              const SizedBox(height: 16),
                              Text('No ${_selectedStatus == 'all' ? '' : _selectedStatus} documents found', style: AdminTheme.headingSmall),
                              const SizedBox(height: 6),
                              const Text('All driver documents in this category are fully processed.', style: TextStyle(color: AdminTheme.textSecondary)),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('Driver Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Document Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Document Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Submitted Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _documents.map((doc) {
                                      final status = doc['verification_status'] ?? 'pending';
                                      Color badgeColor = AdminTheme.accentAmber;
                                      if (status == 'approved') badgeColor = AdminTheme.successGreen;
                                      if (status == 'rejected') badgeColor = AdminTheme.errorRed;

                                      return DataRow(cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: AdminTheme.secondaryBlue.withOpacity(0.1),
                                                child: Text(
                                                  (doc['driver_name'] ?? 'D')[0].toUpperCase(),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.secondaryBlue),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(doc['driver_name'] ?? 'Driver #${doc['driver_id']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(doc['driver_phone'] ?? '—')),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              (doc['document_type'] ?? 'DOC').toString().toUpperCase(),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AdminTheme.textPrimary),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(doc['document_number'] ?? '—')),
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
                                        DataCell(Text(doc['created_at'] != null ? doc['created_at'].toString().split('T')[0] : '—')),
                                        DataCell(
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AdminTheme.primaryOrange,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _reviewDocument(doc),
                                            child: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

