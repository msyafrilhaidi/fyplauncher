import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'user_state_manager.dart';
import 'services/app_service.dart';
import 'screens/login_screen.dart';
import 'screens/parent_home_screen.dart'; // We'll create this next
import 'screens/child_home_screen.dart'; // We'll create this next
import 'package:firebase_core/firebase_core.dart'; // Needed for initialization
import 'services/firestore_service.dart'; // <--- This is the crucial missing import
import 'firebase_options.dart';

// Imports: Add firebase_core and cloud_firestore imports

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️ Ensure this is called BEFORE any service attempts to use Firebase
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        // 1. Provide the Firestore Service first
        Provider(create: (context) => FirestoreService()),
        // 2. Provide the AppService (Platform Channel)
        Provider(create: (context) => AppService()),
        // 3. Create the UserStateManager, passing in the FirestoreService it needs
        ChangeNotifierProvider(
          create: (context) => UserStateManager(
            context.read<FirestoreService>(),
          ),
        ),
      ],
      child: const LauncherApp(),
    ),
  );
}

// ... (LauncherApp widget remains the same) ...
class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch the UserStateManager for changes to the currentMode
    final userMode = context
        .watch<UserStateManager>()
        .currentMode;

    // Conditional rendering based on the user mode (Login, Parent, Child)
    Widget homeScreen;
    switch (userMode) {
      case UserMode.parentMode:
        homeScreen = const ParentHomeScreen();
        break;
      case UserMode.childMode:
        homeScreen = const ChildHomeScreen();
        break;
      case UserMode.loggedOut:
        homeScreen = const LoginScreen();
        break;
    }

    return MaterialApp(
      title: 'Safe Launcher',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: homeScreen,
    );
  }
}
