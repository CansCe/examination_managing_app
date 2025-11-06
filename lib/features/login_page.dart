import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/index.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// Login Page State class definition
class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isStudentLogin = true; // Track login type
  bool _isAdminLogin = false; // Track if admin login is selected
  bool _obscurePassword = true;
  int _hiddenButtonTapCount = 0; // Counter for hidden button taps
  bool _showAdminLogin = false; // Track if admin login should be shown

  @override
  void initState() {
    super.initState();
    // Initialize Atlas connection
    AtlasService.init().catchError((error) {
      print('Error initializing Atlas: $error');
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (user != null) {
        // Check if user is trying to login as admin but selected wrong role
        if (_isAdminLogin && user.role != UserRole.admin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This account is not an admin account'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        // Navigate to home page with user information
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              username: user.fullName,
              userRole: user.role,
              studentId: user.role == UserRole.student ? user.id : null,
              className: user.role == UserRole.student ? 'Class A' : null, // TODO: Get actual class from user data
              teacherId: user.role == UserRole.teacher ? user.id : null, // Pass teacherId for teachers
              adminId: user.role == UserRole.admin ? user.id : null, // Pass adminId for admins
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid username or password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during login: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleHiddenButtonTap() {
    setState(() {
      _hiddenButtonTapCount++;
      if (_hiddenButtonTapCount >= 5) {
        _showAdminLogin = true;
        _hiddenButtonTapCount = 0; // Reset counter
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin login enabled'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        //title: const Text('Login Page'),
        actions: [
          // Hidden button in top right corner (transparent/invisible)
          GestureDetector(
            onTap: _handleHiddenButtonTap,
            child: Container(
              width: 50,
              height: 50,
              color: Colors.transparent, // Invisible
              // Optional: Add a very subtle visual hint (commented out)
              // child: Container(
              //   margin: EdgeInsets.all(8),
              //   decoration: BoxDecoration(
              //     color: Colors.transparent,
              //     borderRadius: BorderRadius.circular(4),
              //   ),
              // ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/phenikaa_login_logo.png',
                        height: 120,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.school,
                                size: 50,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Phenikaa University',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  // Login type selector
                  _showAdminLogin
                      ? SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'student',
                              label: Text('Student'),
                              icon: Icon(Icons.person),
                            ),
                            ButtonSegment<String>(
                              value: 'teacher',
                              label: Text('Teacher'),
                              icon: Icon(Icons.school),
                            ),
                            ButtonSegment<String>(
                              value: 'admin',
                              label: Text('Admin'),
                              icon: Icon(Icons.admin_panel_settings),
                            ),
                          ],
                          selected: {
                            _isStudentLogin ? 'student' : (_isAdminLogin ? 'admin' : 'teacher')
                          },
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              final selected = newSelection.first;
                              _isStudentLogin = selected == 'student';
                              _isAdminLogin = selected == 'admin';
                            });
                          },
                        )
                      : SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Student'),
                              icon: Icon(Icons.person),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Teacher'),
                              icon: Icon(Icons.school),
                            ),
                          ],
                          selected: {_isStudentLogin},
                          onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              _isStudentLogin = newSelection.first;
                              _isAdminLogin = false;
                            });
                          },
                        ),
                  const SizedBox(height: 12.0),
                  Text(
                    _isStudentLogin
                        ? 'Enter your Student ID'
                        : (_isAdminLogin
                            ? 'Enter your Admin Username or Email'
                            : 'Enter your Username or Email'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32.0),
                  TextFormField(
                    controller: _usernameController,
                    focusNode: _usernameFocusNode,
                    decoration: InputDecoration(
                      labelText: _isStudentLogin
                          ? 'Student ID'
                          : (_isAdminLogin
                              ? 'Admin Username/Email'
                              : 'Username/Email'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your ${_isStudentLogin ? 'Student ID' : (_isAdminLogin ? 'Admin Username/Email' : 'Username/Email')}';
                      }
                      if (_isStudentLogin && value.length != 8) {
                        return 'Student ID must be 8 digits';
                      }
                      if (!_isStudentLogin) {
                        if (_isAdminLogin) {
                          // Admin validation - can be username or email
                          if (value.length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                        } else {
                          // Teacher validation
                          if (!value.contains('@') && !value.startsWith('teacher')) {
                            return 'Please enter a valid username or email';
                          }
                        }
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      _passwordFocusNode.requestFocus();
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      _handleLogin();
                    },
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 