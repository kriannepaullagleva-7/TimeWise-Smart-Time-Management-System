import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/focus_provider.dart';
import 'screens/splash/loading_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    AppLogger.warning('main', 'Failed to load .env file', e);
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable offline persistence so the app remains usable on poor connections.
  // Firestore will serve from its local cache and sync when connectivity returns.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  try {
    await NotificationService().initNotifications();
  } catch (e) {
    // Local notifications are a supporting feature; don't block app startup
    // if the platform plugin fails to initialize on a given device.
    AppLogger.warning('main', 'Failed to initialize notifications', e);
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<TaskProvider, FocusProvider>(
          create: (_) => FocusProvider(),
          update: (_, taskProvider, focusProvider) => focusProvider!..updateTaskProvider(taskProvider),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          if (!themeProvider.isReady) {
            return const MaterialApp(
              home: Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return MaterialApp(
            title: 'TimeWise',
            theme: AppTheme.light(accentColor: themeProvider.accentColor),
            darkTheme: AppTheme.dark(accentColor: themeProvider.accentColor),
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
          );
        },
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
