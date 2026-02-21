import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_info.dart';
import '../services/app_service.dart';
import '../user_state_manager.dart';
import '../services/firestore_service.dart';

class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({super.key});

  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  // State for Custom Tabs
  int _selectedIndex = 0;

  // Set of package names that are currently toggled ON for the child
  late Set<String> _allowedAppsSet;
  late Future<List<AppInfo>> _appsFuture;

  // Controllers for the PIN update form
  final TextEditingController _parentPinController = TextEditingController();
  final TextEditingController _parentPinConfirmController = TextEditingController();
  final TextEditingController _childPinController = TextEditingController();
  final TextEditingController _childPinConfirmController = TextEditingController();

  // Usage Stats State
  bool _hasUsagePermission = false;
  bool _hasNotificationPermission = false;
  Map<String, int> _usageStats = {};
  bool _isLoadingStats = false;

  // Screen Time Limit State
  int _screenTimeLimit = 120; 
  final TextEditingController _limitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final userManager = Provider.of<UserStateManager>(context, listen: false);
    _allowedAppsSet = userManager.allowedApps.toSet();
    _screenTimeLimit = userManager.screenTimeLimit;
    _limitController.text = _screenTimeLimit.toString();

    final appService = Provider.of<AppService>(context, listen: false);
    if (appService.allApps.isNotEmpty) {
      _appsFuture = Future.value(appService.allApps);
    } else {
      _appsFuture = appService.getInstalledApps();
    }

    _checkPermissions();
  }

  @override
  void dispose() {
    _parentPinController.dispose();
    _parentPinConfirmController.dispose();
    _childPinController.dispose();
    _childPinConfirmController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final appService = context.read<AppService>();
    final usage = await appService.checkUsagePermission();
    final notification = await appService.checkNotificationPermission();
    setState(() {
      _hasUsagePermission = usage;
      _hasNotificationPermission = notification;
    });
    if (usage) {
      _fetchUsageStats();
    }
  }

  Future<void> _fetchUsageStats() async {
    setState(() => _isLoadingStats = true);
    final appService = context.read<AppService>();
    final stats = await appService.getUsageStats();
    setState(() {
      _usageStats = stats;
      _isLoadingStats = false;
    });
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Helper to update Allowed Apps immediately
  void _toggleAppPermission(String packageName, bool allowed) async {
    setState(() {
      if (allowed) {
        _allowedAppsSet.add(packageName);
      } else {
        _allowedAppsSet.remove(packageName);
      }
    });
    // Save immediately
    final userManager = context.read<UserStateManager>();
    await userManager.updateAllowedApps(_allowedAppsSet.toList());
  }

  // Helper to update Screen Time Limit
  void _updateScreenLimit(int limit) async {
    setState(() {
      _screenTimeLimit = limit;
    });
    final userManager = context.read<UserStateManager>();
    await userManager.updateScreenTimeLimit(limit);
  }

  // Helper to update Passwords
  void _changePassword(String type, String newPin, String confirmPin) async {
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits.')));
      return;
    }
    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs do not match.')));
      return;
    }

    final firestoreService = context.read<FirestoreService>();
    final userManager = context.read<UserStateManager>();
    
    bool success = false;
    if (type == 'parent') {
      success = await firestoreService.updatePins({'parentPin': newPin});
    } else {
      success = await firestoreService.updatePins({'childPin': newPin});
    }

    if (success) {
      // Force reload
      await userManager.authenticate('0000'); // Reloads data internally
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$type Password Changed Successfully')));
      if (type == 'parent') {
        _parentPinController.clear();
        _parentPinConfirmController.clear();
      } else {
        _childPinController.clear();
        _childPinConfirmController.clear();
      }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update PIN.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F38), // Dark Navy Background
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FE), // Light Grey/White Card
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                // --- Header ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Parental Controls',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.black87),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // --- Custom Tab Bar (Now Scrollable) ---
                _buildCustomTabBar(),

                const Divider(height: 1, thickness: 1, color: Colors.black12),

                // --- Tab Content ---
                Expanded(
                  child: _buildTabContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      height: 60,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildTabItem(0, Icons.security, 'App Permissions'),
            const SizedBox(width: 12), 
            _buildTabItem(1, Icons.show_chart, 'Activity Log'),
            const SizedBox(width: 12),
            _buildTabItem(2, Icons.access_time, 'Screen Time'),
            const SizedBox(width: 12),
            _buildTabItem(3, Icons.vpn_key, 'Passwords'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isSelected ? BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ) : null,
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.black87 : Colors.black45),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.black87 : Colors.black45
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedIndex) {
      case 0: return _buildAppPermissionsTab();
      case 1: return _buildActivityLogTab();
      case 2: return _buildScreenTimeTab();
      case 3: return _buildPasswordsTab();
      default: return _buildAppPermissionsTab();
    }
  }

  // ---------------- TAB 1: App Permissions ----------------
  Widget _buildAppPermissionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("Allowed Apps for Child Mode", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text("Toggle which apps are visible and accessible in Child Mode", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AppInfo>>(
            future: _appsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final apps = snapshot.data!;
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  final app = apps[index];
                  bool isAllowed = _allowedAppsSet.contains(app.packageName);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF536DFE), Color(0xFF7C4DFF)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: app.iconBytes != null 
                              ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(app.iconBytes!, fit: BoxFit.cover))
                              : const Icon(Icons.android, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(app.appName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Switch(
                          value: isAllowed,
                          activeColor: Colors.black,
                          onChanged: (val) => _toggleAppPermission(app.packageName, val),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(),
        _buildSystemPermissionsSection(),
      ],
    );
  }

  // --- System Permissions Section (New ListView implementation) ---
  Widget _buildSystemPermissionsSection() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("System Permissions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text("Enable these permissions for full functionality.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          // Using ListView for the two permission items
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildPermissionTile(
                icon: Icons.show_chart,
                title: "Usage Stats Access",
                subtitle: "Required to monitor screen time and log activity.",
                isGranted: _hasUsagePermission,
                onGrant: () async {
                  final appService = context.read<AppService>();
                  await appService.requestUsagePermission();
                  await Future.delayed(const Duration(seconds: 1)); // Give user time to return
                  _checkPermissions();
                },
              ),
              const SizedBox(height: 12),
              _buildPermissionTile(
                icon: Icons.notifications_active,
                title: "Notification Access",
                subtitle: "Required to block unwanted notifications in Child Mode.",
                isGranted: _hasNotificationPermission,
                onGrant: () async {
                  final appService = context.read<AppService>();
                  await appService.requestNotificationPermission();
                  await Future.delayed(const Duration(seconds: 1));
                  _checkPermissions();
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPermissionTile({required IconData icon, required String title, required String subtitle, required bool isGranted, required VoidCallback onGrant}) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
            children: [
                Icon(icon, color: Colors.black54),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                    ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                    onPressed: isGranted ? null : onGrant,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isGranted ? Colors.grey[300] : Colors.black87,
                        disabledBackgroundColor: Colors.green[400], // Green when granted
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                    ),
                    child: Text(isGranted ? "Granted" : "Grant"),
                )
            ],
        ),
    );
  }


  // ---------------- TAB 2: Activity Log ----------------
  Widget _buildActivityLogTab() {
    if (!_hasUsagePermission) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("Usage Stats permission is required to view activity. Please enable it in the App Permissions tab.", textAlign: TextAlign.center),
        )
      );
    }
    if (_isLoadingStats) return const Center(child: CircularProgressIndicator());

    final childStats = _usageStats.entries
        .where((entry) => _allowedAppsSet.contains(entry.key))
        .toList();
    
    final totalTimeMs = childStats.fold(0, (sum, entry) => sum + entry.value);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Child Activity Log", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("View detailed usage history", style: TextStyle(fontSize: 12, color: Colors.grey)),
              TextButton(
                onPressed: _fetchUsageStats,
                style: TextButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text("Refresh", style: TextStyle(color: Colors.black87, fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Total Screen Time", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(totalTimeMs),
                        style: const TextStyle(color: Color(0xFF1565C0), fontSize: 20, fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purple.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Apps Used", style: TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text("${childStats.length}", style: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          Expanded(
            child: childStats.isEmpty 
              ? const Center(child: Text("No activity logged yet", style: TextStyle(color: Colors.grey)))
              : FutureBuilder<List<AppInfo>>(
                  future: _appsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final apps = snapshot.data!;
                    
                    childStats.sort((a, b) => b.value.compareTo(a.value));
                    
                    return ListView.builder(
                      itemCount: childStats.length,
                      itemBuilder: (context, index) {
                        final entry = childStats[index];
                        final app = apps.firstWhere(
                          (a) => a.packageName == entry.key, 
                          orElse: () => AppInfo(appName: entry.key, packageName: entry.key)
                        );
                        final duration = Duration(milliseconds: entry.value);
                        
                        return ListTile(
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: app.iconBytes != null 
                                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(app.iconBytes!, fit: BoxFit.cover))
                                : const Icon(Icons.android, size: 20),
                          ),
                          title: Text(app.appName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          trailing: Text("${duration.inMinutes}m", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                        );
                      },
                    );
                  }
                ),
          ),
        ],
      ),
    );
  }

  // ---------------- TAB 3: Screen Time ----------------
  Widget _buildScreenTimeTab() {
    final childStats = _usageStats.entries
        .where((entry) => _allowedAppsSet.contains(entry.key));
    final totalTimeMs = childStats.fold(0, (sum, entry) => sum + entry.value);
    final totalMins = (totalTimeMs / 1000 / 60).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Screen Time Management", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text("Set daily screen time limits for Child Mode", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 24),
          
          const Text("Daily Screen Time Limit (minutes)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _limitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "120",
                    ),
                    onSubmitted: (val) {
                      final limit = int.tryParse(val);
                      if (limit != null) _updateScreenLimit(limit);
                    },
                    onEditingComplete: () {
                      final limit = int.tryParse(_limitController.text);
                      if (limit != null) {
                        _updateScreenLimit(limit);
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ),
                const Text("minutes", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text("Enter the number of minutes allowed per day", style: TextStyle(fontSize: 11, color: Colors.grey)),
          
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Current Usage", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text("$totalMins / $_screenTimeLimit min", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    TextButton(
                      onPressed: _fetchUsageStats,
                      style: TextButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Refresh", style: TextStyle(color: Colors.black87)),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _screenTimeLimit > 0 ? (totalMins / _screenTimeLimit).clamp(0.0, 1.0) : 0.0,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    color: totalMins >= _screenTimeLimit ? Colors.redAccent : Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- TAB 4: Passwords ----------------
  Widget _buildPasswordsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Password Management", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text("Change the passwords for Parent Mode and Child Mode", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.security, size: 18, color: Colors.purple),
                    SizedBox(width: 8),
                    Text("Parent Mode Password", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPasswordField("New Password", _parentPinController),
                const SizedBox(height: 12),
                _buildPasswordField("Confirm Password", _parentPinConfirmController),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _changePassword('parent', _parentPinController.text, _parentPinConfirmController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD087F6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Change Parent Password", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.key, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text("Child Mode Password", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPasswordField("New Password", _childPinController),
                const SizedBox(height: 12),
                _buildPasswordField("Confirm Password", _childPinConfirmController),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _changePassword('child', _childPinController.text, _childPinConfirmController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF64B5F6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Change Child Password", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(String hint, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 4,
        obscureText: true,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          counterText: "",
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
