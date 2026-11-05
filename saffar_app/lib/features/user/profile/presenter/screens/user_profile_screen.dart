import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';
import 'package:saffar_app/features/home/presenter/screens/home.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/features/user/presenter/screens/user_ride_history_screen.dart';
import 'package:saffar_app/features/user/presenter/screens/user_support_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  static const String routeName = '/user_profile';

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserCubit>().fetchAndRefreshUserProfile();
    });
  }

  void _openEditProfileDialog(
    BuildContext context, {
    required String currentName,
    required String? currentEmail,
    required String currentPhone,
    String? currentAddress,
    String? currentImageUrl,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(
        currentName: currentName,
        currentEmail: currentEmail,
        currentPhone: currentPhone,
        currentAddress: currentAddress,
        currentImageUrl: currentImageUrl,
      ),
    );
  }

  void _showAddMoneyDialog(BuildContext context) {
    final amountController = TextEditingController(text: '500');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Money to Saffar Wallet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                labelText: 'Enter Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: ['₹200', '₹500', '₹1000'].map((chip) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(chip),
                    onPressed: () {
                      amountController.text = chip.replaceAll('₹', '');
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final entered = double.tryParse(amountController.text.trim()) ?? 500.0;
                  Navigator.pop(ctx);
                  final success = await context.read<UserCubit>().addMoneyToWallet(entered);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? 'Added ₹${entered.toStringAsFixed(0)} to Wallet in database!'
                            : 'Failed to update wallet. Please check connection.'),
                        backgroundColor: success ? const Color(0xFF20A46B) : Palette.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Proceed to Pay'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPromoCodesDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Offers & Coupons',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _promoTile('SAVE30', 'Save 30% on next 3 auto & bike rides', 'Max ₹50 off'),
            const SizedBox(height: 10),
            _promoTile('SAFFARFIRST', '20% off on first 5 Auto rides', 'Applied automatically'),
            const SizedBox(height: 10),
            _promoTile('WEEKEND50', '₹50 flat cashback on Prime Sedan rides', 'Valid Sat-Sun'),
          ],
        ),
      ),
    );
  }

  Widget _promoTile(String code, String desc, String badge) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFFFEDD5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Palette.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  badge,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your Saffar account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context
                  .read<UserCubit>()
                  .deleteCurrentUserFromLocalStorageAndEmitCurrentUser(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                RoleSelectionScreen.routeName,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: BlocBuilder<UserCubit, UserState>(
          builder: (context, state) {
            final user = state.currentUser;
            final displayName = (user != null && user.name.isNotEmpty)
                ? user.name
                : 'Rider';
            final rawPhone = (user != null && user.phone.isNotEmpty)
                ? user.phone
                : '98765 43210';
            final displayPhone = rawPhone.startsWith('+91')
                ? rawPhone.substring(3).trim()
                : rawPhone;
            final displayEmail = (user?.email != null && user!.email!.isNotEmpty)
                ? user.email!
                : '';
            final displayAddress = user?.address;

            return Column(
              children: [
                // Top App Bar
                _buildTopBar(context, user),

                // Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Rider Profile Title (Settings gear removed as requested)
                        _buildHeaderRow(context, memberSince: user?.memberSince),

                        const SizedBox(height: 14),

                        // Profile Details Card
                        _buildProfileDetailsCard(
                          context,
                          displayName: displayName,
                          displayPhone: displayPhone,
                          displayEmail: displayEmail,
                          displayAddress: displayAddress,
                          userImageUrl: user?.imageUrl,
                          rating: user?.rating ?? 4.92,
                        ),

                        const SizedBox(height: 14),

                        // Three Stats Cards
                        _buildStatsRow(
                          context,
                          totalRides: user?.totalRides ?? 0,
                          walletBalance: user?.walletBalance ?? 1240.0,
                          savedPlacesCount: user?.savedPlacesCount ?? 2,
                        ),

                        const SizedBox(height: 18),

                        // Safety & Emergency Hub
                        _buildSafetySection(context),

                        const SizedBox(height: 18),

                        // Payment & Wallets
                        _buildPaymentSection(
                          context,
                          walletBalance: user?.walletBalance ?? 1240.0,
                        ),

                        const SizedBox(height: 18),

                        // Preferences & Places
                        _buildPreferencesSection(context, displayAddress: displayAddress),

                        const SizedBox(height: 18),

                        // Help & Support
                        _buildSupportSection(context),

                        const SizedBox(height: 22),

                        // Log Out Button
                        _buildLogoutButton(context),

                        const SizedBox(height: 14),

                        // App Version Footer
                        const Center(
                          child: Text(
                            'Saffar Mobility App v4.12.0 (Build 8904)',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Bottom Navigation Bar
                _buildBottomNavBar(context),
              ],
            );
          },
        ),
      ),
    );
  }

  // 1. Top Bar with Saffar logo & notifications
  Widget _buildTopBar(BuildContext context, dynamic user) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Saffar Brand Logo
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B00), Color(0xFFFF8A00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.electric_rickshaw_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Saffar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Palette.neutral,
                  height: 1.1,
                ),
              ),
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Bell Icon
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF1E293B),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Mini Avatar
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Palette.primary, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _buildAvatarImage(
                  imageUrl: user?.imageUrl,
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Header Row: "Rider Profile" (Settings button removed)
  Widget _buildHeaderRow(BuildContext context, {String? memberSince}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rider Profile',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Palette.neutral,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          memberSince ?? 'Member since March 2023',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 3. Main Profile Details Card with Edit Pencil & Badges
  Widget _buildProfileDetailsCard(
    BuildContext context, {
    required String displayName,
    required String displayPhone,
    required String displayEmail,
    String? displayAddress,
    String? userImageUrl,
    double rating = 4.92,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with Pencil Overlay
              Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: _buildAvatarImage(
                        imageUrl: userImageUrl,
                        size: 72,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _openEditProfileDialog(
                        context,
                        currentName: displayName,
                        currentEmail: displayEmail,
                        currentPhone: displayPhone,
                        currentAddress: displayAddress,
                        currentImageUrl: userImageUrl,
                      ),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Palette.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Palette.primary.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Name, Phone, Email, Address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Palette.neutral,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF20A46B),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayPhone.startsWith('+91')
                          ? displayPhone
                          : '+91 $displayPhone',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (displayEmail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        displayEmail,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (displayAddress != null && displayAddress.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.home_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              displayAddress,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Badges Row
          Row(
            children: [
              // Rating Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E7FF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFF8A00), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${rating.toStringAsFixed(2)} ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      'Rider Rating',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // KYC Verified Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined,
                        color: Color(0xFF059669), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'KYC Verified',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Three Stats Cards Row
  Widget _buildStatsRow(
    BuildContext context, {
    int totalRides = 0,
    double walletBalance = 1240.0,
    int savedPlacesCount = 2,
  }) {
    return Row(
      children: [
        // Total Rides
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL RIDES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalRides',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Palette.neutral,
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.trending_up_rounded,
                        color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 2),
                    Text(
                      'Top 5%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Wallet
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WALLET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${walletBalance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Palette.neutral,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showAddMoneyDialog(context),
                  child: const Text(
                    '+ Add Money',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Palette.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Saved Places
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAVED PLACES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$savedPlacesCount',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Palette.neutral,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Home • Work',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 5. Section: Safety & Emergency Hub
  Widget _buildSafetySection(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_rounded, color: Palette.primary, size: 18),
                SizedBox(width: 6),
                Text(
                  'Safety & Emergency Hub',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Palette.neutral,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Secured',
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildListRow(
                icon: Icons.contacts_rounded,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: Palette.primary,
                title: 'Emergency SOS & Trusted Contacts',
                subtitle: 'Instant SOS trigger and live ride sharing',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '2 Active',
                    style: TextStyle(
                      color: Color(0xFF0F766E),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pushNamed(context, UserSupportScreen.routeName);
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildListRow(
                icon: Icons.nightlight_round,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                title: 'Ride Check & Night Safety',
                subtitle: 'Automated unexpected stop check-ins active',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'active',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Night Safety Shield is active on all rides.'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 6. Section: Payment & Wallets
  Widget _buildPaymentSection(BuildContext context, {double walletBalance = 1240.0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment & Wallets',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Palette.neutral,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildListRow(
                icon: Icons.account_balance_wallet_rounded,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                title: 'Saffar Wallet & Saved Cards',
                subtitle: 'Primary: Saffar Cashless • Auto-Pay',
                trailing: Text(
                  '₹${walletBalance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Palette.neutral,
                  ),
                ),
                onTap: () => _showAddMoneyDialog(context),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildListRow(
                icon: Icons.local_offer_rounded,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: Palette.primary,
                title: 'Offers & Promo Codes',
                subtitle: '3 discount coupons ready for you',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '3 New',
                    style: TextStyle(
                      color: Palette.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () => _showPromoCodesDialog(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 7. Section: Preferences & Places
  Widget _buildPreferencesSection(BuildContext context, {String? displayAddress}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferences & Places',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Palette.neutral,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _buildListRow(
            icon: Icons.bookmark_outline_rounded,
            iconBg: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            title: 'Saved Places',
            subtitle: (displayAddress != null && displayAddress.isNotEmpty)
                ? displayAddress
                : 'Home, CyberCity Hub (Add Gym)',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(displayAddress != null && displayAddress.isNotEmpty
                      ? 'Permanent Address: $displayAddress'
                      : 'Manage saved addresses & shortcuts'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 8. Section: Help & Support
  Widget _buildSupportSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Help & Support',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Palette.neutral,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildListRow(
                icon: Icons.headset_mic_rounded,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                title: '24x7 Customer Support & FAQs',
                subtitle: 'Immediate live agent chat or callback',
                onTap: () {
                  Navigator.pushNamed(context, UserSupportScreen.routeName);
                },
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildListRow(
                icon: Icons.warning_amber_rounded,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                title: 'Report an Issue with a Ride',
                subtitle: 'Lost item, fare discrepancy, feedback',
                onTap: () {
                  Navigator.pushNamed(context, UserSupportScreen.routeName);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 9. Log Out Button
  Widget _buildLogoutButton(BuildContext context) {
    return InkWell(
      onTap: () => _showLogoutDialog(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE4E6)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 18),
            SizedBox(width: 8),
            Text(
              'Log Out',
              style: TextStyle(
                color: Color(0xFFE11D48),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable List Row
  Widget _buildListRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Palette.neutral,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // 11. Bottom Navigation Bar matching Stitch design
  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            Icons.map_outlined,
            'Home',
            false,
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                HomeScreen.routeName,
                (route) => false,
              );
            },
          ),
          _buildNavItem(
            Icons.history_rounded,
            'My Rides',
            false,
            onTap: () {
              Navigator.pushReplacementNamed(
                context,
                UserRideHistoryScreen.routeName,
              );
            },
          ),
          _buildNavItem(
            Icons.notifications_none_rounded,
            'Notifications',
            false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
          _buildNavItem(
            Icons.person_outline_rounded,
            'Profile',
            true,
            hasDot: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive, {
    bool hasDot = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? Palette.primary : const Color(0xFF64748B),
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? Palette.primary : const Color(0xFF64748B),
            ),
          ),
          if (hasDot) ...[
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B00),
                shape: BoxShape.circle,
              ),
            ),
          ] else ...[
            const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

// Reusable avatar image builder supporting picked bytes, data URI, or network URL
Widget _buildAvatarImage({
  Uint8List? localBytes,
  String? imageUrl,
  double size = 72,
}) {
  if (localBytes != null && localBytes.isNotEmpty) {
    return Image.memory(
      localBytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }

  if (imageUrl != null && imageUrl.isNotEmpty) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final commaIdx = imageUrl.indexOf(',');
        final base64Data =
            commaIdx != -1 ? imageUrl.substring(commaIdx + 1) : imageUrl;
        return Image.memory(
          base64Decode(base64Data),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatarPlaceholder(size),
        );
      } catch (_) {
        return _defaultAvatarPlaceholder(size);
      }
    }

    return Image.network(
      imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _defaultAvatarPlaceholder(size),
    );
  }

  return _defaultAvatarPlaceholder(size);
}

Widget _defaultAvatarPlaceholder(double size) {
  return Container(
    width: size,
    height: size,
    color: const Color(0xFFF1F5F9),
    child: Icon(
      Icons.person,
      size: size * 0.55,
      color: Palette.primary,
    ),
  );
}

class _EditProfileSheet extends StatefulWidget {
  final String currentName;
  final String? currentEmail;
  final String currentPhone;
  final String? currentAddress;
  final String? currentImageUrl;

  const _EditProfileSheet({
    Key? key,
    required this.currentName,
    required this.currentEmail,
    required this.currentPhone,
    this.currentAddress,
    this.currentImageUrl,
  }) : super(key: key);

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  Uint8List? _pickedImageBytes;
  String? _newImageBase64;
  late String? _currentImageUrl;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isPickingPhoto = false;
  String? _photoErrorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail ?? '');

    // Strip leading +91 for clean editing in prefix-adorned field
    String initialPhone = widget.currentPhone.trim();
    if (initialPhone.startsWith('+91')) {
      initialPhone = initialPhone.substring(3).trim();
    }
    _phoneController = TextEditingController(text: initialPhone);
    _addressController =
        TextEditingController(text: widget.currentAddress ?? '');
    _currentImageUrl = widget.currentImageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _photoErrorMessage = null;
      _isPickingPhoto = true;
    });

    try {
      XFile? file;
      try {
        file = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
      } catch (err) {
        debugPrint('pickImage with options failed ($err), trying fallback...');
        try {
          file = await _picker.pickImage(source: source);
        } catch (err2) {
          // If camera is unsupported on desktop or device without camera, fall back to gallery
          if (source == ImageSource.camera) {
            debugPrint('Camera unsupported/failed ($err2), falling back to gallery');
            file = await _picker.pickImage(source: ImageSource.gallery);
          } else {
            rethrow;
          }
        }
      }

      if (file == null) {
        // User cancelled photo selection
        setState(() => _isPickingPhoto = false);
        return;
      }

      final bytes = await file.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      setState(() {
        _pickedImageBytes = bytes;
        _newImageBase64 = base64Str;
        _isPickingPhoto = false;
        _photoErrorMessage = null;
      });
    } catch (e) {
      setState(() => _isPickingPhoto = false);
      final errStr = e.toString();
      debugPrint('Error picking image: $errStr');

      String friendlyMessage;
      if (errStr.contains('MissingPluginException') ||
          errStr.contains('No implementation found')) {
        friendlyMessage =
            'Native photo picker plugin requires an app restart.\nPlease STOP your running app and run "flutter run" again to enable device photo access.';
      } else if (errStr.contains('cameraDelegate') ||
          errStr.contains('StateError')) {
        friendlyMessage =
            'Camera is not supported on this platform/device. Please use "From Device" to choose a photo.';
      } else {
        friendlyMessage = 'Could not access photo: $errStr';
      }

      setState(() {
        _photoErrorMessage = friendlyMessage;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Palette.primary),
                SizedBox(width: 8),
                Text('Photo Access', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Text(friendlyMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Choose Profile Photo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Palette.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Palette.primary),
                ),
                title: const Text('Take Photo',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Click a new photo with camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Color(0xFF0284C7)),
                ),
                title: const Text('Choose from Device',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select a photo from device storage'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();
    String newPhone = _phoneController.text.trim();
    final newAddress = _addressController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    if (newPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact number cannot be empty')),
      );
      return;
    }

    if (!newPhone.startsWith('+')) {
      newPhone = '+91 $newPhone';
    }

    setState(() => _isSaving = true);

    final success = await context.read<UserCubit>().updateUserProfile(
          name: newName,
          email: newEmail.isNotEmpty ? newEmail : null,
          phone: newPhone,
          address: newAddress.isNotEmpty ? newAddress : null,
          imageUrl: _newImageBase64 ?? _currentImageUrl,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profile updated successfully!'
                : 'Failed to update profile.',
          ),
          backgroundColor:
              success ? const Color(0xFF20A46B) : Palette.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header: Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Rider Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Palette.neutral,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Update photo, contact & permanent address',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF64748B)),
                  splashRadius: 20,
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),

            // Avatar Section with Camera overlay and buttons
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImageSourcePicker,
                    child: Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Palette.primary, width: 2.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(45),
                            child: _isPickingPhoto
                                ? const Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Palette.primary,
                                      ),
                                    ),
                                  )
                                : _buildAvatarImage(
                                    localBytes: _pickedImageBytes,
                                    imageUrl: _currentImageUrl,
                                    size: 90,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Palette.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Two Action Buttons: Take Photo & From Device (Wrap prevents overflow on narrow screens)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isPickingPhoto
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('Take Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Palette.primary,
                          side: const BorderSide(color: Palette.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isPickingPhoto
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, size: 16),
                        label: const Text('From Device'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFF0284C7)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  if (_photoErrorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFFDC2626), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _photoErrorMessage!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Form Fields: Full Name
            const Text(
              'Full Name *',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                prefixIcon:
                    const Icon(Icons.person_outline, color: Palette.primary),
                hintText: 'e.g. Sameer Verma',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // Email Address
            const Text(
              'Email Address',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                prefixIcon:
                    const Icon(Icons.email_outlined, color: Palette.primary),
                hintText: 'e.g. sameer.v@example.com',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // Contact / Phone Number
            const Text(
              'Contact Number *',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon:
                    const Icon(Icons.phone_outlined, color: Palette.primary),
                prefixText: '+91 ',
                hintText: '9876543210',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // Permanent Address
            const Text(
              'Permanent Address',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Icon(Icons.home_outlined, color: Palette.primary),
                ),
                hintText:
                    'e.g. Flat 402, Green Valley Apts, Koramangala 4th Block, Bengaluru',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Save Profile Changes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
