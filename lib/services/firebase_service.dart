import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get the current user's ID
  String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // Sign up for an event
  Future<void> signUpForEvent(String eventId) async {
    String? userId = getCurrentUserId();
    if (userId == null) {
      throw Exception("User not logged in");
    }

    DocumentReference eventRef = _firestore.collection('events').doc(eventId);
    DocumentSnapshot eventSnapshot = await eventRef.get();

    if (!eventSnapshot.exists) {
      throw Exception("Event not found!");
    }

    DateTime startTime = eventSnapshot['startTime'].toDate();
    DateTime now = DateTime.now();

    if (now.isAfter(startTime)) {
      throw Exception("Event has already started!");
    }

    await _firestore
        .collection('user_events')
        .doc(userId)
        .collection('events')
        .doc(eventId)
        .set({
      'status': 'awaiting',
      'signUpTime': now,
    });

    await eventRef.update({'status': 'awaiting'});

    print("User signed up for the event!");
  }
}
