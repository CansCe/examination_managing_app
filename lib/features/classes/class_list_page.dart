import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State,Center;
import '../../models/index.dart';
import '../../services/atlas_service.dart';
import '../../services/api_service.dart';
import '../../utils/dialog_helper.dart';
import '../exams/exam_edit_page.dart';
import '../admin/admin_student_exam_assignment_page.dart';

class ClassListPage extends StatefulWidget {
  final String? teacherId;
  final String? adminId;

  const ClassListPage({
    super.key,
    this.teacherId,
    this.adminId,
  });

  @override
  State<ClassListPage> createState() => _ClassListPageState();
}

class _ClassListPageState extends State<ClassListPage> {
  List<Map<String, dynamic>> _classes = [];
  Map<String, int> _classStudentCounts = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterClasses);
    _loadClasses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // For teachers, only load classes they teach
      final classes = await AtlasService.getAllClasses(
        teacherId: widget.teacherId,
      );
      
      // Extract class names and student counts from class objects
      final counts = <String, int>{};
      for (final classData in classes) {
        final className = classData['className'] as String? ?? '';
        final numStudent = classData['numStudent'] as int? ?? 0;
        counts[className] = numStudent;
      }

      if (mounted) {
        setState(() {
          _classes = classes;
          _classStudentCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Loading Classes',
          message: 'An error occurred while loading classes: $e',
        );
      }
    }
  }

  void _filterClasses() {
    setState(() {
      // Filtering is handled in the build method
    });
  }

  List<Map<String, dynamic>> get _filteredClasses {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      return _classes;
    }
    return _classes.where((classData) {
      final className = classData['className'] as String? ?? '';
      return className.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _makeExamForClass(String className) async {
    // Navigate to exam creation page with pre-selected class
    final creatorId = widget.teacherId ?? widget.adminId;
    if (creatorId == null || creatorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create exam: missing teacher/admin ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Exam for $className'),
        content: Text(
          'This will create a new exam and automatically assign all students from $className class (${_classStudentCounts[className] ?? 0} students). Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create Exam'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Get teacher's subjects if teacher
    List<String> teacherSubjects = [];
    if (widget.teacherId != null && widget.teacherId!.isNotEmpty) {
      try {
        final api = ApiService();
        final teacherData = await api.getTeacher(widget.teacherId!);
        api.close();
        if (teacherData != null) {
          final teacher = Teacher.fromMap(teacherData);
          teacherSubjects = teacher.subjects;
        }
      } catch (e) {
        // Continue without subject filtering if error
      }
    }

    // Navigate to exam creation page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamEditPage(
          examId: null,
          teacherId: widget.teacherId,
          adminId: widget.adminId,
          teacherSubjects: teacherSubjects,
        ),
      ),
    );

    // If exam was created, get the exam and assign students
    if (result is String && mounted) {
      // result contains the exam ID
      final examId = result;
      
      // Get all students from the class
      try {
        setState(() {
          _isLoading = true;
        });

        final students = await AtlasService.getStudentsByClass(
          className: className,
          page: 0,
          limit: 1000,
        );

        // Assign all students to the exam
        int successCount = 0;
        for (final student in students) {
          try {
            final success = await AtlasService.assignStudentToExam(
              studentId: student.id,
              examId: examId,
            );
            if (success) successCount++;
          } catch (e) {
            // Continue with other students
          }
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Exam created! Assigned $successCount out of ${students.length} students from $className.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          DialogHelper.showErrorDialog(
            context: context,
            title: 'Error Assigning Students',
            message: 'Exam was created but there was an error assigning students: $e',
          );
        }
      }
    } else if (result == true && mounted) {
      // Exam was created but we don't have the ID
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exam created! Please assign students from $className class manually.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _viewClassStudents(String className) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final students = await AtlasService.getStudentsByClass(
        className: className,
        page: 0,
        limit: 1000,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show dialog with class students
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Students in $className'),
            content: SizedBox(
              width: double.maxFinite,
              child: students.isEmpty
                  ? const Text('No students found in this class.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              student.fullName.isNotEmpty
                                  ? student.fullName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(student.fullName),
                          subtitle: Text('Roll: ${student.rollNumber}'),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Loading Students',
          message: 'An error occurred while loading students: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Classes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClasses,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search classes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          // Class list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredClasses.isEmpty
                    ? const Center(
                        child: Text(
                          'No classes found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredClasses.length,
                        itemBuilder: (context, index) {
                          final classData = _filteredClasses[index];
                          final className = classData['className'] as String? ?? '';
                          final studentCount = _classStudentCounts[className] ?? 0;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: Text(
                                  className.isNotEmpty
                                      ? className[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                className,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Text(
                                '$studentCount ${studentCount == 1 ? 'student' : 'students'}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.people),
                                    tooltip: 'View Students',
                                    onPressed: () => _viewClassStudents(className),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.assignment),
                                    tooltip: 'Make Exam',
                                    color: Theme.of(context).primaryColor,
                                    onPressed: () => _makeExamForClass(className),
                                  ),
                                ],
                              ),
                              onTap: () => _viewClassStudents(className),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

