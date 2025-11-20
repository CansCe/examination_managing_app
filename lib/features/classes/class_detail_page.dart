import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../services/atlas_service.dart';
import '../../services/api_service.dart';
import '../../utils/dialog_helper.dart';
import '../exams/exam_edit_page.dart';

class ClassDetailPage extends StatefulWidget {
  final String className;
  final String? teacherId;
  final String? adminId;

  const ClassDetailPage({
    super.key,
    required this.className,
    this.teacherId,
    this.adminId,
  });

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  List<Student> _students = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStudents);
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final students = await AtlasService.getStudentsByClass(
        className: widget.className,
        page: 0,
        limit: 1000,
      );

      if (mounted) {
        setState(() {
          _students = students;
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
          title: 'Error Loading Students',
          message: 'An error occurred while loading students: $e',
        );
      }
    }
  }

  void _filterStudents() {
    setState(() {
      // Filtering is handled in the build method
    });
  }

  List<Student> get _filteredStudents {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      return _students;
    }
    return _students.where((student) {
      return student.fullName.toLowerCase().contains(query) ||
          student.rollNumber.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _makeExamForClass() async {
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
        title: Text('Create Exam for ${widget.className}'),
        content: Text(
          'This will create a new exam and automatically assign all students from ${widget.className} class (${_students.length} students). Continue?',
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

      // Assign all students to the exam
      try {
        setState(() {
          _isLoading = true;
        });

        int successCount = 0;
        for (final student in _students) {
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
                'Exam created! Assigned $successCount out of ${_students.length} students from ${widget.className}.',
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
          content: Text('Exam created! Please assign students from ${widget.className} class manually.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        actions: [
          if (widget.teacherId != null || widget.adminId != null)
            IconButton(
              icon: const Icon(Icons.assignment),
              tooltip: 'Make Exam',
              onPressed: _makeExamForClass,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
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
                hintText: 'Search students...',
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
          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total Students', '${_students.length}'),
                _buildStatCard('Displayed', '${_filteredStudents.length}'),
              ],
            ),
          ),
          // Student list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                    ? const Center(
                        child: Text(
                          'No students found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  student.fullName.isNotEmpty
                                      ? student.fullName[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(
                                student.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Roll: ${student.rollNumber}'),
                                  if (student.email.isNotEmpty)
                                    Text(
                                      'Email: ${student.email}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.chat),
                                tooltip: 'Start Chat',
                                onPressed: () {
                                  // TODO: Implement chat functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Chat functionality coming soon'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

