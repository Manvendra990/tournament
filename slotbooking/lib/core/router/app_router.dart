import 'package:slotbooking/core/api/session_manager.dart';
import 'package:go_router/go_router.dart';

import 'package:slotbooking/User/booking/bookinghistory.dart';
import 'package:slotbooking/User/booking/transaction_history.dart';
import 'package:slotbooking/User/home/dashboard.dart';
import 'package:slotbooking/User/home/ground_detail.dart';
import 'package:slotbooking/User/payments/booking_payment_screen.dart';
import 'package:slotbooking/User/profile/user_profile.dart';
import 'package:slotbooking/User/slot_selections/slot.dart';
import 'package:slotbooking/features/auth/screens/otp_screen.dart';
import 'package:slotbooking/features/auth/screens/splash_screen.dart';
import 'package:slotbooking/features/auth/screens/userlogin_screen.dart';
import 'package:slotbooking/features/auth/screens/userregister_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',

  redirect: (context, state) {
    final loggedIn = SessionManager.isLoggedIn;

    final publicRoutes = [
      '/',
      '/role-selection',
      '/admin/login',
      '/user/login',
      '/user/otp',
      '/admin/register',
      '/user/register',
      '/master/register',
    ];

    final isPublic = publicRoutes.contains(state.uri.path);

    if (!loggedIn && !isPublic) {
      return '/user/login';
    }

    if (loggedIn && state.uri.path == '/user/login') {
      return '/user/home';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),

    // ── User username/phone + password auth ─────────────────────────────────
    GoRoute(path: '/user/login', builder: (_, __) => const UserLoginScreen()),
    GoRoute(
      path: '/user/register',
      builder: (_, __) => const UserRegisterScreen(),
    ),

    // ── OTP screen — /otp?phone=+91xxxxxxxxxx ────────────────────────────────
    GoRoute(
      path: '/user/otp',
      builder: (_, state) {
        final phone = Uri.decodeComponent(
          state.uri.queryParameters['phone'] ?? '',
        );
        return OtpScreen(phoneNumber: phone);
      },
    ),

    //// user  screens
    GoRoute(
      path: '/user/home',
      builder: (context, state) {
        return HomeScreen();
      },
    ),
    GoRoute(
      path: '/user/ground_details',
      builder: (context, state) {
        final groundId = state.uri.queryParameters['groundId'] ?? '';
        return GroundDetailScreen(groundId: groundId);
      },
    ),
    GoRoute(
      path: '/user/slot',
      builder: (context, state) {
        final groundId = state.uri.queryParameters['groundId'] ?? '';
        return SlotBookingScreen(groundId: groundId);
      },
    ),
    GoRoute(
      path: '/user/payment',
      builder: (context, state) {
        final bookingData = state.extra as Map<String, dynamic>? ?? {};
        return BookingPaymentScreen(bookingData: bookingData);
      },
    ),
    GoRoute(
      path: '/user/transaction',
      builder: (context, state) {
        return TransactionHistoryScreen();
      },
    ),
    GoRoute(
      path: '/user/booking_history',
      builder: (context, state) {
        return BookingHistoryScreen();
      },
    ),
    GoRoute(
      path: '/user/profile',
      builder: (context, state) {
        return UserProfileScreen();
      },
    ),
  ],
);
