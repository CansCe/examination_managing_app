import 'package:flutter/material.dart';
import '../../models/index.dart';
import '../../services/atlas_service.dart';

class AdminStudentExamAssignmentPage extends StatefulWidget {
  final String examId;
  final Exam exam;

  const AdminStudentExamAssignmentPage({
    super.key,
    required this.examId,
    required this.exam,
  });

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
  final TextEditingController _idsInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStudents);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _idsInputController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all students with pagination (backend max limit is 100)
      List<Student> allStudents = [];
      int page = 0;
      const int limit = 100; // Max allowed by backend
      bool hasMore = true;
      
      while (hasMore) {
        final batch = await AtlasService.findStudents(page: page, limit: limit);
        if (batch.isEmpty) {
          hasMore = false;
        } else {
          allStudents.addAll(batch);
          // If we got fewer than the limit, we've reached the end
          if (batch.length < limit) {
            hasMore = false;
          } else {
            page++;
          }
        }
      }
      
      final assignedStudents =
          await AtlasService.getStudentsAssignedToExam(examId: widget.examId);

      // Keep assigned list in state; no need for a separate set

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
            backgroundColor: isAssigned ? Colors.red : Colors.green,
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

  Future<void> _assignByIds() async {
    final raw = _idsInputController.text.trim();
    if (raw.isEmpty) return;
    final List<String> tokens = raw
        .split(RegExp(r"[\s,]+"))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    int successCount = 0;
    int notFoundCount = 0;
    for (final token in tokens) {
      // Match by rollNumber or by id
      final candidates = _allStudents.where((s) =>
          s.rollNumber.toLowerCase() == token.toLowerCase() ||
          s.id.toLowerCase() == token.toLowerCase());
      if (candidates.isEmpty) {
        notFoundCount++;
        continue;
      }
      final match = candidates.first;
      try {
        final alreadyAssigned = _assignedStudents.any((s) => s.id == match.id);
        if (!alreadyAssigned) {
          final ok = await AtlasService.assignStudentToExam(
            studentId: match.id,
            examId: widget.examId,
          );
          if (ok) successCount++;
        }
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added: $successCount, Not found/Skipped: $notFoundCount'),
        ),
      );
      _idsInputController.clear();
      await _loadData();
    }
  }

  Future<void> _assignByClass(String className) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get all students from the class
      final classStudents = await AtlasService.getStudentsByClass(
        className: className,
        page: 0,
        limit: 1000,
      );

      // Assign all students from the class who are not already assigned
      int successCount = 0;
      int alreadyAssignedCount = 0;

      for (final student in classStudents) {
        try {
          final alreadyAssigned = _assignedStudents.any((s) => s.id == student.id);
          if (!alreadyAssigned) {
            final ok = await AtlasService.assignStudentToExam(
              studentId: student.id,
              examId: widget.examId,
            );
            if (ok) successCount++;
          } else {
            alreadyAssignedCount++;
          }
        } catch (e) {
          // Continue with other students
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assigned $successCount students from $className. '
              '${alreadyAssignedCount > 0 ? "$alreadyAssignedCount were already assigned." : ""}',
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
            content: Text('Error assigning students by class: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showClassSelectionDialog() async {
    try {
      final classes = await AtlasService.getAllClasses();
      
      if (classes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No classes found.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!mounted) return;

      final selectedClass = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Class'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final className = classes[index];
                return ListTile(
                  title: Text(className),
                  onTap: () => Navigator.pop(context, className),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedClass != null && mounted) {
        await _assignByClass(selectedClass);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading classes: $e'),
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
            const Text(
              'Manage Student Assignments',
              style: TextStyle(fontSize: 12),
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
          // Bulk assign by IDs and Class
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _idsInputController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter Student IDs (comma, space or newline separated)',
                          prefixIcon: const Icon(Icons.playlist_add),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _assignByIds,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add by IDs'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _showClassSelectionDialog,
                    icon: const Icon(Icons.group),
                    label: const Text('Assign All Students by Class'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total Students', '${_allStudents.length}'),
                // _buildStatCard(
                //     'Assigned', '${_assignedStudents.length}', Colors.green),
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

