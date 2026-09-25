import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slotbookingadmin/theme/app_colors.dart';
import 'package:slotbookingadmin/theme/app_spacing.dart';

class AdminNavBar extends StatelessWidget {
  final int currentIndex;

  const AdminNavBar({super.key, required this.currentIndex});

  static const _items = [
    _NavItem(
      icon: Icons.grid_view_rounded,
      label: 'Home',
      route: '/admin/dashboard',
    ),
    _NavItem(
      icon: Icons.grass_rounded,
      label: 'Grounds',
      route: '/admin/grounds',
    ),
    _NavItem(
      icon: Icons.access_time_rounded,
      label: 'AddSlots',
      route: '/admin/slotmanagement',
    ),
    _NavItem(
      icon: Icons.book_online_rounded,
      label: 'View-Slots',
      route: '/admin/slot',
    ),
    _NavItem(
      icon: Icons.attach_money_rounded,
      label: 'Revenue',
      route: '/admin/revenue',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md - 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = currentIndex == i;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (!isActive) context.go(item.route);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md + 2,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withOpacity(.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textSecondary.withOpacity(0.5),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textSecondary.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
