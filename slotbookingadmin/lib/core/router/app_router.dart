import 'package:slotbookingadmin/core/api/session_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:slotbookingadmin/Admin/admin_shell.dart';

import 'package:slotbookingadmin/Admin/dashboard/admin_dashboard_screen.dart';
import 'package:slotbookingadmin/Admin/ground/add_edit_ground_screen.dart';
import 'package:slotbookingadmin/Admin/ground/my_grounds_screen.dart';
import 'package:slotbookingadmin/Admin/profile/admin_profile_screen.dart';
import 'package:slotbookingadmin/Admin/revenue/revenue_report_screen.dart';
import 'package:slotbookingadmin/Admin/slot_bookings/admin_addslot.dart';
import 'package:slotbookingadmin/Admin/slot_bookings/admin_slotview.dart';
import 'package:slotbookingadmin/features/auth/screens/login_screen.dart';
import 'package:slotbookingadmin/features/auth/screens/register_screen.dart';
import 'package:slotbookingadmin/features/auth/screens/splash_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',

  redirect: (context, state) {
    final loggedIn = SessionManager.currentToken?.isNotEmpty == true;

    final publicRoutes = [
      '/',
      '/role-selection',
      '/admin/login',
      '/user/login'
          '/user/otp',
      '/admin/register',
      '/user/register',
      '/master/register',
    ];

    final isPublic = publicRoutes.contains(state.uri.path);

    if (!loggedIn && !isPublic) {
      return '/';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),

    GoRoute(
      path: '/admin/login',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'admin';
        return AdminLoginScreen();
      },
    ),

    GoRoute(
      path: '/admin/register',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'admin';
        return AdminRegisterScreen();
      },
    ),

    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) {
        return const AdminShell(child: AdminDashboardScreen());
      },
    ),

    GoRoute(
      path: '/admin/slotmanagement',
      builder: (context, state) {
        return const AdminShell(child: AddSlotScreen());
      },
    ),
    GoRoute(
      path: '/admin/slot',
      builder: (context, state) {
        return const AdminShell(child: AdminBookingsScreen());
      },
    ),
    GoRoute(
      path: '/admin/addgrounds',
      builder: (context, state) {
        return const AdminShell(child: AddGroundScreen());
      },
    ),
    GoRoute(
      path: '/admin/grounds',
      builder: (context, state) {
        return const AdminShell(child: AdminGroundsScreen());
      },
    ),

    GoRoute(
      path: '/admin/revenue',
      builder: (context, state) {
        final adminId = SessionManager.currentUserId;
        return AdminShell(child: AdminRevenueScreen(adminId: adminId));
      },
    ),

    GoRoute(
      path: '/admin/profile',
      builder: (context, state) {
        return const AdminShell(child: AdminProfileScreen());
      },
    ),
  ],
);
