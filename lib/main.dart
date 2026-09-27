import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/schedule_provider.dart';
import 'screens/splash/loading_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await NotificationService().initNotifications();
  } catch (e) {
    // Local notifications are a supporting feature; don't block app startup
    // if the platform plugin fails to initialize on a given device.
    debugPrint('Failed to initialize notifications: $e');
  }

  runApp(const TimeWiseApp());
}

class TimeWiseApp extends StatelessWidget {
  const TimeWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
      ],
      child: MaterialApp(
        title: 'TimeWise',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isReady) {
          return const LoadingScreen();
        }

        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }

        return const WelcomeScreen();
      },
    );
  }
}
