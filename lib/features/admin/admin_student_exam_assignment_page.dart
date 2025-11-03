import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../services/atlas_service.dart';

class AdminStudentExamAssignmentPage extends StatefulWidget {
  final String examId;
  final Exam exam;

  const AdminStudentExamAssignmentPage({
    Key? key,
    required this.examId,
    required this.exam,
  }) : super(key: key);

  @override
  State<AdminStudentExamAssignmentPage> createState() =>
      _AdminStudentExamAssignmentPageState();
}

class _AdminStudentExamAssignmentPageState
    extends State<AdminStudentExamAssignmentPage> {
  List<Student> _allStudents = [];
  List<Student> _assignedStudents = [];
  List<Student> _filteredStudents = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStudents);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allStudents = await AtlasService.findStudents(limit: 1000);
      final assignedStudents =
          await AtlasService.getStudentsAssignedToExam(examId: widget.examId);

      final assignedIds = assignedStudents.map((s) => s.id).toSet();

      if (mounted) {
        setState(() {
          _allStudents = allStudents;
          _assignedStudents = assignedStudents;
          _filteredStudents = allStudents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredStudents = _allStudents;
      });
    } else {
      setState(() {
        _filteredStudents = _allStudents.where((student) {
          final nameMatch = student.fullName.toLowerCase().contains(query);
          final idMatch = student.rollNumber.toLowerCase().contains(query) ||
              student.id.toLowerCase().contains(query);
          return nameMatch || idMatch;
        }).toList();
      });
    }
  }

  Future<void> _toggleStudentAssignment(Student student, bool isAssigned) async {
    try {
      bool success;
      if (isAssigned) {
        success = await AtlasService.unassignStudentFromExam(
          studentId: student.id,
          examId: widget.examId,
        );
      } else {
        success = await AtlasService.assignStudentToExam(
          studentId: student.id,
          examId: widget.examId,
        );
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAssigned
                  ? 'Student removed from exam'
                  : 'Student assigned to exam',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.exam.title),
            Text(
              'Manage Student Assignments',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by student name or ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isNotEmpty
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
                );
              },
            ),
          ),
          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total Students', '${_allStudents.length}'),
                _buildStatCard(
                    'Assigned', '${_assignedStudents.length}', Colors.green),
              ],
            ),
          ),
          // Student List
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
                          final isAssigned = _assignedStudents
                              .any((s) => s.id == student.id);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 4,
                            ),
                            color: isAssigned
                                ? Colors.green.shade50
                                : Colors.white,
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
                              subtitle: Text('${student.rollNumber} • ${student.className}'),
                              trailing: Switch(
                                value: isAssigned,
                                onChanged: (value) {
                                  _toggleStudentAssignment(student, isAssigned);
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

  Widget _buildStatCard(String label, String value, [Color? color]) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color ?? Colors.blue.shade200,
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
              color: color ?? Colors.blue.shade700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color ?? Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

