import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for AuthWrapper
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'pages/signup_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        // Custom purple-based theme
        primaryColor: const Color(0xFF6A1B9A),
        scaffoldBackgroundColor: const Color(0xFF4A148C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE53935), // Redb
          secondary: Color(0xFF6A1B9A), // Purple
        ),
      ),
      // home: LoginPage(), // Replaced by initialRoute and routes
      initialRoute: '/',
      routes: {
        '/': (context) => AuthWrapper(),
        '/login': (context) => LoginPage(),
        // '/home': (context) => HomePage(clientCode: ''), // Placeholder, adjust as needed
        // Note: HomePage requires clientCode. How you provide this here depends
        // on your app's navigation and state management strategy.
        // For now, direct navigation to '/login' after logout will be handled
        // in HomePage itself. If HomePage is pushed via named route, clientCode needs to be passed.
      },
    );
  }
}

// AuthWrapper to decide initial screen based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in. Navigate to HomePage.
          // IMPORTANT: You need a way to pass the clientCode to HomePage.
          // This might involve fetching it based on user.uid or another mechanism.
          // For now, this will likely cause an issue if HomePage strictly requires clientCode via constructor for its initial build.
          // A common pattern is to fetch member data in HomePage's initState based on UID.
          // Or, if clientCode is stored locally (e.g., SharedPreferences) after login, retrieve it here.
          // As a temporary measure, if HomePage can handle a null/empty clientCode initially and fetch it, that's one way.
          // Consider what clientCode HomePage needs. If it's just for display or initial fetch, it might be okay.
          // Let's assume HomePage can be navigated to, and it will handle fetching its required data.
          // To make this compile, we need a default for clientCode or a way to get it.
          // For now, let's defer proper HomePage navigation from here as it needs clientCode.
          // The logout will explicitly go to '/login'.
          // If starting the app while logged in, this needs a robust solution.
          // Let's navigate to LoginPage if no user, and assume HomePage is reached after login.
          // This means if the app starts and user is already logged in, they might see login briefly
          // or you need to handle the transition to HomePage with clientCode properly.
          // For the immediate logout issue, navigating to '/login' is the key.
          // Let's default to LoginPage to ensure a screen is always shown.
          // A better AuthWrapper would fetch user profile data here to decide.
          return LoginPage(); // Fallback, or implement logic to go to HomePage with clientCode
        }
        return LoginPage(); // User is not logged in
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;

  final TextEditingController _clientCodeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService authService =
      AuthService(); // Corrected: Removed leading underscore, made final

  @override
  void dispose() {
    _clientCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await authService.signInWithClientCode(
        _clientCodeController.text.trim(),
        _passwordController.text,
      );

      // Navigate to home page after successful login
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomePage(
              clientCode: _clientCodeController.text.trim(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid client code or password'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Method to show the forgot password dialog
  Future<void> _showForgotPasswordDialog() async {
    // Removed unused emailController
    final TextEditingController forgotPasswordClientCodeController =
        TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF6A1B9A), // Dialog background
          title: const Text('Reset Password',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(
                    'Enter your Client Code to receive a password reset link.',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                TextField(
                  controller: forgotPasswordClientCodeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Client Code',
                    hintStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white70),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE53935)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFEF9A9A))),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Send Reset Link',
                  style: TextStyle(color: Color(0xFFE53935))),
              onPressed: () async {
                if (forgotPasswordClientCodeController.text.isNotEmpty) {
                  Navigator.of(dialogContext).pop(); // Dismiss dialog first
                  setState(() => _isLoading = true);
                  try {
                    await authService.sendPasswordResetEmail(
                        forgotPasswordClientCodeController.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Password reset link sent. Please check your email.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Error: ${e.toString().replaceFirst("Exception: ", "")}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                  }
                } else {
                  // Optionally show an error in the dialog if the field is empty
                  // Or, more directly, show it in a SnackBar after popping this one.
                  // For simplicity, let's just ensure the user knows.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your Client Code.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A148C),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  const Icon(
                    Icons.sports_gymnastics,
                    size: 80,
                    color: Color(0xFFE53935),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Client Code field
                        TextFormField(
                          controller: _clientCodeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Client Code',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.person_outline,
                                color: Color(0xFFEF9A9A)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF9C27B0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF9C27B0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE53935), width: 2),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF6A1B9A).withOpacity(0.5),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your client code';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: Color(0xFFEF9A9A)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xFFEF9A9A),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF9C27B0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF9C27B0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE53935), width: 2),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF6A1B9A).withOpacity(0.5),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Remember me and Forgot Password
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value!;
                                  });
                                },
                                fillColor:
                                    WidgetStateProperty.resolveWith<Color>(
                                  (states) => const Color(0xFFE53935),
                                ),
                                checkColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Remember me',
                                style: TextStyle(color: Colors.white70)),
                            const Spacer(),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _showForgotPasswordDialog, // Updated onPressed
                              child: const Text('Forgot Password?',
                                  style: TextStyle(color: Color(0xFFEF9A9A))),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // First time user
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "First time user? ",
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SignupPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Create Password',
                                style: TextStyle(
                                  color: Color(0xFFEF9A9A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
