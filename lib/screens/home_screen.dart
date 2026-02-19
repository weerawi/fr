import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/database_service.dart';
import 'enrollment_screen.dart';
import 'verification_screen.dart';

/// Home screen with options to enroll or verify
class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  int _userCount = 0;
  List<UserFaceData> _registeredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserCount();
  }

  Future<void> _loadUserCount() async {
    setState(() => _isLoading = true);
    
    try {
      final count = await _databaseService.getUserCount();
      final users = await _databaseService.getAllUsers();
      
      setState(() {
        _userCount = count;
        _registeredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user count: $e');
      setState(() => _isLoading = false);
    }
  }

  CameraDescription _getFrontCamera() {
    return widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );
  }

  Future<void> _navigateToEnrollment() async {
    if (widget.cameras.isEmpty) {
      _showError('No camera available');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnrollmentScreen(camera: _getFrontCamera()),
      ),
    );

    if (result != null) {
      _loadUserCount();
    }
  }

  Future<void> _navigateToVerification() async {
    if (_userCount == 0) {
      _showError('No users registered. Please enroll first.');
      return;
    }

    if (widget.cameras.isEmpty) {
      _showError('No camera available');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationScreen(camera: _getFrontCamera()),
      ),
    );

    if (result != null && result['verified'] == true) {
      _showSuccess('Verified as ${result['userName']}');
    }
  }

  Future<void> _deleteUser(UserFaceData user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.userName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _databaseService.deleteUser(user.userId);
      _loadUserCount();
      _showSuccess('${user.userName} deleted');
    }
  }

  Future<void> _deleteAllUsers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Users'),
        content: const Text('Are you sure you want to delete ALL registered users?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _databaseService.deleteAllUsers();
      _loadUserCount();
      _showSuccess('All users deleted');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          if (_userCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _deleteAllUsers,
              tooltip: 'Delete all users',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.deepPurple, Colors.deepPurple.shade300],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.face,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Face Recognition',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lightweight Offline Authentication',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_userCount Registered Users',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      _buildActionButton(
                        icon: Icons.person_add,
                        label: 'Enroll New User',
                        description: 'Register a new face',
                        color: Colors.blue,
                        onPressed: _navigateToEnrollment,
                      ),
                      const SizedBox(height: 20),
                      _buildActionButton(
                        icon: Icons.lock_open,
                        label: 'Verify Identity',
                        description: 'Unlock with your face',
                        color: Colors.green,
                        onPressed: _navigateToVerification,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Registered users list
                if (_registeredUsers.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Registered Users',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      itemCount: _registeredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _registeredUsers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple,
                              child: Text(
                                user.userName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(user.userName),
                            subtitle: Text(
                              '${user.embeddings.length} face samples',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteUser(user),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Text(
                      'No users registered yet.\nTap "Enroll New User" to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color),
          ],
        ),
      ),
    );
  }
}
