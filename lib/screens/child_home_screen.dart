import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Required for date formatting
import 'package:provider/provider.dart';
import '../models/app_info.dart';
import '../services/app_service.dart';
import '../user_state_manager.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  bool _isTimeUp = false;
  bool _isLoading = true;
  Map<String, int> _usageStats = {}; // To hold usage stats

  // Clock State
  late Timer _timer;
  String _timeString = '';
  String _dateString = '';

  @override
  void initState() {
    super.initState();
    
    // Initialize Clock
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
    
    // Initial Check
    _checkScreenTime();
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

  Future<void> _checkScreenTime() async {
    setState(() {
      _isLoading = true;
    });

    final userManager = context.read<UserStateManager>();
    final appService = context.read<AppService>();

    // 1. Check permissions first
    final hasPermission = await appService.checkUsagePermission();
    if (!hasPermission) {
      setState(() {
        _isTimeUp = false;
        _isLoading = false;
      });
      return;
    }

    // 2. Get current usage stats and store them in the state
    final usageStats = await appService.getUsageStats();
    
    // 3. Calculate total time spent on allowed apps
    final allowedAppsSet = userManager.allowedApps.toSet();
    final totalTimeMs = usageStats.entries
        .where((entry) => allowedAppsSet.contains(entry.key))
        .fold(0, (sum, entry) => sum + entry.value);

    final totalMinutesUsed = (totalTimeMs / 1000 / 60).round();
    final limitMinutes = userManager.screenTimeLimit;

    setState(() {
      _usageStats = usageStats; // Store the fetched stats
      _isTimeUp = totalMinutesUsed >= limitMinutes;
      _isLoading = false;
    });
  }

  Future<void> _launchApp(AppInfo appInfo) async {
    if (_isTimeUp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time is up! You cannot open apps now.')),
      );
      return;
    }
    
    final appService = context.read<AppService>();
    await appService.launchApp(appInfo.packageName);
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
    if (lower.contains('map')) return Icons.map_outlined;
    if (lower.contains('music') || lower.contains('spotify')) return Icons.music_note_outlined;
    if (lower.contains('file')) return Icons.folder_open;
    if (lower.contains('calc')) return Icons.calculate_outlined;
    
    return Icons.grid_view; // Default icon
  }

  // --- Widget for a single app icon in the grid ---
  Widget _buildAppGridItem(BuildContext context, AppInfo appInfo) {
    return InkWell(
      onTap: () => _launchApp(appInfo),
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
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
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
                  color: Colors.grey,
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
                color: Colors.black87,
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
    // Use context.watch to make this widget rebuild when UserStateManager changes
    final userManager = context.watch<UserStateManager>();
    final appService = context.read<AppService>();

    final List<AppInfo> childAllowedApps = appService.allApps.where((app) {
      return userManager.allowedApps.contains(app.packageName);
    }).toList();

    // Recalculate remaining time using the state variable _usageStats
    final limitMinutes = userManager.screenTimeLimit;
    final totalMinutesUsed = (_usageStats.entries
        .where((entry) => userManager.allowedApps.toSet().contains(entry.key))
        .fold(0, (sum, entry) => sum + entry.value) / 1000 / 60).round();
    final remaining = (limitMinutes - totalMinutesUsed).clamp(0, limitMinutes);

    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark, // Makes status bar icons dark
        child: PopScope(
        canPop: false, // Disable back button
        onPopInvoked: (didPop) {
           if (didPop) return;
        },
        child: Scaffold(
          // Fullscreen Gradient Background
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB2EBF2), Color(0xFFC8E6C9)], // Light Blue to Light Green
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // --- Custom Header (Time | Date | Lock) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      children: [
                        Text(
                          _timeString,
                          style: const TextStyle(
                            color: Colors.black87, 
                            fontSize: 18, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text('|', style: TextStyle(color: Colors.black54, fontSize: 18)),
                        ),
                        Text(
                          _dateString,
                          style: const TextStyle(
                            color: Colors.black54, 
                            fontSize: 16
                          ),
                        ),
                        const Spacer(),
                        // Logout Icon
                        InkWell(
                          onTap: userManager.logout,
                          child: const Icon(Icons.lock, color: Colors.black54, size: 20),
                        ),
                      ],
                    ),
                  ),

                  // --- Title & Screen Time Info ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "My",
                                style: TextStyle(
                                  color: Colors.black87, 
                                  fontSize: 32, 
                                  fontWeight: FontWeight.w400
                                ),
                              ),
                              Text(
                                "Apps",
                                style: TextStyle(
                                  color: Colors.black87, 
                                  fontSize: 32, 
                                  fontWeight: FontWeight.w600,
                                  height: 0.9
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Screen Time Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white, // Solid white card
                            borderRadius: BorderRadius.circular(16),
                             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, spreadRadius: 1)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Screen Time",
                                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              ),
                              Text(
                                "Remaining",
                                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$remaining minutes",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // --- Apps Grid or Time's Up ---
                  Expanded(
                    child: _buildBody(childAllowedApps, remaining > 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<AppInfo> childAllowedApps, bool isTimeLeft) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!isTimeLeft) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 20),
            Text(
              'Time\'s Up!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 10),
            Text(
              'You have used your screen time for today.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Allow manual refresh just in case
                _checkScreenTime(); 
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87
              ),
              child: const Text('Check Again')
            )
          ],
        ),
      );
    }

    if (childAllowedApps.isEmpty) {
      return Center(
        child: Text(
          'No allowed apps found.\nAsk your parent to add some!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18.0, color: Colors.grey[700]),
        ),
      );
    }

    // Scrollable App Grid
    return RawScrollbar(
      thumbColor: Colors.black26,
      radius: const Radius.circular(20),
      thickness: 4,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        itemCount: childAllowedApps.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 20.0,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          return _buildAppGridItem(context, childAllowedApps[index]);
        },
      ),
    );
  }
}
