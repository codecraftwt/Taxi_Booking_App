import 'package:flutter/material.dart';
import '../../core/admin_theme.dart';
import '../../core/admin_api_service.dart';

class AdminFaresScreen extends StatefulWidget {
  const AdminFaresScreen({Key? key}) : super(key: key);

  @override
  State<AdminFaresScreen> createState() => _AdminFaresScreenState();
}

class _AdminFaresScreenState extends State<AdminFaresScreen> {
  bool _isLoading = true;
  List<dynamic> _fares = [];

  @override
  void initState() {
    super.initState();
    _fetchFares();
  }

  Future<void> _fetchFares() async {
    setState(() => _isLoading = true);
    try {
      final list = await AdminApiService.instance.getFares();
      setState(() {
        _fares = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load fare configurations: $e'), backgroundColor: AdminTheme.errorRed),
        );
      }
    }
  }

  void _openEditDialog(Map<String, dynamic> fare) {
    final category = fare['category']?.toString() ?? '';
    final baseFareCtrl = TextEditingController(text: fare['base_fare']?.toString() ?? '0');
    final baseDistCtrl = TextEditingController(text: (fare['base_distance_km'] ?? '0').toString());
    final perKmCtrl = TextEditingController(text: (fare['per_km'] ?? fare['per_km_rate'] ?? '12').toString());
    final perMinCtrl = TextEditingController(text: (fare['per_minute'] ?? fare['per_minute_rate'] ?? '1.5').toString());
    final minFareCtrl = TextEditingController(text: (fare['minimum_fare'] ?? '30').toString());
    final commissionCtrl = TextEditingController(text: (fare['commission_percentage'] ?? fare['commission_rate'] ?? '15').toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Fare: ${category.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: baseFareCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Base Fare (₹)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: baseDistCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Base Distance (km)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: perKmCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Per Km Rate (₹)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: perMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Per Min Rate (₹)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minFareCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minimum Fare (₹)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: commissionCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Platform Commission (%)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primaryOrange),
            onPressed: () async {
              final payload = {
                'base_fare': double.tryParse(baseFareCtrl.text) ?? 0,
                'base_distance_km': double.tryParse(baseDistCtrl.text) ?? 0,
                'per_km': double.tryParse(perKmCtrl.text) ?? 0,
                'per_km_rate': double.tryParse(perKmCtrl.text) ?? 0,
                'per_minute': double.tryParse(perMinCtrl.text) ?? 0,
                'per_minute_rate': double.tryParse(perMinCtrl.text) ?? 0,
                'minimum_fare': double.tryParse(minFareCtrl.text) ?? 0,
                'commission_percentage': double.tryParse(commissionCtrl.text) ?? 0,
                'commission_rate': double.tryParse(commissionCtrl.text) ?? 0,
              };
              final ok = await AdminApiService.instance.updateFare(category, payload);
              if (context.mounted) {
                Navigator.of(ctx).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated $category fare successfully!'), backgroundColor: AdminTheme.successGreen),
                  );
                  _fetchFares();
                }
              }
            },
            child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'bike':
        return Icons.two_wheeler_rounded;
      case 'auto':
        return Icons.electric_rickshaw_rounded;
      case 'sedan':
      case 'prime sedan':
        return Icons.directions_car_filled_rounded;
      case 'car':
      default:
        return Icons.directions_car_rounded;
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
                  const Text('Fares & Commission Matrix', style: AdminTheme.headingLarge),
                  const SizedBox(height: 4),
                  const Text('Configure base fares, per-kilometer pricing, and platform take-rates by vehicle category', style: AdminTheme.bodySecondary),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _fetchFares,
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AdminTheme.primaryOrange))
                : _fares.isEmpty
                    ? const Center(child: Text('No fare configurations found.'))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420,
                          mainAxisExtent: 330,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: _fares.length,
                        itemBuilder: (ctx, index) {
                          final fare = _fares[index];
                          final category = fare['category']?.toString() ?? 'Vehicle';
                          final baseFare = fare['base_fare'] ?? 0;
                          final baseDist = fare['base_distance_km'] ?? 0;
                          final perKm = fare['per_km'] ?? fare['per_km_rate'] ?? 0;
                          final perMin = fare['per_minute'] ?? fare['per_minute_rate'] ?? 0;
                          final minFare = fare['minimum_fare'] ?? 0;
                          final commission = fare['commission_percentage'] ?? fare['commission_rate'] ?? 0;

                          return Container(
                            decoration: AdminTheme.elevatedCardDecoration,
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AdminTheme.primaryOrange.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(_getCategoryIcon(category), color: AdminTheme.primaryOrange, size: 26),
                                        ),
                                        const SizedBox(width: 14),
                                        Text(category.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary)),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: AdminTheme.secondaryBlue, size: 20),
                                      tooltip: 'Edit Pricing',
                                      onPressed: () => _openEditDialog(fare),
                                    ),
                                  ],
                                ),
                                const Divider(height: 28),
                                _buildPriceRow('Base Fare', '₹$baseFare (up to $baseDist km)'),
                                const SizedBox(height: 10),
                                _buildPriceRow('Rate per KM', '₹$perKm / km'),
                                const SizedBox(height: 10),
                                _buildPriceRow('Rate per Minute', '₹$perMin / min'),
                                const SizedBox(height: 10),
                                _buildPriceRow('Minimum Fare', '₹$minFare'),
                                const SizedBox(height: 10),
                                _buildPriceRow('Platform Commission', '$commission%', highlight: true),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AdminTheme.secondaryBlue,
                                      side: const BorderSide(color: AdminTheme.secondaryBlue),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.tune_rounded, size: 16),
                                    label: const Text('Update Rates'),
                                    onPressed: () => _openEditDialog(fare),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: highlight ? AdminTheme.successGreen : AdminTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

