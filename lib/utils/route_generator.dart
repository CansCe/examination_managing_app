import 'package:flutter/material.dart';
import '../features/home_page.dart';
import '../features/login_page.dart';
import '../models/user.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Getting arguments passed in while calling Navigator.pushNamed
    final args = settings.arguments;

    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case '/home':
        // Validation of correct data type
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => HomeScreen(
              username: args['username'] as String?,
              userRole: args['userRole'] as UserRole,
              studentId: args['studentId'] as String?,
              className: args['className'] as String?,
            ),
          );
        }
        // If args is not of the correct type, return an error page.
        return _errorRoute();
      default:
        // If there is no such named route, return an error page.
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: const Center(
          child: Text('ERROR'),
        ),
      );
    });
  }
} 