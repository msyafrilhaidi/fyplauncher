import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fyplauncher/screens/parent_settings_screen.dart';
import 'package:provider/provider.dart';
import '../models/app_info.dart';
import '../services/app_service.dart';
import '../user_state_manager.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  late Future<List<AppInfo>> _appsFuture;
  
  // Clock State
  late Timer _timer;
  String _timeString = '';
  String _dateString = '';

  @override
  void initState() {
    super.initState();
    final appService = Provider.of<AppService>(context, listen: false);
    _appsFuture = appService.getInstalledApps();

    // Initialize Clock
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    setState(() {
      _timeString = DateFormat('HH:mm').format(now);
      _dateString = DateFormat('EEE, MMM d').format(now);
    });
  }

  // Helper to get a relevant icon based on package name (Fallback)
  IconData _getIconForPackage(String packageName) {
    final String lower = packageName.toLowerCase();
    if (lower.contains('chrome') || lower.contains('browser')) return Icons.public;
    if (lower.contains('youtube')) return Icons.play_arrow_rounded;
    if (lower.contains('camera')) return Icons.camera_alt_outlined;
    if (lower.contains('gallery') || lower.contains('photos')) return Icons.photo_outlined;
    if (lower.contains('message') || lower.contains('sms')) return Icons.chat_bubble_outline;
    if (lower.contains('phone') || lower.contains('dialer')) return Icons.phone_outlined;
    if (lower.contains('calendar')) return Icons.calendar_today;
    if (lower.contains('clock') || lower.contains('alarm')) return Icons.access_time;
    if (lower.contains('setting')) return Icons.settings_outlined;
    if (lower.contains('map')) return Icons.map_outlined;
    if (lower.contains('music') || lower.contains('spotify')) return Icons.music_note_outlined;
    if (lower.contains('file')) return Icons.folder_open;
    if (lower.contains('mail') || lower.contains('gmail')) return Icons.mail_outline;
    if (lower.contains('store') || lower.contains('play')) return Icons.shopping_bag_outlined;
    if (lower.contains('calc')) return Icons.calculate_outlined;
    if (lower.contains('contact')) return Icons.people_outline;
    
    return Icons.grid_view; // Default icon
  }

  // --- Widget for a single app icon in the grid ---
  Widget _buildAppGridItem(BuildContext context, AppInfo appInfo) {
    final appService = Provider.of<AppService>(context, listen: false);

    return InkWell(
      onTap: () => appService.launchApp(appInfo.packageName),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Icon Container
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              // Gradient background
              gradient: appInfo.iconBytes == null ? const LinearGradient(
                colors: [Color(0xFF536DFE), Color(0xFF7C4DFF)], // Blue to Purple
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) : null,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF536DFE).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            // Display Real Icon or Fallback Icon
            child: appInfo.iconBytes != null 
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(
                    appInfo.iconBytes!,
                    fit: BoxFit.cover,
                  ),
                )
              : Icon(
                  _getIconForPackage(appInfo.packageName),
                  size: 30.0,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8.0),
          // App Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              appInfo.appName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.0, 
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userManager = context.read<UserStateManager>();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1F38), // Dark Navy Background
        body: SafeArea(
          child: Column(
            children: [
              // --- Header Section ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  children: [
                    Text(
                      _timeString,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text('|', style: TextStyle(color: Colors.white54, fontSize: 18)),
                    ),
                    Text(
                      _dateString,
                      style: const TextStyle(
                        color: Colors.white70, 
                        fontSize: 16
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      "Parent Mode",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(width: 10),
                    // Logout Icon
                    InkWell(
                      onTap: userManager.logout,
                      child: const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
                    ),
                  ],
                ),
              ),

              // --- Title & Settings Button ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Home",
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 32, 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                    // Parental Controls Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ParentSettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text("Parental Controls"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2979FF), // Bright Blue
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // --- Apps Grid ---
              Expanded(
                child: FutureBuilder<List<AppInfo>>(
                  future: _appsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No apps found.', style: const TextStyle(color: Colors.white)));
                    } else {
                      final apps = snapshot.data!;
                      
                      return RawScrollbar(
                        thumbColor: Colors.white24,
                        radius: const Radius.circular(20),
                        thickness: 4,
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                          itemCount: apps.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4, // 4 Icons per row
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 20.0,
                            childAspectRatio: 0.75, // Taller to fit text below
                          ),
                          itemBuilder: (context, index) {
                            return _buildAppGridItem(context, apps[index]);
                          },
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
