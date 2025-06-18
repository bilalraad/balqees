import 'package:balqees/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AppNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const AppNavigationBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final bool isRider = authProvider.role == 'rider';
        debugPrint('Current role: ${authProvider.role}');

        // Define the indices for better readability
        // ignore: unused_local_variable
        const int homeIndex = 0;
        // ignore: unused_local_variable
        const int ordersIndex = 1;
        // ignore: unused_local_variable
        final int driverIndex = isRider ? 2 : -1;
        // ignore: unused_local_variable
        final int profileIndex = isRider ? 3 : 2;

        // Create navigation items without the search button
        List<BottomNavigationBarItem> navItems = [
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'طلباتي',
          ),
          // Center home button
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 28),
            activeIcon: Icon(Icons.home, size: 28),
            label: 'الرئيسية',
          ),
          if (isRider)
            const BottomNavigationBarItem(
              icon: Icon(Icons.delivery_dining_outlined),
              activeIcon: Icon(Icons.delivery_dining),
              label: 'السائق',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ];

        // Adjust the current index to match the new layout
        int safeCurrentIndex;
        switch (currentIndex) {
          case 0: // Home was 0, now 1
            safeCurrentIndex = 1;
            break;
          case 1: // Search was 1, now removed
            safeCurrentIndex = 1; // Default to home
            break;
          case 2: // Orders was 2, now 0
            safeCurrentIndex = 0;
            break;
          case 3: // Driver was 3 (if rider), now 2
            safeCurrentIndex = isRider ? 2 : 1; // Default to home if not rider
            break;
          case 4: // Profile was 4 (if rider) or 3, now 3 or 2
            safeCurrentIndex = isRider ? 3 : 2;
            break;
          default:
            safeCurrentIndex = 1; // Default to home
        }

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: BottomNavigationBar(
              selectedItemColor: AppColors.burntBrown,
              unselectedItemColor: Colors.grey,
              backgroundColor: Colors.white,
              elevation: 8,
              currentIndex: safeCurrentIndex,
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedFontSize: 12,
              unselectedFontSize: 10,
              iconSize: 24,
              onTap: (index) {
                if (onTap != null) onTap!(index);
                
                // Handle navigation based on the new layout
                if (index == 0) { // Orders (was at index 2)
                  Navigator.pushNamed(context, '/orders');
                } else if (index == 1) { // Home (was at index 0)
                  if (ModalRoute.of(context)?.settings.name != '/') {
                    Navigator.pushNamed(context, '/');
                  }
                } else if (isRider && index == 2) { // Driver (was at index 3)
                  Navigator.pushNamed(context, '/driver');
                } else if ((isRider && index == 3) || (!isRider && index == 2)) { // Profile
                  Navigator.pushNamed(context, '/profile');
                }
              },
              items: navItems,
            ),
          ),
        );
      },
    );
  }
}