import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/member.dart';
import '../models/course.dart'; // Import Course model

class HomePage extends StatefulWidget {
  final String clientCode;

  const HomePage({Key? key, required this.clientCode}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  Member? _member;
  bool _isLoadingMember = true;
  int _currentIndex = 0;
  List<Course> _courses = [];
  bool _isLoadingCourses = true;

  List<Widget> _tabs = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMember = true;
      _isLoadingCourses = true;
    });

    try {
      // Fetch member data and courses in parallel if desired, or sequentially
      final memberFuture =
          _firestoreService.getMemberByClientCode(widget.clientCode);
      final coursesFuture = _firestoreService.getCourses();

      final member = await memberFuture;
      if (!mounted) return;
      setState(() {
        _member = member;
        _isLoadingMember = false;
      });

      final courses = await coursesFuture;
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _isLoadingCourses = false;
      });
    } catch (e) {
      print('Error loading data for HomePage: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingMember = false;
        _isLoadingCourses = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
    } finally {
      _initializeTabs();
    }
  }

  void _initializeTabs() {
    if (!mounted) return;
    setState(() {
      _tabs = [
        _buildDashboardTab(),
        _buildCoursesTab(), // This will now use _courses and _isLoadingCourses
        _buildAttendanceTab(),
        _buildProfileTab(),
      ];
    });
  }

  Future<void> _refreshCourses() async {
    if (!mounted) return;
    setState(() {
      _isLoadingCourses = true;
    });
    try {
      final courses = await _firestoreService.getCourses();
      if (!mounted) return;
      setState(() {
        _courses = courses;
      });
    } catch (e) {
      print('Error refreshing courses: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing courses: ${e.toString()}')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingCourses = false;
      });
      _initializeTabs(); // Re-initialize tabs to update the courses tab
    }
  }

  Widget _buildErrorTab(String tabName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Failed to load $tabName. Please check your connection or try again later.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red.shade700, fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  Widget _buildDashboardTab() {
    if (_isLoadingMember) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_member == null) {
      return _buildErrorTab('Dashboard content');
    }

    String firstName = _member!.fullName.split(' ')[0];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Hello $firstName 👋',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome back to Your Club!',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Quick Actions',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan to Check-In / Check-Out'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Check-In/Out action (to be implemented)')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Next Course',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // Placeholder for next course - to be implemented with actual data
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.calendar_today,
                        color: Theme.of(context).primaryColor, size: 30),
                    title: const Text('Yoga Session',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Today at 5:00 PM - Studio 1'),
                    trailing: TextButton(
                      child: const Text('View'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'View course details (to be implemented)')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Club News',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // Placeholder for club news - to be implemented
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.campaign,
                        color: Theme.of(context).primaryColor, size: 30),
                    title: const Text('Summer Fitness Challenge!',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text(
                        'Join our summer challenge and win exciting prizes. Registrations open!'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('View news details (to be implemented)')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Membership Snapshot',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        _member!.membershipStatus == 'active'
                            ? Icons.check_circle_outline
                            : Icons.highlight_off,
                        color: _member!.membershipStatus == 'active'
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Status: ${_member!.membershipStatus.toUpperCase()}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _member!.membershipStatus == 'active'
                                ? Colors.green.shade700
                                : Colors.red.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                      'Expires on: ${DateFormat.yMMMd().format(_member!.subscriptionEndDate)}',
                      style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      child: const Text('View Full Profile'),
                      onPressed: () {
                        _onItemTapped(3); // Switch to Profile tab
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesTab() {
    if (_isLoadingCourses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_courses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No Courses Available',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please check back later for new courses.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Courses'),
                onPressed: _refreshCourses,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        final isEnrolled =
            _member?.enrolledCourseIds?.contains(course.id) ?? false;
        final canEnroll = course.enrolledUids.length < course.maxCapacity;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Icon(Icons.fitness_center,
                  color: Theme.of(context).primaryColor),
            ),
            title: Text(course.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${course.category} - ${course.difficultyLevel}'),
                const SizedBox(height: 4),
                Text('Instructor: ${course.instructor}'),
                const SizedBox(height: 4),
                Text(course.dateTime != null
                    ? '${DateFormat.yMMMd().add_jm().format(course.dateTime!)} (${course.durationMinutes} mins)'
                    : 'Date/Time not set (${course.durationMinutes} mins)'),
                const SizedBox(height: 4),
                Text('Location: ${course.location}'),
                const SizedBox(height: 4),
                Text(
                    'Spots: ${course.enrolledUids.length}/${course.maxCapacity}'),
              ],
            ),
            trailing: isEnrolled
                ? Chip(
                    label: const Text('Enrolled',
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green.shade600,
                    avatar: const Icon(Icons.check_circle,
                        color: Colors.white, size: 18),
                  )
                : ElevatedButton(
                    onPressed: canEnroll
                        ? () async {
                            if (_member == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Member data not loaded. Please try again.')),
                              );
                              return;
                            }
                            try {
                              if (_member?.uid == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'User ID not found. Cannot enroll.')),
                                );
                                return;
                              }
                              await _firestoreService.enrollMemberInCourse(
                                  widget.clientCode,
                                  course.id,
                                  _member!
                                      .uid); // Safe to use ! due to check above

                              // Update local member state immediately for UI responsiveness
                              setState(() {
                                // Assuming _member!.enrolledCourseIds is final and effectively non-nullable (List<String>)
                                // due to Member model's initialization (e.g., List.from(data['enrolledCourseIds'] ?? [])).
                                // If enrolledCourseIds is typed as List<String>?, we need to assert non-nullity if confident.
                                if (_member != null &&
                                    _member!.enrolledCourseIds != null) {
                                  _member!.enrolledCourseIds!.add(course.id);
                                } else {
                                  // Log or handle the unexpected null case. This shouldn't happen if Member.fromFirestore guarantees non-null list.
                                  print(
                                      "Error: _member.enrolledCourseIds is null during UI update. This indicates an issue with member data loading or model initialization.");
                                }
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Successfully enrolled in ${course.name}')),
                              );

                              // Refresh course list from Firestore to ensure consistency
                              await _refreshCourses();
                            } catch (e) {
                              print(
                                  'Error enrolling in course: $e'); // Use print for now
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Error enrolling in course: ${e.toString()}')),
                              );
                            }
                          }
                        : null, // Disable button if full
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canEnroll
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                    child: const Text('Enroll'),
                  ),
            onTap: () {
              // TODO: Navigate to Course Details Page
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'View details for ${course.name} (to be implemented)')),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAttendanceTab() {
    return const Center(
        child: Text('Attendance Page - Coming Soon!',
            style: TextStyle(fontSize: 18)));
  }

  Widget _buildProfileTab() {
    if (_isLoadingMember) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_member == null) {
      return _buildErrorTab('Profile data');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _member!.fullName,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Member ID: ${_member!.clientCode}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Membership Status',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _member!.membershipStatus == 'active'
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: _member!.membershipStatus == 'active'
                            ? Colors.green.shade600
                            : Colors.orange.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _member!.membershipStatus.toUpperCase(),
                        style: TextStyle(
                          color: _member!.membershipStatus == 'active'
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Expires on: ${DateFormat.yMMMd().format(_member!.subscriptionEndDate)}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Information',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _infoRow(Icons.email_outlined, 'Email', _member!.email),
                  _infoRow(
                      Icons.phone_outlined, 'Phone', _member!.primaryPhone),
                  _infoRow(
                      Icons.location_on_outlined, 'Address', _member!.address),
                  _infoRow(Icons.medical_services_outlined, 'Emergency Contact',
                      _member!.emergencyContact),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 3),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Club Dashboard';
      case 1:
        return 'Available Courses'; // Updated title
      case 2:
        return 'Attendance';
      case 3:
        return 'My Profile';
      default:
        return 'Sports Club';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: primaryColor,
        elevation: _currentIndex == 0 ? 0 : 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: (_isLoadingMember && _currentIndex != 1) ||
              (_isLoadingCourses && _currentIndex == 1) ||
              _tabs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
      bottomNavigationBar: _tabs.isEmpty
          ? null
          : BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_outlined),
                    activeIcon: Icon(Icons.dashboard),
                    label: 'Dashboard'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.list_alt_outlined),
                    activeIcon: Icon(Icons.list_alt),
                    label: 'Courses'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.check_circle_outline_outlined),
                    activeIcon: Icon(Icons.check_circle),
                    label: 'Attendance'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile'),
              ],
              currentIndex: _currentIndex,
              selectedItemColor: primaryColor,
              unselectedItemColor: Colors.grey.shade600,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              selectedFontSize: 12,
              unselectedFontSize: 12,
            ),
    );
  }
}
