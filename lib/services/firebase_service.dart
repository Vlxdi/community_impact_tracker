import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  // Activate Event when startTime is reached
  Future<void> activateEvent(String eventId) async {
    DocumentReference eventRef = _firestore.collection('events').doc(eventId);
    DocumentSnapshot eventSnapshot = await eventRef.get();

    if (!eventSnapshot.exists) {
      throw Exception("Event not found!");
    }

    DateTime startTime = eventSnapshot['startTime'].toDate();
    DateTime now = DateTime.now();

    if (now.isAfter(startTime)) {
      // Only activate if event is in 'soon' or 'awaiting' status
      String currentStatus = eventSnapshot['status'];
      if (currentStatus == 'soon' || currentStatus == 'awaiting') {
        await eventRef.update({'status': 'active'});
        print("Event $eventId is now Active!");
      }
    }
  }

  // Periodically check and update event status
  void startEventActivationListener() {
    Timer.periodic(Duration(minutes: 1), (timer) async {
      QuerySnapshot eventsSnapshot = await _firestore
          .collection('events')
          .where('status', whereIn: ['soon', 'awaiting']).get();

      for (var eventDoc in eventsSnapshot.docs) {
        await activateEvent(eventDoc.id);
      }
    });
  }

  // Helper function to update status in user_events collection for current user
  Future<void> updateUserEventStatus(String eventId, String newStatus) async {
    String? userId = getCurrentUserId();
    if (userId == null) return;

    DocumentReference userEventRef = _firestore
        .collection('user_events')
        .doc(userId)
        .collection('events')
        .doc(eventId);

    // Check if user has this event
    DocumentSnapshot eventCheck = await userEventRef.get();
    if (eventCheck.exists) {
      await userEventRef.update({'status': newStatus});
      print("Updated user event status to $newStatus for event $eventId");
    }
  }

  // Update events that are active or ended
  Future<void> updateEventStatuses() async {
    DateTime now = DateTime.now();

    QuerySnapshot eventSnapshot = await _firestore
        .collection('events')
        .where('status', whereIn: ['soon', 'awaiting', 'active']).get();

    for (var doc in eventSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      DateTime startTime = (data['startTime'] as Timestamp).toDate();
      DateTime endTime = (data['endTime'] as Timestamp).toDate();
      String currentStatus = data['status'];
      String eventId = doc.id;

      // If the event has started and it's not already active
      if (now.isAfter(startTime) &&
          now.isBefore(endTime) &&
          (currentStatus == 'soon' || currentStatus == 'awaiting')) {
        // Update main event status
        await _firestore
            .collection('events')
            .doc(eventId)
            .update({'status': 'active'});
        print("Updated event $eventId to Active");

        // Update user event status if they're signed up
        await updateUserEventStatus(eventId, 'active');
      }

      // If the event has ended and it's not in a final state
      if (now.isAfter(endTime) &&
          !['ended', 'overdue', 'participated', 'absent']
              .contains(currentStatus)) {
        // Update main event status
        await _firestore
            .collection('events')
            .doc(eventId)
            .update({'status': 'ended'});
        print("Updated event $eventId to Ended");

        // Update user event status if they're signed up
        await updateUserEventStatus(eventId, 'ended');
      }
    }
  }

// Periodically check for events that ended and update status accordingly
  void startAbsentStatusListener() {
    Timer.periodic(Duration(seconds: 30), (timer) async {
      String? userId = getCurrentUserId();
      if (userId == null) return;

      DateTime now = DateTime.now();

      // First, get the current user's signed up events that are in 'ended' status
      QuerySnapshot userEndedEvents = await _firestore
          .collection('user_events')
          .doc(userId)
          .collection('events')
          .where('status', isEqualTo: 'ended')
          .get();

      // For each ended event the user is signed up for
      for (var userEventDoc in userEndedEvents.docs) {
        String eventId = userEventDoc.id;

        // Get the main event document
        DocumentSnapshot eventDoc =
            await _firestore.collection('events').doc(eventId).get();

        if (!eventDoc.exists) continue;

        DateTime endTime = eventDoc['endTime'].toDate();

        // Check if 10 minutes have passed since event ended
        if (now.isAfter(endTime.add(Duration(minutes: 1)))) {
          // Move to overdue since we know the user is signed up
          // Update main event
          await _firestore
              .collection('events')
              .doc(eventId)
              .update({'status': 'overdue'});
          print("Event $eventId moved to overdue status");

          // Update user event
          await updateUserEventStatus(eventId, 'overdue');
        }
      }

      // Handle overdue events for current user
      QuerySnapshot userOverdueEvents = await _firestore
          .collection('user_events')
          .doc(userId)
          .collection('events')
          .where('status', isEqualTo: 'overdue')
          .get();

      for (var userEventDoc in userOverdueEvents.docs) {
        String eventId = userEventDoc.id;

        // Get the main event document
        DocumentSnapshot eventDoc =
            await _firestore.collection('events').doc(eventId).get();

        if (!eventDoc.exists) continue;

        DateTime endTime = eventDoc['endTime'].toDate();

        // Check if 25 minutes have passed since event ended (10 + 15)
        if (now.isAfter(endTime.add(Duration(minutes: 2)))) {
          // Move to absent since overdue period has passed
          // Update main event
          await _firestore
              .collection('events')
              .doc(eventId)
              .update({'status': 'absent'});
          print("Event $eventId marked as absent after overdue period");

          // Update user event
          await updateUserEventStatus(eventId, 'absent');
        }
      }
    });
  }

// Check-in for an event
  Future<void> checkInForEvent(String eventId) async {
    String? userId = getCurrentUserId();
    if (userId == null) {
      throw Exception("User not logged in");
    }

    DocumentReference eventRef = _firestore.collection('events').doc(eventId);
    DocumentSnapshot eventSnapshot = await eventRef.get();

    if (!eventSnapshot.exists) {
      throw Exception("Event not found!");
    }

    DateTime endTime = eventSnapshot['endTime'].toDate();
    DateTime now = DateTime.now();
    String currentStatus = eventSnapshot['status'];

    // Check if user is registered for the event
    DocumentSnapshot userEventDoc = await _firestore
        .collection('user_events')
        .doc(userId)
        .collection('events')
        .doc(eventId)
        .get();

    if (!userEventDoc.exists) {
      throw Exception("User is not registered for this event");
    }

    // Allow check-in during ended or overdue status if user is registered
    if ((currentStatus == 'ended' &&
            now.isBefore(endTime.add(Duration(minutes: 1)))) ||
        (currentStatus == 'overdue' &&
            now.isBefore(endTime.add(Duration(minutes: 2))))) {
      // Mark user as 'participated'
      await _firestore
          .collection('user_events')
          .doc(userId)
          .collection('events')
          .doc(eventId)
          .update({'status': 'participated'});

      // Update event status to 'participated'
      await eventRef.update({'status': 'participated'});
      print("User checked in, event marked as participated!");
    } else {
      // If past the grace period, mark as 'absent'
      await _firestore
          .collection('user_events')
          .doc(userId)
          .collection('events')
          .doc(eventId)
          .update({'status': 'absent'});

      // Update event status to 'absent'
      await eventRef.update({'status': 'absent'});
      print("Check-in period expired, event marked as absent.");
    }
  }
}
