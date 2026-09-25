import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slotbookingadmin/core/router/app_router.dart';
import 'package:slotbookingadmin/core/api/session_manager.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionManager.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'GroundBook',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    routerConfig: router,
  );
}
