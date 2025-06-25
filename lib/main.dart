// lib/main.dart
import 'package:flutter/material.dart';
import 'config/route_generator.dart'; // Ensure this path is correct
import 'config/routes.dart';          // Ensure this path is correct

void main() {
  // Add error handling for keyboard events
  FlutterError.onError = (FlutterErrorDetails details) {
    // Filter out keyboard-related errors
    if (details.exception.toString().contains('KeyDownEvent') ||
        details.exception.toString().contains('HardwareKeyboard') ||
        details.exception.toString().contains('_pressedKeys.containsKey')) {
      // Log but don't crash the app
      print('Keyboard event error suppressed: ${details.exception}');
      return;
    }
    // Let other errors through
    FlutterError.presentError(details);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Login Demo',
      theme: ThemeData(
        // ... your theme
      ),
      initialRoute: AppRoutes.login, // Or whatever your initial route is
      // --- THIS IS THE CRUCIAL LINE ---
      onGenerateRoute: RouteGenerator.generateRoute,
      // --- MAKE SURE IT'S EXACTLY LIKE THIS ---
    );
  }
}