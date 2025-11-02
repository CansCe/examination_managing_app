// lib/features/home_screen.dart
import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' hide State,Center;
import '../config/routes.dart'; // For AppRoutes.login
import '../models/index.dart';
import '../models/question.dart';
//import 'exam_details_page.dart';
import '../features/shared/helpdesk_chat.dart';
import '../features/admin/admin_chat_page.dart';
import '../services/atlas_service.dart';
import '../utils/dialog_helper.dart';

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
  // Separate lists for students: upcoming and past exams
  Exam? _nearestUpcomingExam;
  List<Exam> _pastExams = [];

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
        final oneDayFromNow = now.add(const Duration(days: 1));
        final oneWeekAgo = now.subtract(const Duration(days: 7));
        
        final upcomingExams = <Exam>[];
        final pastExams = <Exam>[];
        
        for (final exam in assignedExams) {
          final examStartDateTime = exam.getExamStartDateTime();
          final examEndDateTime = exam.getExamEndDateTime();
          
          // Upcoming exams (at least 1 day away)
          if (examStartDateTime.isAfter(oneDayFromNow) || examStartDateTime.isAtSameMomentAs(oneDayFromNow)) {
            upcomingExams.add(exam);
          }
          // Past exams (finished within last week)
          else if (examEndDateTime.isBefore(now) && examEndDateTime.isAfter(oneWeekAgo)) {
            pastExams.add(exam);
          }
        }
        
        // Find the nearest upcoming exam
        Exam? nearestUpcoming;
        if (upcomingExams.isNotEmpty) {
          upcomingExams.sort((a, b) => a.getExamStartDateTime().compareTo(b.getExamStartDateTime()));
          nearestUpcoming = upcomingExams.first;
        }
        
        setState(() {
          if (widget.userRole == UserRole.student) {
            _nearestUpcomingExam = nearestUpcoming;
            _pastExams = pastExams;
            _exams = pastExams; // Use _exams for past exams list
          } else {
            _exams = assignedExams;
          }
          _hasMoreData = assignedExams.length == _pageSize;
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
        _nearestUpcomingExam = null;
        _pastExams.clear();
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.userRole == UserRole.teacher) {
        await _loadTeacherData();
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
          final oneDayFromNow = now.add(const Duration(days: 1));
          final oneWeekAgo = now.subtract(const Duration(days: 7));
          
          final upcomingExams = <Exam>[];
          final pastExams = <Exam>[];
          
          for (final exam in studentExams) {
            final examStartDateTime = exam.getExamStartDateTime();
            final examEndDateTime = exam.getExamEndDateTime();
            
            // Upcoming exams (at least 1 day away)
            if (examStartDateTime.isAfter(oneDayFromNow) || examStartDateTime.isAtSameMomentAs(oneDayFromNow)) {
              upcomingExams.add(exam);
            }
            // Past exams (finished within last week)
            else if (examEndDateTime.isBefore(now) && 
                     (examEndDateTime.isAfter(oneWeekAgo) || examEndDateTime.isAtSameMomentAs(oneWeekAgo))) {
              pastExams.add(exam);
            }
          }
          
          // Find the nearest upcoming exam
          Exam? nearestUpcoming;
          if (upcomingExams.isNotEmpty) {
            upcomingExams.sort((a, b) => a.getExamStartDateTime().compareTo(b.getExamStartDateTime()));
            nearestUpcoming = upcomingExams.first;
          }
          
          setState(() {
            if (refresh || _currentPage == 0) {
              _nearestUpcomingExam = nearestUpcoming;
              _pastExams = pastExams;
              _exams = pastExams;
            } else {
              _pastExams.addAll(pastExams);
              _exams = _pastExams;
            }
            _hasMoreData = studentExams.length == _pageSize;
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
              if (widget.userRole == UserRole.teacher)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Create Exam',
                  onPressed: _createNewExam,
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
              if (widget.userRole == UserRole.admin)
                IconButton(
                  icon: const Icon(Icons.support_agent),
                  tooltip: 'Admin Chat',
                  onPressed: () {
                    final adminId = widget.adminId ?? widget.studentId ?? widget.teacherId ?? widget.username;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminChatPage(adminId: adminId ?? ''),
                      ),
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

  Widget _buildUpcomingExamBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.upcoming,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
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
          if (_nearestUpcomingExam != null) ...[
            Card(
              color: Colors.white.withOpacity(0.95),
              child: InkWell(
                onTap: () => _navigateToExamDetails(_nearestUpcomingExam!),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nearestUpcomingExam!.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.subject, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 4),
                          Text(
                            _nearestUpcomingExam!.subject,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${_nearestUpcomingExam!.examDate.toString().split(' ')[0]} at ${_nearestUpcomingExam!.examTime}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
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
                            'Duration: ${_nearestUpcomingExam!.duration} minutes',
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
          ] else ...[
            Card(
              color: Colors.white.withOpacity(0.95),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No upcoming exams',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
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
            'Past Exams (Last 1 Week)',
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
                        'No past exams in the last week',
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
    // For students, check if exam has finished before navigating
    if (widget.userRole != UserRole.teacher && exam.isExamFinished()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This exam has finished and is no longer available.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      AppRoutes.examDetails,
      arguments: {
        'exam': exam,
        'studentId': widget.studentId,
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
    String? examId;
    try {
      examId = exam.id.toHexString();
    } catch (_) {
      examId = null;
    }
    if (examId == null) {
      // If exam id is null, create a temp one and navigate to create exam
      final tempId = ObjectId().toHexString();
      Navigator.pushNamed(
        context,
        AppRoutes.examEdit,
        arguments: {
          'examId': tempId,
          'teacherId': _teacherId,
        },
      ).then((_) => _loadData(refresh: true));
    } else {
      // Edit existing exam
      Navigator.pushNamed(
        context,
        AppRoutes.examEdit,
        arguments: {
          'examId': examId,
          'teacherId': _teacherId,
        },
      ).then((_) => _loadData(refresh: true));
    }
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
    // Only allow teachers to delay exams
    if (widget.userRole != UserRole.teacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only teachers can delay exams.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
                DialogHelper.showErrorDialog(
                  context: context,
                  title: 'Error Delaying Exam',
                  message: 'An error occurred while delaying the exam: $e',
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
    // Only allow teachers to cancel exams
    if (widget.userRole != UserRole.teacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only teachers can cancel exams.'),
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
    
    // Navigate to question edit page
    if (_teacherId != null && _teacherId!.isNotEmpty) {
      Navigator.pushNamed(
        context,
        AppRoutes.questionEdit,
        arguments: {
          'questionId': null,
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