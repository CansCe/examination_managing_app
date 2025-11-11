import 'package:flutter/material.dart';
import '../../services/index.dart';
import '../../models/index.dart';

class AdminTeacherListPage extends StatefulWidget {
  final String adminId;
  
  const AdminTeacherListPage({Key? key, required this.adminId}) : super(key: key);

  @override
  State<AdminTeacherListPage> createState() => _AdminTeacherListPageState();
}

class _AdminTeacherListPageState extends State<AdminTeacherListPage> {
  List<Teacher> _allTeachers = [];
  List<Teacher> _filteredTeachers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterTeachers);
    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTeachers() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredTeachers = _allTeachers;
      });
    } else {
      setState(() {
        _filteredTeachers = _allTeachers.where((teacher) {
          final nameMatch = teacher.fullName.toLowerCase().contains(query);
          final emailMatch = teacher.email.toLowerCase().contains(query);
          final deptMatch = teacher.department.toLowerCase().contains(query);
          final idMatch = teacher.id.toHexString().toLowerCase().contains(query);
          return nameMatch || emailMatch || deptMatch || idMatch;
        }).toList();
      });
    }
  }

  Future<void> _loadTeachers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Teacher> allTeachers = [];
      int page = 0;
      const int limit = 100;
      bool hasMore = true;
      
      while (hasMore) {
        final batch = await AtlasService.findTeachers(page: page, limit: limit);
        if (batch.isEmpty) {
          hasMore = false;
        } else {
          allTeachers.addAll(batch);
          if (batch.length < limit) {
            hasMore = false;
          } else {
            page++;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _allTeachers = allTeachers;
          _filteredTeachers = allTeachers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading teachers: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editTeacher(Teacher teacher) async {
    final firstNameController = TextEditingController(text: teacher.firstName);
    final lastNameController = TextEditingController(text: teacher.lastName);
    final emailController = TextEditingController(text: teacher.email);
    final departmentController = TextEditingController(text: teacher.department);
    final usernameController = TextEditingController(text: teacher.username);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Teacher'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final success = await AtlasService.updateTeacher(
                  teacherId: teacher.id.toHexString(),
                  name: '${firstNameController.text.trim()} ${lastNameController.text.trim()}',
                  email: emailController.text.trim(),
                  department: departmentController.text.trim(),
                );

                if (mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Teacher updated successfully')),
                    );
                    _loadTeachers(); // Refresh list
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to update teacher')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeachers,
            tooltip: 'Refresh',
          ),
        ],
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
                    hintText: 'Search by name, email, department, or ID...',
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
          // Teacher List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTeachers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No teachers found'
                                  : 'No teachers match your search',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _filteredTeachers.length,
                        itemBuilder: (context, index) {
                          final teacher = _filteredTeachers[index];
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  teacher.fullName.isNotEmpty
                                      ? teacher.fullName[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(
                                teacher.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Department: ${teacher.department}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  Text(
                                    'Email: ${teacher.email}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editTeacher(teacher),
                                tooltip: 'Edit Teacher',
                                color: Colors.blue,
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
}

