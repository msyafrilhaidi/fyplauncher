import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart'; // Used for service access
import 'services/firestore_service.dart';
// REMOVE: This import is no longer needed since FieldValue is not used here.
// import 'package:cloud_firestore/cloud_firestore.dart';

// 1. Define the possible user modes
enum UserMode {
  loggedOut,
  parentMode,
  childMode,
}

class UserStateManager extends ChangeNotifier {
  // Use private variables to store data fetched from Firestore
  String _parentPin = '';
  String _childPin = '';
  List<String> _allowedApps = [];
  int _screenTimeLimit = 120; // Default to 120 minutes

  UserMode _currentMode = UserMode.loggedOut;
  UserMode get currentMode => _currentMode;
  List<String> get allowedApps => _allowedApps; // New public getter
  int get screenTimeLimit => _screenTimeLimit; // Getter for screen time limit

  final FirestoreService _firestoreService; // Hold the service instance

  // Constructor now requires the service
  UserStateManager(this._firestoreService) {
    _loadPinsAndSettings();
  }

  // Load the stored settings from Firestore
  Future<void> _loadPinsAndSettings() async {
    // CORRECT: Delegating the database call to the injected service
    final data = await _firestoreService.getControlData();

    if (data != null) {
      _parentPin = data['parentPin'] as String;
      _childPin = data['childPin'] as String;
      // Firestore returns a List<dynamic>, so we cast it to List<String>
      _allowedApps = List<String>.from(data['allowedApps'] ?? []);
      // Load screen time limit, default to 120 if missing
      _screenTimeLimit = (data['screenTimeLimit'] as int?) ?? 120;
    } else {
      // Handle the case where initial data could not be retrieved
      debugPrint("Warning: Could not fetch initial control data from Firestore.");
    }
    _currentMode = UserMode.loggedOut;
    notifyListeners();
  }

// Authentication Logic (Uses Firestore data)
  Future<bool> authenticate(String pin) async {
    // Reload data before checking to ensure we have the latest PINs
    await _loadPinsAndSettings();

    if (pin == _parentPin) {
      _currentMode = UserMode.parentMode;
      notifyListeners();
      return true;
    } else if (pin == _childPin) {
      _currentMode = UserMode.childMode;
      notifyListeners();
      return true;
    }
    _currentMode = UserMode.loggedOut;
    notifyListeners();
    return false;
  }

  // 3. Logout Function
  void logout() {
    _currentMode = UserMode.loggedOut;
    notifyListeners();
  }

  // Function to handle updates from the settings screen
  Future<void> updateAllowedApps(List<String> newAllowedApps) async {
    await _firestoreService.updateAllowedApps(newAllowedApps);
    _allowedApps = newAllowedApps; // Update local cache
    notifyListeners();
  }

  // New: Function to update screen time limit
  Future<void> updateScreenTimeLimit(int minutes) async {
    await _firestoreService.updateScreenTimeLimit(minutes);
    _screenTimeLimit = minutes;
    notifyListeners();
  }
}
