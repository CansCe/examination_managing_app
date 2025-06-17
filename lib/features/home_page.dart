// lib/features/home_screen.dart
import 'package:flutter/material.dart';
import '../config/routes.dart'; // For AppRoutes.login
import '../models/index.dart';
import '../models/question.dart';
//import 'exam_details_page.dart';
import '../features/shared/helpdesk_chat.dart';
import '../services/atlas_service.dart';

class HomeScreen extends StatefulWidget {
  final String? username;
  final UserRole userRole;
  final String? studentId;
  final String? className;
  final String? teacherId;

  const HomeScreen({
    super.key,
    this.username,
    required this.userRole,
    this.studentId,
    this.className,
    this.teacherId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Exam> _exams = [];
  late List<Student> _students = [];
  late List<Teacher> _teachers = [];
  bool _isLoading = true;
  bool _hasMoreData = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _isInitialized = false;
  String _currentLanguage = 'English';
  String? _studentId;
  String? _className;
  String? _teacherId;
  final List<Question> _questions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.userRole == UserRole.teacher ? 3 : 1,
      vsync: this,
    );
    _loadMockData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // Get student info from arguments if available
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _studentId = args['studentId'] as String?;
        _className = args['className'] as String?;
        _teacherId = args['teacherId'] as String?;
      } else if (widget.teacherId != null) {
        _teacherId = widget.teacherId;
      }
      _isInitialized = true;
      _loadData();
    }
  }

  Future<void> _loadMockData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize Atlas connection
      await AtlasService.init();

      if (widget.userRole == UserRole.student && widget.studentId != null) {
        // For students, load only their assigned exams on initial data load
        final assignedExams = await AtlasService.getStudentExams(
          studentId: widget.studentId!,
          page: _currentPage,
          limit: _pageSize,
        );
        setState(() {
          _exams = assignedExams;
          _hasMoreData = assignedExams.length == _pageSize; // Adjust hasMoreData based on this initial load
        });
      } else {
        // For teachers or if studentId is not available, load all relevant data
        final teachers = await AtlasService.findTeachers();
        final students = await AtlasService.findStudents();
        final exams = await AtlasService.findExams();

        setState(() {
          _teachers = teachers;
          _students = students;
          _exams = exams;
        });
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      setState(() {
        _currentPage = 0;
        _exams.clear();
        _students.clear();
        _teachers.clear();
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.userRole == UserRole.teacher) {
        await _loadTeacherData();
      } else {
        // For students, load their exams
        final studentExams = await AtlasService.getStudentExams(
          studentId: widget.username!,
          page: _currentPage,
          limit: _pageSize,
        );

        if (!mounted) return;

        setState(() {
          _exams.addAll(studentExams);
          _hasMoreData = studentExams.length == _pageSize;
          _currentPage++;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
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

  Future<void> _loadTeacherData() async {
    if (!mounted || _isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      print('_loadTeacherData called for username: ${widget.username}');
      // First get the teacher's ID from their username
      final teacher = await AtlasService.findTeacherByUsername(widget.username!);
      if (teacher == null) {
        print('Teacher not found for username: ${widget.username}');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      // Get the teacher's ID and ensure it's a string
      final teacherId = teacher['_id'].toHexString();
      print('Found teacher ID: $teacherId');
      // Get teacher's exams using their ID
      final exams = await AtlasService.getTeacherExams(
        teacherId: teacherId,
        page: _currentPage,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (_currentPage == 0) {
          _exams = exams;
        } else {
          _exams.addAll(exams);
        }
        _hasMoreData = exams.length == _pageSize;
        if (_hasMoreData) _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading teacher data: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading teacher data: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.userRole == UserRole.teacher) {
        await _loadTeacherData();
      } else {
        await _loadData();
      }
    } catch (e) {
      print('Error loading more data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more data: $e')),
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username != null ? 'Welcome, ${widget.username}!' : 'Home Page',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 20,
                  ),
                ),
                Text(
                  widget.userRole == UserRole.teacher ? 'Teacher Dashboard' : 'Student Dashboard',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            actions: [
              if (widget.userRole == UserRole.teacher)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Create Exam',
                  onPressed: _createNewExam,
                ),
              IconButton(
                icon: const Icon(Icons.support_agent),
                tooltip: 'Helpdesk',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const HelpdeskChat(),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () {
                  _showSettingsDialog(context);
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: MediaQuery.of(context).size.width < 600,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment),
                      if (MediaQuery.of(context).size.width >= 600) const SizedBox(width: 8),
                      if (MediaQuery.of(context).size.width >= 600) const Text('Exams'),
                    ],
                  ),
                ),
                if (widget.userRole == UserRole.teacher) ...[
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people),
                        if (MediaQuery.of(context).size.width >= 600) const SizedBox(width: 8),
                        if (MediaQuery.of(context).size.width >= 600) const Text('Students'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school),
                        if (MediaQuery.of(context).size.width >= 600) const SizedBox(width: 8),
                        if (MediaQuery.of(context).size.width >= 600) const Text('Teachers'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          body: _isLoading && _currentPage == 0
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildExamsList(MediaQuery.of(context).size.width < 600),
                    if (widget.userRole == UserRole.teacher) ...[
                      _buildStudentsList(MediaQuery.of(context).size.width < 600),
                      _buildTeachersList(MediaQuery.of(context).size.width < 600),
                    ],
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (widget.userRole == UserRole.teacher) {
                _loadTeacherData();
              } else {
                _loadData(refresh: true);
              }
            },
            child: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }

  Widget _buildExamsList(bool isSmallScreen) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadMoreData();
        }
        return true;
      },
      child: isSmallScreen
          ? ListView.builder(
              itemCount: _exams.length + (_hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _exams.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final exam = _exams[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(
                      exam.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${exam.subject} - ${exam.examDate.toString().split(' ')[0]}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: SizedBox(
                      width: widget.userRole == UserRole.teacher ? 180 : 80,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.userRole == UserRole.teacher) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _editExam(exam),
                              tooltip: 'Edit Exam',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.access_time, size: 20),
                              onPressed: () => _delayExam(exam),
                              tooltip: 'Delay Exam',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, size: 20),
                              onPressed: () => _cancelExam(exam),
                              tooltip: 'Cancel Exam',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                          Expanded(
                            child: Chip(
                              label: Text(
                                exam.status ?? 'scheduled',
                                overflow: TextOverflow.ellipsis,
                              ),
                              backgroundColor: (exam.status ?? 'scheduled') == 'scheduled' ? Colors.blue : Colors.green,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () => _navigateToExamDetails(exam),
                  ),
                );
              },
            )
          : GridView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 16, left: 16, right: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _exams.length + (_hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _exams.length) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final exam = _exams[index];
                return Card(
                  child: InkWell(
                    onTap: () => _navigateToExamDetails(exam),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              exam.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: Text(
                              'Subject: ${exam.subject}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              'Date: ${exam.examDate.toString().split(' ')[0]}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (widget.userRole == UserRole.teacher)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _editExam(exam),
                                  tooltip: 'Edit Exam',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.access_time, size: 18),
                                  onPressed: () => _delayExam(exam),
                                  tooltip: 'Delay Exam',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, size: 18),
                                  onPressed: () => _cancelExam(exam),
                                  tooltip: 'Cancel Exam',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          const SizedBox(height: 2),
                          Chip(
                            label: Text(
                              exam.status ?? 'scheduled',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            backgroundColor: (exam.status ?? 'scheduled') == 'scheduled' ? Colors.blue : Colors.green,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStudentsList(bool isSmallScreen) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadMoreData();
        }
        return true;
      },
      child: isSmallScreen
          ? ListView.builder(
              itemCount: _students.length + (_hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _students.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final student = _students[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(
                      student.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${student.className} - ${student.rollNumber}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      student.email,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            )
          : GridView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 16, left: 16, right: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _students.length + (_hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _students.length) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final student = _students[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            student.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            'Class: ${student.className}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Roll Number: ${student.rollNumber}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Email: ${student.email}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTeachersList(bool isSmallScreen) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadMoreData();
        }
        return true;
      },
      child: isSmallScreen
          ? ListView.builder(
              itemCount: _teachers.length + (_hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _teachers.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final teacher = _teachers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(
                      teacher.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      teacher.department,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      teacher.subjects.join(', '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            )
          : GridView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 16, left: 16, right: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _teachers.length + (_hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _teachers.length) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final teacher = _teachers[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            teacher.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            'Department: ${teacher.department}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'Subjects: ${teacher.subjects.join(', ')}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _navigateToExamDetails(Exam exam) {
    Navigator.pushNamed(
      context,
      AppRoutes.examDetails,
      arguments: {
        'exam': exam,
        'onExamUpdated': () => _loadData(refresh: true),
        'onExamDeleted': () => _loadData(refresh: true),
      },
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Use a StatefulWidget inside the dialog to manage language selection state
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Settings'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    const Text('Change Language:'),
                    DropdownButton<String>(
                      value: _currentLanguage,
                      isExpanded: true,
                      items: <String>['English', 'Spanish', 'French', 'German']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateDialog(() {
                            _currentLanguage = newValue;
                          });
                          // In a real app, you would persist this and update your app's locale
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Language changed to $_currentLanguage (UI placeholder)')),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      child: const Text('Logout', style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close settings dialog
                        _confirmLogout(context);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () {
                Navigator.of(context).pop(); // Close confirmation dialog
                // Navigate to login screen and remove all previous routes
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                      (Route<dynamic> route) => false, // Removes all routes
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _editExam(Exam exam) {
    Navigator.pushNamed(
      context,
      AppRoutes.examEdit,
      arguments: {
        'exam': exam,
        'teacherId': _teacherId,
      },
    ).then((_) => _loadData(refresh: true));
  }

  void _createNewExam() {
    Navigator.pushNamed(
      context,
      AppRoutes.examEdit,
      arguments: {
        'teacherId': _teacherId,
      },
    ).then((_) => _loadData(refresh: true));
  }

  void _delayExam(Exam exam) {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delay Exam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select new date and time for the exam:'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date'),
              subtitle: Text(selectedDate?.toString().split(' ')[0] ?? 'Select date'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: exam.examDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  selectedDate = date;
                  Navigator.pop(context);
                  _delayExam(exam);
                }
              },
            ),
            ListTile(
              title: const Text('Time'),
              subtitle: Text(selectedTime?.format(context) ?? 'Select time'),
              onTap: () async {
                TimeOfDay initialTime;
                try {
                  if (exam.examTime.contains(':')) {
                    final parts = exam.examTime.split(':');
                    if (parts.length == 2) {
                      initialTime = TimeOfDay(
                        hour: int.parse(parts[0]),
                        minute: int.parse(parts[1]),
                      );
                    } else {
                      initialTime = const TimeOfDay(hour: 9, minute: 0);
                    }
                  } else {
                    initialTime = const TimeOfDay(hour: 9, minute: 0);
                  }
                } catch (e) {
                  initialTime = const TimeOfDay(hour: 9, minute: 0);
                }

                final time = await showTimePicker(
                  context: context,
                  initialTime: initialTime,
                );
                if (time != null) {
                  selectedTime = time;
                  Navigator.pop(context);
                  _delayExam(exam);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (selectedDate == null || selectedTime == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select both date and time')),
                );
                return;
              }

              final newDate = DateTime(
                selectedDate!.year,
                selectedDate!.month,
                selectedDate!.day,
                selectedTime!.hour,
                selectedTime!.minute,
              );

              try {
                final success = await AtlasService.updateExam(
                  examId: exam.id.toString(),
                  status: 'delayed',
                  newDate: newDate,
                );

                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exam delayed successfully')),
                  );
                  _loadData(refresh: true);
                } else {
                  throw Exception('Failed to delay exam');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error delaying exam: $e')),
                );
              }
            },
            child: const Text('Delay'),
          ),
        ],
      ),
    );
  }

  void _cancelExam(Exam exam) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Exam'),
        content: const Text('Are you sure you want to cancel this exam? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final success = await AtlasService.updateExamStatus(
                  examId: exam.id.toString(),
                  status: 'cancelled',
                );

                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exam cancelled successfully')),
                  );
                  _loadData(refresh: true);
                } else {
                  throw Exception('Failed to cancel exam');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error cancelling exam: $e')),
                );
              }
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}