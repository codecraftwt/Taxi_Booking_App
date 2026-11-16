import 'package:flutter/material.dart';
import '../../core/admin_theme.dart';
import '../../core/admin_api_service.dart';
import '../auth/admin_login_screen.dart';
import '../dashboard/admin_dashboard_screen.dart';
import '../drivers/admin_drivers_screen.dart';
import '../documents/admin_documents_screen.dart';
import '../fares/admin_fares_screen.dart';
import '../rides/admin_rides_screen.dart';
import '../finance/admin_finance_screen.dart';
import '../customers/admin_customers_screen.dart';
import '../audit/admin_audit_screen.dart';

/// Upper concave fillet: cleanly draws only the curved arc scoop into the canvas.
/// Zero background box, zero border artifacts.
class UpperFilletPainter extends CustomPainter {
  final Color color;
  const UpperFilletPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w, h);
    path.lineTo(0, h);
    path.arcToPoint(
      Offset(w, 0),
      radius: Radius.circular(h),
      clockwise: false,
    );
    path.lineTo(w, h);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant UpperFilletPainter oldDelegate) => oldDelegate.color != color;
}

/// Lower concave fillet: cleanly draws only the curved arc scoop into the canvas.
/// Zero background box, zero border artifacts.
class LowerFilletPainter extends CustomPainter {
  final Color color;
  const LowerFilletPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w, 0);
    path.lineTo(w, h);
    path.arcToPoint(
      Offset(0, 0),
      radius: Radius.circular(h),
      clockwise: false,
    );
    path.lineTo(w, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LowerFilletPainter oldDelegate) => oldDelegate.color != color;
}

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({Key? key}) : super(key: key);

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _selectedIndex = 0;
  int? _hoveredIndex;
  bool _isCollapsed = false;

  final List<Map<String, dynamic>> _navItems = [
    {'title': 'Dashboard', 'icon': Icons.grid_view_rounded},
    {'title': 'Drivers & Fleet', 'icon': Icons.drive_eta_rounded},
    {'title': 'Document Verification', 'icon': Icons.assignment_turned_in_rounded},
    {'title': 'Fares & Commission', 'icon': Icons.price_change_rounded},
    {'title': 'Rides & Trips', 'icon': Icons.alt_route_rounded},
    {'title': 'Finance & Settlements', 'icon': Icons.account_balance_wallet_rounded},
    {'title': 'Customers', 'icon': Icons.people_alt_rounded},
    {'title': 'Audit & Staff', 'icon': Icons.shield_rounded},
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      AdminDashboardScreen(onNavigate: (index) => setState(() => _selectedIndex = index)),
      const AdminDriversScreen(),
      const AdminDocumentsScreen(),
      const AdminFaresScreen(),
      const AdminRidesScreen(),
      const AdminFinanceScreen(),
      const AdminCustomersScreen(),
      const AdminAuditScreen(),
    ];
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to end your Super Admin session?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Stay')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.errorRed),
            onPressed: () {
              AdminApiService.instance.logout();
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = AdminApiService.instance.currentAdmin;
    final adminName = admin?['name'] ?? 'Super Admin';
    final adminEmail = admin?['email'] ?? 'admin@saffar.com';
    final adminRole = (admin?['role'] ?? 'SUPER ADMIN').toString().toUpperCase();

    final sidebarWidth = _isCollapsed ? 82.0 : 255.0;

    return Scaffold(
      backgroundColor: AdminTheme.bgLight,
      body: Row(
        children: [
          // ─── LEFT SIDEBAR (SEAMLESS CURVED CUTOUT) ─────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            width: sidebarWidth,
            decoration: const BoxDecoration(
              color: AdminTheme.sidebarDark,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. BRAND HEADER + COLLAPSE TOGGLE
                _buildHeader(),

                const SizedBox(height: 10),

                // 2. NAV ITEMS LIST
                Expanded(
                  child: SingleChildScrollView(
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: List.generate(_navItems.length, (index) {
                        return _buildNavItem(index, sidebarWidth);
                      }),
                    ),
                  ),
                ),

                // 3. ADMIN PROFILE PILL AT BOTTOM
                _buildProfilePill(adminName, adminRole),
              ],
            ),
          ),

          // ─── MAIN CONTENT BODY & TOP BAR ─────────────────────────────
          Expanded(
            child: Container(
              color: AdminTheme.bgLight,
              child: Column(
                children: [
                  // Top Bar
                  Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: const BoxDecoration(
                      color: AdminTheme.cardWhite,
                      border: Border(bottom: BorderSide(color: AdminTheme.borderSubtle)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _navItems[_selectedIndex]['title'] as String,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AdminTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AdminTheme.successGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.circle, color: AdminTheme.successGreen, size: 8),
                                  SizedBox(width: 6),
                                  Text(
                                    'Node.js & PostgreSQL Connected',
                                    style: TextStyle(
                                      color: AdminTheme.successGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded, color: AdminTheme.textSecondary),
                              onPressed: () {},
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Text(
                                  adminEmail,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AdminTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AdminTheme.errorRed,
                                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.power_settings_new_rounded, size: 16),
                                  label: const Text('Exit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: _handleLogout,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Active Page Stack
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _pages,
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

  // ─── BRAND HEADER ──────────────────────────────────────────────────
  Widget _buildHeader() {
    if (_isCollapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminTheme.primaryOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AdminTheme.primaryOrange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAFFAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AdminTheme.primaryOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SUPER ADMIN',
                    style: TextStyle(
                      color: AdminTheme.primaryOrange,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── NAV ITEM (CURVED CUTOUT ON ACTIVE / PILL ON INACTIVE) ─────────
  Widget _buildNavItem(int index, double sidebarWidth) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    final isHovered = _hoveredIndex == index;

    if (isSelected) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: SizedBox(
          width: sidebarWidth,
          height: 52.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Upper Concave Fillet (Zero background container, pure arc scoop)
              Positioned(
                top: -19.5,
                right: -2.0,
                width: 22.0,
                height: 20.0,
                child: const CustomPaint(
                  painter: UpperFilletPainter(color: AdminTheme.bgLight),
                ),
              ),

              // 2. Active Tab Main Body (Connected flush with 2px bleed to eliminate any hairline)
              Positioned(
                top: 0,
                bottom: 0,
                left: _isCollapsed ? 10.0 : 16.0,
                right: -2.0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AdminTheme.bgLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(26),
                      bottomLeft: Radius.circular(26),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 8.0 : 12.0),
                  child: Row(
                    mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      // Circular dark badge with icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AdminTheme.sidebarDark,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                      if (!_isCollapsed) ...[
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            style: const TextStyle(
                              color: AdminTheme.sidebarDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 3. Lower Concave Fillet (Zero background container, pure arc scoop)
              Positioned(
                bottom: -19.5,
                right: -2.0,
                width: 22.0,
                height: 20.0,
                child: const CustomPaint(
                  painter: LowerFilletPainter(color: AdminTheme.bgLight),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Inactive Nav Item
    final inactiveWidget = MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(26),
          child: Container(
            height: 52.0,
            margin: EdgeInsets.symmetric(horizontal: _isCollapsed ? 10.0 : 16.0),
            decoration: BoxDecoration(
              color: isHovered ? Colors.white.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 6.0 : 12.0),
            child: Row(
              mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(
                    item['icon'] as IconData,
                    color: Colors.white.withOpacity(0.85),
                    size: 20,
                  ),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item['title'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (_isCollapsed) {
      return Tooltip(
        message: item['title'] as String,
        preferBelow: false,
        verticalOffset: 20,
        child: inactiveWidget,
      );
    }

    return inactiveWidget;
  }

  // ─── ADMIN PROFILE PILL ───────────────────────────────────────────
  Widget _buildProfilePill(String adminName, String adminRole) {
    if (_isCollapsed) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: IconButton(
          icon: CircleAvatar(
            radius: 18,
            backgroundColor: AdminTheme.primaryOrange,
            child: Text(
              adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          tooltip: 'Logout ($adminName)',
          onPressed: _handleLogout,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AdminTheme.primaryOrange,
            child: Text(
              adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adminName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  adminRole,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }
}
