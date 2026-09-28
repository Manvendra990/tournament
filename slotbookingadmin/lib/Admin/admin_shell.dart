import 'package:slotbookingadmin/core/api/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminShell extends StatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShellScope(
      openDrawer: openDrawer,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const _AdminDrawer(),
        body: widget.child,
      ),
    );
  }
}

class AdminShellScope extends InheritedWidget {
  final VoidCallback openDrawer;

  const AdminShellScope({super.key, required this.openDrawer, required super.child});

  static AdminShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminShellScope>();
  }

  @override
  bool updateShouldNotify(AdminShellScope oldWidget) {
    return openDrawer != oldWidget.openDrawer;
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.currentUser;
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primary),
            accountName: Text(
              (user?['name'] ?? 'Admin').toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            accountEmail: Text((user?['email'] ?? '').toString()),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.onPrimary,
              child: Text(
                ((user?['name'] ?? 'A').toString())[0].toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  route: '/admin/dashboard',
                ),
                _DrawerItem(
                  icon: Icons.sports_soccer_outlined,
                  label: 'My grounds',
                  route: '/admin/grounds',
                ),
                _DrawerItem(
                  icon: Icons.schedule_outlined,
                  label: 'Slots & pricing',
                  route: '/admin/slot',
                ),
                _DrawerItem(
                  icon: Icons.book_online_outlined,
                  label: 'Add Slots',
                  route: '/admin/slotmanagement',
                ),
                _DrawerItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'Revenue report',
                  route: '/admin/revenue',
                ),
                const Divider(),
                _DrawerItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  route: '/admin/profile',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign out',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('keep_logged_in');
                await SessionManager.clear();
                if (context.mounted) context.go('/admin/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).uri.toString();
    final selected = current.startsWith(route);
    final color = selected ? Theme.of(context).colorScheme.primary : null;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        Navigator.pop(context);
        if (route == '/admin/profile') {
          context.push(route);
        } else {
          context.go(route);
        }
      },
    );
  }
}
