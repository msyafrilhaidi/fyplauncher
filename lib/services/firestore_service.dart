import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'settings';
  static const String _documentId = 'control_data';

  // --- 1. Fetch ALL settings (PINs, allowed apps, screen limit) ---
  Future<Map<String, dynamic>?> getControlData() async {
    try {
      DocumentSnapshot snapshot =
      await _db.collection(_collection).doc(_documentId).get();

      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      } else {
        // If the document doesn't exist, create it with initial data
        await _initializeControlData();
        // Fetch the newly created data
        return getControlData();
      }
    } catch (e) {
      debugPrint('Firestore Error (getControlData): $e');
      return null;
    }
  }

  // --- 2. Initialize database with default PINs ---
  Future<void> _initializeControlData() async {
    // Note: These PINs must be changed by the parent immediately after setup.
    final Map<String, dynamic> initialData = {
      'parentPin': '0000',
      'childPin': '1234',
      'allowedApps': <String>[], // Start with no allowed apps
      'screenTimeLimit': 120, // Default limit: 120 minutes (2 hours)
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    await _db.collection(_collection).doc(_documentId).set(initialData);
  }

  // --- 3. Update the Allowed App List ---
  Future<void> updateAllowedApps(List<String> allowedPackageNames) async {
    try {
      await _db.collection(_collection).doc(_documentId).update({
        'allowedApps': allowedPackageNames,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint('Firestore: Allowed apps list updated.');
    } catch (e) {
      debugPrint('Firestore Error (updateAllowedApps): $e');
    }
  }

  // --- 4. Update Screen Time Limit ---
  Future<void> updateScreenTimeLimit(int minutes) async {
    try {
      await _db.collection(_collection).doc(_documentId).update({
        'screenTimeLimit': minutes,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint('Firestore: Screen time limit updated to $minutes mins.');
    } catch (e) {
      debugPrint('Firestore Error (updateScreenTimeLimit): $e');
    }
  }

  // --- 5. Update PINs (Flexible update for one or both PINs) ---
  Future<bool> updatePins(Map<String, String> pinUpdates) async {
    // 1. Build the update map
    final Map<String, dynamic> updates = {
      ...pinUpdates,
      // Always update the timestamp to track the change
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (updates.isEmpty) {
      debugPrint('Firestore: No PIN updates provided.');
      return true; // Nothing to update
    }

    try {
      // 2. Use the update method to change specific fields
      await _db.collection(_collection).doc(_documentId).update(updates);
      debugPrint('Firestore: PINs updated successfully: $pinUpdates');
      return true;
    } catch (e) {
      debugPrint('Firestore Error (updatePins): $e');
      return false;
    }
  }
}
