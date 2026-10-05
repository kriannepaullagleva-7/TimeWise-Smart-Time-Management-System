import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/preferences_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/splash/loading_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';

/// Developer switch: `--dart-define=USE_FIREBASE_EMULATOR=true` points the app
/// at the Firebase Local Emulator Suite (a throw-away local backend) instead
/// of the real project. Off by default.
const bool _useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
const String _emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '10.0.2.2');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline persistence keeps the app usable on poor connections: Firestore
  // serves from its local cache and syncs when connectivity returns.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (_useEmulator) {
    AppLogger.warning('main', 'Using the Firebase emulators on $_emulatorHost');
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, 9199);
  }

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
        ChangeNotifierProvider(create: (_) => PreferencesProvider()),
        // One shared task subscription, restarted whenever the signed-in user
        // changes, and gated by the "Task Reminders" switch.
        ChangeNotifierProxyProvider2<AuthProvider, PreferencesProvider, TaskProvider>(
          create: (_) => TaskProvider(),
          update: (_, auth, prefs, tasks) => tasks!
            ..setRemindersEnabled(prefs.taskReminders)
            ..attachUser(auth.currentUser?.uid),
        ),
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
              debugShowCheckedModeBanner: false,
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );
          }
          return MaterialApp(
            title: 'TimeWise',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(accentColor: themeProvider.accentColor),
            darkTheme: AppTheme.dark(accentColor: themeProvider.accentColor),
            themeMode: themeProvider.themeMode,
            // On tablets and landscape the content keeps a phone-like column
            // instead of stretching across the whole screen.
            builder: (context, child) => ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: child,
                ),
              ),
            ),
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
