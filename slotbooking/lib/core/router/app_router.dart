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
import 'package:slotbooking/features/auth/screens/userlogin_screen.dart';
import 'package:slotbooking/features/auth/screens/userregister_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',

  redirect: (context, state) {
    final loggedIn = SessionManager.isLoggedIn;

    final path = state.uri.path;

    final publicRoutes = [
      '/user/login',
      '/user/register',
      '/user/otp',
      '/admin/login',
      '/admin/register',
      '/master/register',
      '/role-selection',
    ];

    // App root "/" par aaye
    if (path == '/') {
      return loggedIn ? '/user/home' : '/user/login';
    }

    final isPublic = publicRoutes.contains(path);

    // Not logged in → protected screen access block
    if (!loggedIn && !isPublic) {
      return '/user/login';
    }

    // Already logged in → login/register dobara na dikhao
    if (loggedIn && (path == '/user/login' || path == '/user/register')) {
      return '/user/home';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),

    GoRoute(path: '/user/login', builder: (_, _) => const UserLoginScreen()),

    GoRoute(
      path: '/user/register',
      builder: (_, _) => const UserRegisterScreen(),
    ),

    GoRoute(
      path: '/user/otp',
      builder: (_, state) {
        final phone = Uri.decodeComponent(
          state.uri.queryParameters['phone'] ?? '',
        );

        return OtpScreen(phoneNumber: phone);
      },
    ),

    GoRoute(
      path: '/user/home',
      builder: (context, state) => const HomeScreen(),
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
      builder: (context, state) => TransactionHistoryScreen(),
    ),

    GoRoute(
      path: '/user/booking_history',
      builder: (context, state) => BookingHistoryScreen(),
    ),

    GoRoute(
      path: '/user/profile',
      builder: (context, state) => UserProfileScreen(),
    ),
  ],
);
