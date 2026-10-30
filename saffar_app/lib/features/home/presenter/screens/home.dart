import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:saffar_app/core/constants/nums.dart';
import 'package:saffar_app/core/constants/strings.dart';
import 'package:saffar_app/core/cubits/previous_rides_cubit.dart';
import 'package:saffar_app/core/palette.dart';
import 'package:saffar_app/features/authentication/presenter/screens/role_selection_screen.dart';
import 'package:saffar_app/features/driver/presenter/screens/driver_sign_in_screen.dart';
import 'package:saffar_app/features/user/presenter/cubits/user_cubit.dart';
import 'package:saffar_app/core/models/address.dart';
import 'package:saffar_app/core/widgets/address_widget.dart';
import 'package:saffar_app/features/home/presenter/cubits/home_cubit.dart';
import 'package:saffar_app/features/user/presenter/screens/user_profile_screen.dart';
import 'package:saffar_app/features/user/presenter/screens/user_ride_history_screen.dart';
import 'package:saffar_app/features/user/presenter/screens/user_support_screen.dart';
import 'package:saffar_app/features/view_map/presenter/screens/view_map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static const String routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final HomeCubit _homeCubit;

  @override
  void initState() {
    super.initState();

    _homeCubit = HomeCubit();

    _homeCubit.initHomeCubit(context);

    context.read<PreviousRidesCubit>().getListOfPreviousRidesAndEmit();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Log Out'),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5484D)),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return BlocProvider<HomeCubit>.value(
      value: _homeCubit,
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, homeState) {
          return BlocBuilder<UserCubit, UserState>(
            builder: (context, userState) {
              final user = userState.currentUser;
              final String? userImageUrl = user?.imageUrl;

              return Stack(
                children: [
                  Scaffold(
                    key: _scaffoldKey,
                    drawer: Drawer(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Drawer Header with Profile
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, UserProfileScreen.routeName);
                            },
                            child: Container(
                              color: Palette.primary,
                              padding: EdgeInsets.fromLTRB(
                                20,
                                mediaQueryData.padding.top + 24,
                                20,
                                20,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        width: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(30),
                                      child: userImageUrl != null
                                          ? Image.network(
                                              userImageUrl,
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(
                                              Icons.person,
                                              size: 36,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user?.name ?? 'Passenger',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '+91 ${user?.phone ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: const [
                                            Text(
                                              'View Profile',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 10,
                                              color: Colors.white,
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

                          const SizedBox(height: 12),

                          // Drawer Navigation Items
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              children: [
                                _DrawerTile(
                                  icon: Icons.home_rounded,
                                  title: 'Home Dashboard',
                                  onTap: () => Navigator.pop(context),
                                ),
                                const SizedBox(height: 4),
                                _DrawerTile(
                                  icon: Icons.history_rounded,
                                  title: 'My Trips & Activity',
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, UserRideHistoryScreen.routeName);
                                  },
                                ),
                                const SizedBox(height: 4),
                                _DrawerTile(
                                  icon: Icons.person_outline_rounded,
                                  title: 'Manage Profile',
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, UserProfileScreen.routeName);
                                  },
                                ),
                                const SizedBox(height: 4),
                                _DrawerTile(
                                  icon: Icons.support_agent_rounded,
                                  title: 'Help & 24/7 SOS',
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, UserSupportScreen.routeName);
                                  },
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(height: 1),
                                ),
                                _DrawerTile(
                                  icon: Icons.local_taxi_rounded,
                                  title: 'Switch to Driver Mode',
                                  subtitle: 'Start accepting rides & earning',
                                  color: const Color(0xFF008577),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, DriverSignInScreen.routeName);
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Logout button at bottom of drawer
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: OutlinedButton.icon(
                              onPressed: () => _showLogoutDialog(context),
                              icon: const Icon(Icons.logout, color: Color(0xFFE5484D)),
                              label: const Text(
                                'Log Out',
                                style: TextStyle(
                                  color: Color(0xFFE5484D),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE5484D)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(Nums.roundedCornerRadius),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    body: Column(
                      children: [
                        Container(
                          color: colorScheme.primary,
                          padding: EdgeInsets.fromLTRB(
                            Nums.horizontalPadding,
                            statusBarHeight + 16,
                            Nums.horizontalPadding,
                            16,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // User name
                                        Text(
                                          user?.name.split(' ').first ??
                                              'Welcome',
                                          maxLines: 1,
                                          style: textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Saffar caption
                                        Text(
                                          Strings.saffarCaption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onPrimary
                                                .withOpacity(.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // User image / Drawer button
                                  GestureDetector(
                                    onTap: () {
                                      _scaffoldKey.currentState!.openDrawer();
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          width: 2,
                                          color: colorScheme.onPrimary
                                              .withOpacity(.6),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(40),
                                        ),
                                        child: userImageUrl != null
                                            ? Image.network(
                                                userImageUrl,
                                                fit: BoxFit.cover,
                                              )
                                            : Icon(
                                                Icons.person,
                                                color: colorScheme.onPrimary,
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Where do you want to go Container Button
                              GestureDetector(
                                onTap: () async {
                                  final bool locationEnabled = await _homeCubit
                                      .requestLocationPermissionAndEnableLocation(
                                          context);

                                  if (locationEnabled) {
                                    final Address? currentAddress =
                                        await _homeCubit.getCurrentAddress();

                                    await Navigator.pushNamed(
                                      context,
                                      ViewMapScreen.routeName,
                                      arguments: ViewMapScreenArguments(
                                        initialPickupAddress: currentAddress,
                                      ),
                                    );

                                    context
                                        .read<PreviousRidesCubit>()
                                        .getListOfPreviousRidesAndEmit();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colorScheme.onPrimary,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(Nums.roundedCornerRadius),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Where do you want to go
                                      Text(
                                        'Where do you want to go?',
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          Container(
                                            height: 24,
                                            width: 24,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: colorScheme.primary,
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              color: colorScheme.onPrimary,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 16),

                                          // Find the location text
                                          Expanded(
                                            child: Text(
                                              'Find the location',
                                              style:
                                                  textTheme.bodyLarge?.copyWith(
                                                color: textTheme
                                                    .bodyLarge?.color
                                                    ?.withOpacity(.6),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Quick Shortcuts
                              SizedBox(
                                height: 42,
                                child: ListView(
                                  physics: const BouncingScrollPhysics(),
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, UserRideHistoryScreen.routeName);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          width: 1.5,
                                          color: colorScheme.onPrimary.withOpacity(.4),
                                        ),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(Nums.roundedCornerRadius),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.history_rounded,
                                            size: 18,
                                            color: colorScheme.onPrimary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'My Rides',
                                            style: textTheme.labelLarge?.copyWith(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, UserProfileScreen.routeName);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          width: 1.5,
                                          color: colorScheme.onPrimary.withOpacity(.4),
                                        ),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(Nums.roundedCornerRadius),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline_rounded,
                                            size: 18,
                                            color: colorScheme.onPrimary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Profile',
                                            style: textTheme.labelLarge?.copyWith(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, UserSupportScreen.routeName);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          width: 1.5,
                                          color: colorScheme.onPrimary.withOpacity(.4),
                                        ),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(Nums.roundedCornerRadius),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.help_outline_rounded,
                                            size: 18,
                                            color: colorScheme.onPrimary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Help & SOS',
                                            style: textTheme.labelLarge?.copyWith(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Nums.horizontalPadding),
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),

                                  BlocBuilder<PreviousRidesCubit,
                                      PreviousRidesState>(
                                    builder: (context, state) {
                                      if (state is PreviousRidesGot) {
                                        // Most recently visited place address.
                                        return state
                                                .latestTwoPreviousRidesWithoutCancellation
                                                .isEmpty
                                            ? const SizedBox()
                                            : Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 16),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        colorScheme.onPrimary,
                                                    borderRadius:
                                                        const BorderRadius.all(
                                                      Radius.circular(
                                                        Nums.roundedCornerRadius,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    children: List.generate(
                                                      state
                                                          .latestTwoPreviousRidesWithoutCancellation
                                                          .length,
                                                      (index) {
                                                        final Address address = state
                                                            .latestTwoPreviousRidesWithoutCancellation[
                                                                index]
                                                            .destinationAddress;

                                                        return GestureDetector(
                                                          onTap: () async {
                                                            await Navigator
                                                                .pushNamed(
                                                              context,
                                                              ViewMapScreen
                                                                  .routeName,
                                                              arguments:
                                                                  ViewMapScreenArguments(
                                                                initialDestinationAddress:
                                                                    address,
                                                              ),
                                                            );

                                                            context
                                                                .read<
                                                                    PreviousRidesCubit>()
                                                                .getListOfPreviousRidesAndEmit();
                                                          },
                                                          child: AddressWidget(
                                                            address: address,
                                                            showDivider: index !=
                                                                state.latestTwoPreviousRidesWithoutCancellation
                                                                        .length -
                                                                    1,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              );
                                      } else if (state
                                          is PreviousRidesLoading) {
                                        return const Center(
                                            child: Text('Loading'));
                                      } else {
                                        return const SizedBox.shrink();
                                      }
                                    },
                                  ),

                                  // Share location poster
                                  GestureDetector(
                                    onTap: () {
                                      _homeCubit
                                          .requestLocationPermissionAndEnableLocation(
                                        context,
                                        showLocationAlreadyOnMessage: true,
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(
                                          12,
                                        ),
                                      ),
                                      child: Container(
                                        height: 140,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.green[800],
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 7,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        16, 0, 16, 8),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Want better pickups?',
                                                      style: textTheme.bodyLarge
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          'Share your location',
                                                          style: textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        const Icon(
                                                          Icons
                                                              .arrow_forward_ios_rounded,
                                                          size: 14,
                                                          color: Colors.white,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Container(
                                                padding: const EdgeInsets.only(
                                                  top: 16,
                                                  left: 16,
                                                ),
                                                color: Colors.green[900],
                                                alignment:
                                                    Alignment.bottomRight,
                                                child: Image.asset(
                                                  'assets/images/person_with_binocular.png',
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (homeState is HomeLoading)
                    Container(
                      color: colorScheme.primary.withOpacity(.6),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.color = Palette.primary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: color == Palette.primary
                            ? const Color(0xFF1A1A2E)
                            : color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
