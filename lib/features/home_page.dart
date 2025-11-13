// lib/features/home_screen.dart
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State,Center;
import '../services/index.dart';
import '../config/routes.dart'; // For AppRoutes.login
import '../models/index.dart';
import '../features/index.dart';
import '../utils/dialog_helper.dart';
import '../utils/logger.dart';
import '../services/notification_service.dart';
import 'classes/class_list_page.dart';
import 'classes/class_detail_page.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class HomeScreen extends StatefulWidget {
  final String? username;
  final UserRole userRole;
  final String? studentId;
  final String? className;
  final String? teacherId;
  final String? adminId;

  const HomeScreen({
    super.key,
    this.username,
    required this.userRole,
    this.studentId,
    this.className,
    this.teacherId,
    this.adminId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  late List<Exam> _exams = [];
  late List<Student> _students = [];
  late List<Teacher> _teachers = [];
  List<String> _classes = [];
  Map<String, int> _classStudentCounts = {};
  bool _isLoading = true;
  bool _hasMoreData = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _isInitialized = false;
  String _currentLanguage = 'English';
  String? _studentId;
  String? _className;
  String? _teacherId;
  Teacher? _currentTeacher; // Store current teacher info for subject filtering
  final List<Question> _questions = [];
  // Separate lists for students: upcoming and past exams
  List<Exam> _upcomingExams = [];
  List<Exam> _pastExams = [];
  // Unread message count for chat badge
  final int _unreadMessageCount = 0;
  //Timer? _unreadMessageTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.userRole == UserRole.teacher
          ? 3
          : widget.userRole == UserRole.admin
              ? 2
              : 1,
      vsync: this,
    );
    
    // Initialize notifications for students
    if (widget.userRole == UserRole.student) {
      NotificationService().initialize();
    }
    
    _loadMockData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
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

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when coming back to this page
    if (widget.userRole == UserRole.teacher) {
      _loadTeacherData();
    } else {
      _loadData(refresh: true);
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
        
        // For students, separate upcoming and past exams
        final now = DateTime.now();
        final studentId = widget.studentId ?? widget.username;
        
        final upcomingExams = <Exam>[];
        final pastExams = <Exam>[];
        
        // Check which exams the student has completed
        final completedExamIds = <String>{};
        if (studentId != null) {
          try {
            final api = ApiService();
            final studentResults = await api.getStudentResults(studentId);
            api.close();
            
            for (final result in studentResults) {
              if (result['examId'] != null) {
                // examId might be ObjectId or string
                final examIdStr = result['examId'] is String 
                    ? result['examId'] 
                    : result['examId'].toString();
                completedExamIds.add(examIdStr);
              }
            }
          } catch (e) {
            // Silently fail - results might not be available yet
          }
        }
        
        for (final exam in assignedExams) {
          try {
            // Skip dummy exams for students (only teachers/admins can access them)
            if (exam.isDummy || exam.examTime.toUpperCase() == 'NAN') {
              continue;
            }
            
            final examId = exam.id.toHexString();
            
            // If student has completed the exam, show it as past exam
            if (completedExamIds.contains(examId)) {
              pastExams.add(exam);
              continue;
            }
            
            final examStartDateTime = exam.getExamStartDateTime();
            final examEndDateTime = exam.getExamEndDateTime();
            
            // Skip if exam has no valid start/end time
            if (examStartDateTime == null || examEndDateTime == null) {
              continue;
            }
            
            // Upcoming exams: exams that haven't started yet (or are starting now)
            if (examStartDateTime.isAfter(now) || examStartDateTime.isAtSameMomentAs(now)) {
              upcomingExams.add(exam);
            }
            // Past exams: exams that have already ended
            else if (examEndDateTime.isBefore(now)) {
              pastExams.add(exam);
            }
            // Exams currently in progress: show as upcoming
            else if (examStartDateTime.isBefore(now) && examEndDateTime.isAfter(now)) {
              upcomingExams.add(exam);
            }
          } catch (e) {
            // Silently skip exams with errors
            continue;
          }
        }
        
        // Sort upcoming exams by start date (nearest to farthest)
        if (upcomingExams.isNotEmpty) {
          upcomingExams.sort((a, b) {
            final aStart = a.getExamStartDateTime();
            final bStart = b.getExamStartDateTime();
            if (aStart == null || bStart == null) return 0;
            return aStart.compareTo(bStart);
          });
        }
        
        setState(() {
          _upcomingExams = upcomingExams;
          _pastExams = pastExams;
          _exams = pastExams; // Use _exams for past exams list
          _hasMoreData = assignedExams.length == _pageSize;
        });
      } else {
        // For teachers and admins, load all relevant data in parallel for faster loading
        final results = await Future.wait([
          AtlasService.findTeachers(),
          AtlasService.findStudents(),
          AtlasService.findExams(),
        ]);

        setState(() {
          _teachers = results[0] as List<Teacher>;
          _students = results[1] as List<Student>;
          _exams = results[2] as List<Exam>;
        });
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Show error message
      if (mounted) {
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Loading Data',
          message: 'An error occurred while loading data: $e',
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
        _upcomingExams.clear();
        _pastExams.clear();
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.userRole == UserRole.teacher) {
        await _loadTeacherData();
      } else if (widget.userRole == UserRole.admin) {
        // For admins, load all exams
        final exams = await AtlasService.findExams();
        final students = await AtlasService.findStudents();
        
        if (!mounted) return;
        
        setState(() {
          if (refresh || _currentPage == 0) {
            _exams = exams;
            _students = students;
          } else {
            _exams.addAll(exams);
            _students.addAll(students);
          }
          _hasMoreData = false; // Load all at once for admins
          _isLoading = false;
        });
      } else {
        // For students, load their exams using studentId if available, else fallback to username
        final studentId = widget.studentId ?? widget.username;
        if (studentId == null) {
          setState(() {
            _exams = [];
            _isLoading = false;
          });
          return;
        }
        final studentExams = await AtlasService.getStudentExams(
          studentId: studentId,
          page: _currentPage,
          limit: _pageSize,
        );

        if (!mounted) return;

        if (widget.userRole == UserRole.student) {
          // For students, separate upcoming and past exams
          final now = DateTime.now();
          final studentId = widget.studentId ?? widget.username;
          
          final upcomingExams = <Exam>[];
          final pastExams = <Exam>[];
          
          // Check which exams the student has completed
          final completedExamIds = <String>{};
          if (studentId != null) {
            try {
              final api = ApiService();
              final studentResults = await api.getStudentResults(studentId);
              api.close();
              
              for (final result in studentResults) {
                if (result['examId'] != null) {
                  // examId might be ObjectId or string
                  final examIdStr = result['examId'] is String 
                      ? result['examId'] 
                      : result['examId'].toString();
                  completedExamIds.add(examIdStr);
                }
              }
            } catch (e) {
              // Silently fail - results might not be available yet
            }
          }
          
          for (final exam in studentExams) {
            // Skip dummy exams for students (only teachers/admins can access them)
            if (exam.isDummy || exam.examTime.toUpperCase() == 'NAN') {
              continue;
            }
            
            final examId = exam.id.toHexString();
            
            // If student has completed the exam, show it as past exam
            if (completedExamIds.contains(examId)) {
              pastExams.add(exam);
              continue;
            }
            
            final examStartDateTime = exam.getExamStartDateTime();
            final examEndDateTime = exam.getExamEndDateTime();
            
            // Skip if exam has no valid start/end time
            if (examStartDateTime == null || examEndDateTime == null) {
              continue;
            }
            
            // Upcoming exams: exams that haven't started yet (or are starting now)
            if (examStartDateTime.isAfter(now) || examStartDateTime.isAtSameMomentAs(now)) {
              upcomingExams.add(exam);
            }
            // Past exams: exams that have already ended
            else if (examEndDateTime.isBefore(now)) {
              pastExams.add(exam);
            }
            // Exams currently in progress: show as upcoming
            else if (examStartDateTime.isBefore(now) && examEndDateTime.isAfter(now)) {
              upcomingExams.add(exam);
            }
          }
          
          // Sort upcoming exams by start date (nearest to farthest)
          if (upcomingExams.isNotEmpty) {
            upcomingExams.sort((a, b) {
              final aStart = a.getExamStartDateTime();
              final bStart = b.getExamStartDateTime();
              if (aStart == null || bStart == null) return 0;
              return aStart.compareTo(bStart);
            });
          }
          
          setState(() {
            if (refresh || _currentPage == 0) {
              _upcomingExams = upcomingExams;
              _pastExams = pastExams;
              _exams = pastExams;
            } else {
              // Merge and re-sort upcoming exams
              _upcomingExams.addAll(upcomingExams);
              _upcomingExams.sort((a, b) {
                final aStart = a.getExamStartDateTime();
                final bStart = b.getExamStartDateTime();
                if (aStart == null || bStart == null) return 0;
                return aStart.compareTo(bStart);
              });
              // Remove duplicates based on exam ID
              final seenIds = <String>{};
              _upcomingExams = _upcomingExams.where((exam) {
                final id = exam.id.toString();
                if (seenIds.contains(id)) return false;
                seenIds.add(id);
                return true;
              }).toList();
              _upcomingExams.sort((a, b) {
                final aStart = a.getExamStartDateTime();
                final bStart = b.getExamStartDateTime();
                if (aStart == null || bStart == null) return 0;
                return aStart.compareTo(bStart);
              });
              
              _pastExams.addAll(pastExams);
              _exams = _pastExams;
            }
            _hasMoreData = studentExams.length == _pageSize;
            
            // Schedule notifications for upcoming exams (only for students)
            if (widget.userRole == UserRole.student && studentId != null && _upcomingExams.isNotEmpty) {
              try {
                final notificationService = NotificationService();
                await notificationService.initialize();
                await notificationService.scheduleNotificationsForExams(
                  exams: _upcomingExams,
                  studentId: studentId,
                );
              } catch (e) {
                Logger.warning('Failed to schedule notifications: $e', 'HomePage');
                // Don't show error to user - notifications are not critical
              }
            }
            _currentPage++;
          });
        } else {
          // For teachers, show all exams
          setState(() {
            if (refresh || _currentPage == 0) {
              _exams = studentExams;
            } else {
              _exams.addAll(studentExams);
            }
            _hasMoreData = studentExams.length == _pageSize;
            _currentPage++;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Loading Data',
          message: 'An error occurred while loading data: $e',
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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final teacherId = _teacherId ?? widget.teacherId;
      if (teacherId == null) {
        Logger.warning('Teacher ID not available for teacher user', 'HomePage');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      Logger.debug('_loadTeacherData called for teacherId: $teacherId', 'HomePage');
      
      // Get teacher's info to filter questions by subject
      try {
        final api = ApiService();
        final teacherData = await api.getTeacher(teacherId);
        api.close();
        if (teacherData != null) {
          _currentTeacher = Teacher.fromMap(teacherData);
        }
      } catch (e) {
        Logger.warning('Could not load teacher info: $e', 'HomePage');
      }
      
      // Get teacher's exams using their ID
      final exams = await AtlasService.getTeacherExams(
        teacherId: teacherId,
        page: _currentPage,
        limit: _pageSize,
      );
      
      // Load classes
      await _loadClasses();
      
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Loading Teacher Data',
          message: 'An error occurred while loading teacher data: $e',
        );
      }
    }
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await AtlasService.getAllClasses();
      
      // Get student count for each class
      final counts = <String, int>{};
      for (final className in classes) {
        try {
          final allStudents = await AtlasService.getStudentsByClass(
            className: className,
            page: 0,
            limit: 1000,
          );
          counts[className] = allStudents.length;
        } catch (e) {
          counts[className] = 0;
        }
      }

      if (mounted) {
        setState(() {
          _classes = classes;
          _classStudentCounts = counts;
        });
      }
    } catch (e) {
      Logger.warning('Could not load classes: $e', 'HomePage');
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
      if (mounted) {
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Error Loading Data',
          message: 'An error occurred while loading more data: $e',
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
                  widget.userRole == UserRole.teacher
                      ? 'Teacher Dashboard'
                      : widget.userRole == UserRole.admin
                          ? 'Admin Dashboard'
                          : 'Student Dashboard',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            actions: [
              if (widget.userRole == UserRole.admin)
                IconButton(
                  icon: const Icon(Icons.cloud),
                  tooltip: 'Test Backend API',
                  onPressed: _testApiCall,
                ),
              if (widget.userRole == UserRole.teacher)
                IconButton(
                  icon: const Icon(Icons.library_books),
                  tooltip: 'Question Bank',
                  onPressed: _openQuestionBankPage,
                ),
              if (widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Create Exam',
                  onPressed: _createNewExam,
                ),
              if (widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin)
                IconButton(
                  icon: const Icon(Icons.auto_mode),
                  tooltip: 'Generate Demo Exam',
                  onPressed: _generateDummyExamScenario,
                ),
              if (widget.userRole == UserRole.teacher)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'import':
                        _importQuestionBank();
                        break;
                      case 'new':
                        _createNewQuestion();
                        break;
                      case 'edit':
                        _editQuestion();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'import',
                      child: Text('Import Question Bank'),
                    ),
                    const PopupMenuItem(
                      value: 'new',
                      child: Text('New Question'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Question'),
                    ),
                  ],
                ),
              if (widget.userRole == UserRole.student)
                IconButton(
                  icon: const Icon(Icons.support_agent),
                  tooltip: 'Helpdesk',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => HelpdeskChat(
                        studentId: widget.studentId,
                      ),
                    );
                  },
                ),
              if (widget.userRole == UserRole.teacher) ...[
                IconButton(
                  icon: const Icon(Icons.class_),
                  tooltip: 'Classes',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClassListPage(
                          teacherId: widget.teacherId,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.support_agent),
                  tooltip: 'Contact Admin',
                  onPressed: () {
                    final chatUserId = _teacherId ?? widget.teacherId;
                    if (chatUserId == null || chatUserId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to open chat: missing teacher ID.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (context) => HelpdeskChat(
                        studentId: chatUserId,
                        targetUserRole: 'admin',
                        userRole: 'teacher',
                      ),
                    );
                  },
                ),
              ],
              if (widget.userRole == UserRole.admin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.admin_panel_settings),
                  tooltip: 'Admin Tools',
                  onSelected: (value) async {
                    final adminId = widget.adminId ?? widget.studentId ?? widget.teacherId ?? widget.username;
                    if (value == 'chat') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminChatPage(adminId: adminId ?? ''),
                        ),
                      );
                    } else if (value == 'teachers') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminTeacherListPage(adminId: adminId ?? ''),
                        ),
                      );
                    } else if (value == 'addStudent') {
                      _showAddStudentDialog();
                    } else if (value == 'testChat') {
                      await _testChatSocket();
                    } else if (value == 'testExam') {
                      await _testExaminationPage();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'chat',
                      child: Row(
                        children: [
                          Icon(Icons.support_agent, size: 20),
                          SizedBox(width: 8),
                          Text('Student Chat'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'teachers',
                      child: Row(
                        children: [
                          Icon(Icons.people, size: 20),
                          SizedBox(width: 8),
                          Text('Teachers'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'testChat',
                      child: Row(
                        children: [
                          Icon(Icons.wifi_tethering, size: 20),
                          SizedBox(width: 8),
                          Text('Test Chat Socket'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'testExam',
                      child: Row(
                        children: [
                          Icon(Icons.quiz, size: 20),
                          SizedBox(width: 8),
                          Text('Test Examination Page'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'addStudent',
                      child: Row(
                        children: [
                          Icon(Icons.person_add, size: 20),
                          SizedBox(width: 8),
                          Text('Add Student'),
                        ],
                      ),
                    ),
                  ],
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
                if (widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin) ...[
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
                  if (widget.userRole == UserRole.teacher)
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.class_),
                          if (MediaQuery.of(context).size.width >= 600) const SizedBox(width: 8),
                          if (MediaQuery.of(context).size.width >= 600) const Text('Classes'),
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
                    if (widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin) ...[
                      _buildStudentsList(MediaQuery.of(context).size.width < 600),
                      if (widget.userRole == UserRole.teacher)
                        _buildClassesList(MediaQuery.of(context).size.width < 600),
                    ],
                  ],
                ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Create Exam button (on top)
              if (widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin)
                FloatingActionButton(
                  onPressed: _createNewExam,
                  heroTag: 'createExam',
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.add),
                ),
              const SizedBox(height: 16),
              // Refresh button (below)
              FloatingActionButton(
                onPressed: () {
                  if (widget.userRole == UserRole.teacher) {
                    _loadTeacherData();
                  } else {
                    _loadData(refresh: true);
                  }
                },
                heroTag: 'refresh',
                child: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExamsList(bool isSmallScreen) {
    // For students, show split layout with banner and past exams
    if (widget.userRole == UserRole.student) {
      return Column(
        children: [
          // Upper banner: Upcoming Exams
          _buildUpcomingExamBanner(),
          // Lower part: Past Exams
          Expanded(
            child: _buildPastExamsList(isSmallScreen),
          ),
        ],
      );
    }
    
    // For teachers, show regular list
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
                      width: widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin
                          ? (widget.userRole == UserRole.admin ? 240 : 180)
                          : 80,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin) ...[
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
                            if (widget.userRole == UserRole.admin)
                              IconButton(
                                icon: const Icon(Icons.people, size: 20),
                                onPressed: () => _manageStudentAssignments(exam),
                                tooltip: 'Manage Students',
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
                          if (widget.userRole == UserRole.teacher || widget.userRole == UserRole.admin)
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
                                if (widget.userRole == UserRole.admin)
                                  IconButton(
                                    icon: const Icon(Icons.people, size: 18),
                                    onPressed: () => _manageStudentAssignments(exam),
                                    tooltip: 'Manage Students',
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

  Widget _buildUpcomingExamBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.upcoming,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Upcoming Exams',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_upcomingExams.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No upcoming exams',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              height: 180,
              child: Stack(
                children: [
                  // Horizontal scrollable list
                  ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _upcomingExams.length,
                    itemBuilder: (context, index) {
                      final exam = _upcomingExams[index];
                      return Container(
                        width: 300,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Card(
                          color: Colors.white,
                          child: InkWell(
                            onTap: () => _navigateToExamDetails(exam),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          exam.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (exam.isDummy || exam.examTime.toUpperCase() == 'NAN')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'TEST',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.subject, size: 16, color: Colors.grey.shade700),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          exam.subject,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${exam.examDate.toString().split(' ')[0]} at ${exam.examTime}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 16, color: Colors.grey.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Duration: ${exam.duration} min',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Left fade gradient
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.blue.shade600,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Right fade gradient
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            Colors.blue.shade600,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPastExamsList(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Past Exams',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _pastExams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No past exams',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                      _loadMoreData();
                    }
                    return true;
                  },
                  child: isSmallScreen
                      ? ListView.builder(
                          itemCount: _pastExams.length + (_hasMoreData ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _pastExams.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final exam = _pastExams[index];
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
                                trailing: Chip(
                                  label: const Text(
                                    'Finished',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.grey.shade300,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onTap: () => _navigateToExamDetails(exam),
                              ),
                            );
                          },
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.5,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _pastExams.length + (_hasMoreData ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _pastExams.length) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final exam = _pastExams[index];
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
                                      Chip(
                                        label: const Text(
                                          'Finished',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: Colors.grey.shade300,
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
                ),
        ),
      ],
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.userRole == UserRole.admin)
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editStudent(student),
                            tooltip: 'Edit Student',
                            color: Colors.blue,
                          ),
                        IconButton(
                          icon: const Icon(Icons.chat),
                          onPressed: () => _startChatWithStudent(student),
                          tooltip: 'Start Chat',
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        // Email text
                        Flexible(
                          child: Text(
                            student.email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            // Action buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.userRole == UserRole.admin)
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _editStudent(student),
                                    tooltip: 'Edit Student',
                                    color: Colors.blue,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.chat, size: 20),
                                  onPressed: () => _startChatWithStudent(student),
                                  tooltip: 'Start Chat',
                                  color: Colors.blue,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
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

  Widget _buildClassesList(bool isSmallScreen) {
    return _classes.isEmpty && !_isLoading
        ? const Center(
            child: Text(
              'No classes found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _classes.length,
            itemBuilder: (context, index) {
              final className = _classes[index];
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
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ClassDetailPage(
                          className: className,
                          teacherId: widget.teacherId,
                          adminId: widget.adminId,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
  }

  void _navigateToExamDetails(Exam exam) {
    // For students, check if exam has finished before navigating
    // Dummy exams are always accessible to teachers/admins
    if (widget.userRole == UserRole.student) {
      // Students cannot access dummy exams
      if (exam.isDummy || exam.examTime.toUpperCase() == 'NAN') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This exam is only available to teachers and admins.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      
      // Check if exam has finished
      if (exam.isExamFinished()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This exam has finished and is no longer available.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    Navigator.pushNamed(
      context,
      AppRoutes.examDetails,
      arguments: {
        'exam': exam,
        'studentId': widget.studentId,
        'userRole': widget.userRole,
        'onExamUpdated': () => _loadData(refresh: true),
        'onExamDeleted': () => _loadData(refresh: true),
      },
    ).then((result) {
      // Refresh data if exam was deleted
      if (result == true) {
        _loadData(refresh: true);
      }
    });
  }

  void _editStudent(Student student) {
    final adminId = widget.adminId ?? widget.studentId ?? widget.teacherId ?? widget.username;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminStudentEditPage(
          adminId: adminId ?? '',
          student: student,
        ),
      ),
    ).then((_) {
      // Refresh student list
      _currentPage = 0;
      _students.clear();
      _loadData(refresh: true);
    });
  }

  Future<void> _testChatSocket() async {
    final api = ApiService();
    try {
      setState(() => _isLoading = true);
      final isHealthy = await api.testChatServiceHealth();
      api.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHealthy
                  ? 'Chat socket is connected and healthy!'
                  : 'Chat socket connection failed',
            ),
            backgroundColor: isHealthy ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing chat socket: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _testExaminationPage() async {
    final adminId = widget.adminId ?? widget.studentId ?? widget.teacherId ?? widget.username;
    if (adminId == null || adminId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to test: Admin ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      // Create a dummy exam scenario for testing
      final dummyExamSetup = await AtlasService.createDummyExamScenario(
        teacherId: adminId,
        assignSampleStudent: false, // Don't assign a student, we'll test as admin
      );

      // Check if questions were loaded
      if (dummyExamSetup.exam.populatedQuestions == null || dummyExamSetup.exam.populatedQuestions!.isEmpty) {
        // Try to load questions if not populated
        final questions = await AtlasService.getQuestionsByIds(dummyExamSetup.exam.questions);
        dummyExamSetup.exam.populatedQuestions = questions;
      }

      if (mounted && dummyExamSetup.exam.populatedQuestions != null && dummyExamSetup.exam.populatedQuestions!.isNotEmpty) {
        // Navigate directly to examination page with the dummy exam
        Navigator.pushNamed(
          context,
          AppRoutes.examination,
          arguments: {
            'exam': dummyExamSetup.exam,
            'questions': dummyExamSetup.exam.populatedQuestions!,
            'studentId': adminId, // Use admin ID for testing
          },
        );
      } else {
        throw Exception('Failed to create dummy exam or load questions. Questions count: ${dummyExamSetup.exam.populatedQuestions?.length ?? 0}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating test exam: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startChatWithStudent(Student student) {
    // Only allow admin to chat with students
    if (widget.userRole != UserRole.admin) {
      return;
    }

    final adminId = widget.adminId ?? widget.studentId ?? widget.teacherId ?? widget.username;
    if (adminId == null || adminId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start chat: Admin ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminChatConversationPage(
          adminId: adminId,
          student: student,
        ),
      ),
    );
  }

  void _showAddStudentDialog() {
    final formKey = GlobalKey<FormState>();
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final studentIdController = TextEditingController();
    final classNameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Student'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Full name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: studentIdController,
                        decoration: const InputDecoration(
                          labelText: 'Student ID / Roll Number *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Student ID is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: classNameController,
                        decoration: const InputDecoration(
                          labelText: 'Class Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isSubmitting = true;
                            });

                            try {
                              final student = await AtlasService.createStudent(
                                fullName: fullNameController.text.trim(),
                                email: emailController.text.trim(),
                                studentId: studentIdController.text.trim(),
                                className: classNameController.text.trim().isEmpty
                                    ? null
                                    : classNameController.text.trim(),
                                phoneNumber: phoneController.text.trim().isEmpty
                                    ? null
                                    : phoneController.text.trim(),
                                address: addressController.text.trim().isEmpty
                                    ? null
                                    : addressController.text.trim(),
                              );

                              if (student != null && mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Student added successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                // Refresh student list
                                _currentPage = 0;
                                _students.clear();
                                _loadData(refresh: true);
                              } else {
                                setDialogState(() {
                                  isSubmitting = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to add student'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
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
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Student'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Clean up controllers
      fullNameController.dispose();
      emailController.dispose();
      studentIdController.dispose();
      classNameController.dispose();
      phoneController.dispose();
      addressController.dispose();
    });
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
    String? examId;
    try {
      examId = exam.id.toHexString();
    } catch (_) {
      examId = null;
    }
    if (examId == null) {
      // If exam id is null, create a temp one and navigate to create exam
      final tempId = ObjectId().toHexString();
      if (widget.userRole == UserRole.admin) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExamEditPage(
              examId: tempId,
              adminId: widget.adminId,
            ),
          ),
        ).then((_) => _loadData(refresh: true));
      } else {
        Navigator.pushNamed(
          context,
          AppRoutes.examEdit,
          arguments: {
            'examId': tempId,
            'teacherId': _teacherId,
            'userRole': UserRole.teacher,
          },
        ).then((_) => _loadData(refresh: true));
      }
    } else {
      // Edit existing exam
      if (widget.userRole == UserRole.admin) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExamEditPage(
              examId: examId,
              adminId: widget.adminId,
            ),
          ),
        ).then((_) => _loadData(refresh: true));
      } else if (widget.userRole == UserRole.teacher) {
        // Teacher editing exam - get teacher's subjects
        final teacherId = _teacherId ?? widget.teacherId;
        if (teacherId == null || teacherId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to edit exam: missing teacher ID.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        // Get teacher's subjects if not already loaded
        if (_currentTeacher == null) {
          _loadTeacherInfoAndEditExam(teacherId, examId);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExamEditPage(
                examId: examId,
                teacherId: teacherId,
                teacherSubjects: _currentTeacher?.subjects ?? [],
              ),
            ),
          ).then((_) {
            if (!mounted) return;
            _currentPage = 0;
            _exams.clear();
            _loadTeacherData();
          });
        }
      } else {
        Navigator.pushNamed(
          context,
          AppRoutes.examEdit,
          arguments: {
            'examId': examId,
            'teacherId': _teacherId,
            'userRole': UserRole.teacher,
          },
        ).then((_) => _loadData(refresh: true));
      }
    }
  }

  void _manageStudentAssignments(Exam exam) {
    String? examId;
    try {
      examId = exam.id.toHexString();
    } catch (_) {
      examId = null;
    }
    if (examId != null && examId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminStudentExamAssignmentPage(
            examId: examId!,
            exam: exam,
          ),
        ),
      ).then((_) {
        if (!mounted) return;
        if (widget.userRole == UserRole.teacher) {
          _currentPage = 0;
          _loadTeacherData();
        } else {
          _loadData(refresh: true);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid exam ID'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createNewExam() {
    if (widget.userRole == UserRole.admin) {
      // Admin can create exams
      final adminId = widget.adminId ?? widget.studentId ?? widget.teacherId ?? widget.username;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExamEditPage(
            examId: null, // null means creating new exam
            adminId: adminId,
          ),
        ),
      ).then((_) {
        if (!mounted) return;
        _loadData(refresh: true);
      });
    } else if (widget.userRole == UserRole.teacher) {
      // Teacher creates exam
      Navigator.pushNamed(
        context,
        AppRoutes.examEdit,
        arguments: {
          'teacherId': _teacherId,
          'userRole': UserRole.teacher,
        },
      ).then((_) {
        if (!mounted) return;
        _currentPage = 0;
        _exams.clear();
        _loadTeacherData();
      });
    }
  }

  Future<void> _openQuestionBankPage() async {
    final teacherId = _teacherId ?? widget.teacherId;
    if (teacherId == null || teacherId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open question bank: missing teacher ID.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get teacher's subjects if not already loaded
    if (_currentTeacher == null) {
      try {
        final api = ApiService();
        final teacherData = await api.getTeacher(teacherId);
        api.close();
        if (teacherData != null) {
          _currentTeacher = Teacher.fromMap(teacherData);
        }
      } catch (e) {
        Logger.warning('Could not load teacher info: $e', 'HomePage');
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionBankPage(
          teacherId: teacherId,
          teacherSubjects: _currentTeacher?.subjects ?? [],
        ),
      ),
    );

    if (!mounted) return;
    if (widget.userRole == UserRole.teacher) {
      _currentPage = 0;
      await _loadTeacherData();
    } else {
      await _loadData(refresh: true);
    }
  }

  Future<void> _generateDummyExamScenario() async {
    if (_isLoading) return;

    String? creatorId;
    if (widget.userRole == UserRole.teacher) {
      creatorId = _teacherId ?? widget.teacherId;
    } else if (widget.userRole == UserRole.admin) {
      if (_teachers.isNotEmpty) {
        creatorId = _teachers.first.id.toHexString();
      } else {
        try {
          final teachers = await AtlasService.findTeachers(limit: 1);
          if (teachers.isNotEmpty) {
            creatorId = teachers.first.id.toHexString();
            if (mounted) {
              setState(() {
                _teachers = teachers;
              });
            }
          }
        } catch (e) {
          if (mounted) {
            DialogHelper.showErrorDialog(
              context: context,
              title: 'Demo Exam Failed',
              message: 'Unable to load teacher list: $e',
            );
          }
          return;
        }
      }
    }

    if (creatorId == null || creatorId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No teacher available to own the demo exam.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    bool refreshTeacherTab = widget.userRole == UserRole.teacher;
    bool refreshAdminTab = widget.userRole == UserRole.admin;

    setState(() => _isLoading = true);
    try {
      final setup = await AtlasService.createDummyExamScenario(teacherId: creatorId);
      if (!mounted) return;

      final buffer = StringBuffer('Created demo exam "${setup.exam.title}"');

      final studentName = setup.assignedStudent?['fullName'] ?? setup.assignedStudent?['full_name'];
      if (studentName != null) {
        buffer.write(' assigned to $studentName');
      }

      final rawScore = setup.submission?['percentageScore'] ?? setup.submission?['percentage_score'];
      if (rawScore is num) {
        buffer.write(' (score: ${rawScore.toStringAsFixed(1)}%).');
      } else if (rawScore != null) {
        buffer.write(' (score: $rawScore%).');
      } else {
        buffer.write('.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(buffer.toString())),
      );
    } catch (e) {
      if (mounted) {
        DialogHelper.showErrorDialog(
          context: context,
          title: 'Demo Exam Failed',
          message: 'Unable to create demo exam: $e',
        );
      }
      refreshTeacherTab = false;
      refreshAdminTab = false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (refreshTeacherTab) {
          await _loadTeacherData();
        } else if (refreshAdminTab) {
          await _loadData(refresh: true);
        }
      }
    }
  }

  Future<void> _testApiCall() async {
    // Restrict API test to admins only (defense in depth)
    if (widget.userRole != UserRole.admin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: Only admins can test the API.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      final api = ApiService();
      // Create a valid test ObjectId for createdBy
      final testObjectId = ObjectId().toHexString();
      final insertedId = await api.createExam({
        'title': 'API Sample Exam',
        'subject': 'General Knowledge',
        'examDate': DateTime.now().toIso8601String(),
        'duration': 60,
        'createdBy': testObjectId,
      });
      final doc = await api.getExam(insertedId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API OK. Inserted ${doc['_id']}')),
      );
      api.close();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API error: $e')),
      );
    }
  }

  void _delayExam(Exam exam) {
    // Only allow teachers and admins to delay exams
    if (widget.userRole != UserRole.teacher && widget.userRole != UserRole.admin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only teachers and admins can delay exams.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    // Capture the outer context before showing dialog
    final outerContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
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
                      context: dialogContext,
                      initialDate: exam.examDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        selectedDate = date;
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('Time'),
                  subtitle: Text(selectedTime?.format(dialogContext) ?? 'Select time'),
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
                      context: dialogContext,
                      initialTime: initialTime,
                    );
                    if (time != null) {
                      setState(() {
                        selectedTime = time;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (selectedDate == null || selectedTime == null) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
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
                    final success = await AtlasService.updateExamStatus(
                      examId: exam.id.toHexString(),
                      status: 'delayed',
                      newDate: newDate,
                    );

                    if (success) {
                      // Close dialog first
                      Navigator.pop(dialogContext);
                      
                      // Refresh data and show success message using outer context
                      if (mounted) {
                        ScaffoldMessenger.of(outerContext).showSnackBar(
                          const SnackBar(content: Text('Exam delayed successfully')),
                        );
                        _loadData(refresh: true);
                      }
                    } else {
                      throw Exception('Failed to delay exam');
                    }
                  } catch (e) {
                    // Show error dialog using dialog context
                    if (mounted) {
                      DialogHelper.showErrorDialog(
                        context: dialogContext,
                        title: 'Error Delaying Exam',
                        message: 'An error occurred while delaying the exam: $e',
                      );
                    }
                  }
                },
                child: const Text('Delay'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _cancelExam(Exam exam) {
    // Allow teachers and admins to cancel exams
    if (widget.userRole != UserRole.teacher && widget.userRole != UserRole.admin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only teachers and admins can cancel exams.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
                  examId: exam.id.toHexString(),
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
                DialogHelper.showErrorDialog(
                  context: context,
                  title: 'Error Cancelling Exam',
                  message: 'An error occurred while cancelling the exam: $e',
                );
              }
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _importQuestionBank() {
    // Only allow teachers to import question bank
    if (widget.userRole != UserRole.teacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only teachers can import question banks.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import Question Bank feature coming soon')),
    );
  }

  void _createNewQuestion() {
    // Only allow teachers to create questions
    if (widget.userRole != UserRole.teacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only teachers can create questions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Navigate to question edit page (create mode)
    if (_teacherId != null && _teacherId!.isNotEmpty) {
      Navigator.pushNamed(
        context,
        AppRoutes.questionEdit,
        arguments: {
          'questionId': null, // null means create mode
          'teacherId': _teacherId!,
          'userRole': widget.userRole,
        },
      ).then((_) => _loadData(refresh: true));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Teacher ID not found.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editQuestion() {
    // Only allow teachers to edit questions
    if (widget.userRole != UserRole.teacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only teachers can edit questions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Navigate to question bank page where they can select a question to edit
    if (_teacherId != null && _teacherId!.isNotEmpty) {
      // You can navigate to question bank page or show a dialog to select question
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please go to Question Bank to edit questions')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Teacher ID not found.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}