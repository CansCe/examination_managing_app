import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'routes.dart';
import '../models/user.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../features/login_page.dart';
import '../features/home_page.dart';
import '../features/exams/exam_edit_page.dart';
import '../features/exam_details_page.dart';
import '../features/examination_page.dart';
import '../features/questions/question_edit_page.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case AppRoutes.home:
        // Expecting arguments as a Map: {'username': String, 'role': UserRole}
        if (args is Map<String, dynamic>) {
          final String? username = args['username'] as String?;
          final UserRole? role = args['role'] as UserRole?;

          if (role != null) {
            return MaterialPageRoute(
              builder: (_) => HomeScreen(
                username: username,
                userRole: role,
              ),
            );
          }
        }
        return _errorRoute('Invalid arguments for Home Page. Role is required.');

      case AppRoutes.examEdit:
        if (args is Map<String, dynamic>) {
          final UserRole? role = args['userRole'] as UserRole?;
          // Check if user is a teacher
          if (role != UserRole.teacher) {
            return _errorRoute('Access Denied: Only teachers can create or edit exams.');
          }
          final String? examId = args['examId'] as String?;
          final String teacherId = args['teacherId'] as String;
          return MaterialPageRoute(
            builder: (_) => ExamEditPage(
              examId: examId,
              teacherId: teacherId,
            ),
          );
        }
        return _errorRoute('Invalid arguments for Exam Edit Page');

      case AppRoutes.examDetails:
        if (args is Map<String, dynamic>) {
          final Exam exam = args['exam'] as Exam;
          final Function() onExamUpdated = args['onExamUpdated'] as Function();
          final Function() onExamDeleted = args['onExamDeleted'] as Function();
          final String? studentId = args['studentId'] as String?;
          return MaterialPageRoute(
            builder: (_) => ExamDetailsPage(
              exam: exam,
              studentId: studentId,
              // onExamUpdated: onExamUpdated,
              // onExamDeleted: onExamDeleted,
            ),
          );
        }
        return _errorRoute('Invalid arguments for Exam Details Page');

      case AppRoutes.examination:
        if (args is Map<String, dynamic>) {
          final Exam exam = args['exam'] as Exam;
          final List<Question> questions = args['questions'] as List<Question>;
          final String? studentId = args['studentId'] as String?;
          return MaterialPageRoute(
            builder: (_) => ExaminationPage(
              exam: exam,
              questions: questions,
              studentId: studentId,
            ),
          );
        }
        return _errorRoute('Invalid arguments for Examination Page');

      case AppRoutes.questionEdit:
        if (args is Map<String, dynamic>) {
          final UserRole? role = args['userRole'] as UserRole?;
          // Check if user is a teacher
          if (role != UserRole.teacher) {
            return _errorRoute('Access Denied: Only teachers can create or edit questions.');
          }
          final String? questionId = args['questionId'] as String?;
          final String teacherId = args['teacherId'] as String;
          final ObjectId? examId = args['examId'] as ObjectId?;
          return MaterialPageRoute(
            builder: (_) => QuestionEditPage(
              questionId: questionId,
              teacherId: teacherId,
              examId: examId,
            ),
          );
        }
        return _errorRoute('Invalid arguments for Question Edit Page');

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(builder: (_) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Routing Error: $message',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16)),
          ),
        ),
      );
    });
  }
} 