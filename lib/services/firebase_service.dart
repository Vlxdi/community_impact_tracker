import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _eventActivationTimer;
  Timer? _absentStatusTimer;
  Timer? _eventStatusTimer;
  StreamSubscription<User?>? _authStateSubscription;
  final _disposedController = BehaviorSubject<bool>.seeded(false);
  bool _isInitialized = false;

  // Cache for event data with timestamps
  final Map<String, _CachedEvent> _eventCache = {};
  final Duration _cacheExpiration = Duration(minutes: 5);

  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal() {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    _authStateSubscription = _auth.authStateChanges().listen((User? user) {
      if (user != null && !_disposedController.value) {
        _isInitialized = true;
        // Initialize timers when user logs in
        initializeTimers();
      } else {
        _isInitialized = false;
        // Cancel timers when user logs out
        _cancelTimers();
      }
    });
  }

  void _cancelTimers() {
    _eventActivationTimer?.cancel();
    _absentStatusTimer?.cancel();
    _eventStatusTimer?.cancel();
  }

  Future<void> dispose() async {
    _disposedController.add(true);
    _cancelTimers();
    await _authStateSubscription?.cancel();
    await _disposedController.close();
  }

  String? getCurrentUserId() => _auth.currentUser?.uid;

  void initializeTimers() {
    if (_disposedController.value || getCurrentUserId() == null) return;

    _startEventActivationTimer();
    _startAbsentStatusTimer();
    _startEventStatusTimer();
  }

  void _startEventActivationTimer() {
    _eventActivationTimer?.cancel();
    _eventActivationTimer = Timer.periodic(Duration(seconds: 20), (_) {
      _processEventActivation();
    });
  }

  void _startAbsentStatusTimer() {
    _absentStatusTimer?.cancel();
    _absentStatusTimer = Timer.periodic(Duration(seconds: 15), (_) {
      _processAbsentStatus();
    });
  }

  void _startEventStatusTimer() {
    _eventStatusTimer?.cancel();
    _eventStatusTimer = Timer.periodic(Duration(seconds: 10), (_) {
      _processEventStatus();
      _processEndedToOverdue();
    });
  }

  Future<DocumentSnapshot?> _getCachedEvent(String eventId) async {
    final now = DateTime.now();

    if (_eventCache.containsKey(eventId)) {
      final cachedEvent = _eventCache[eventId]!;
      if (now.difference(cachedEvent.timestamp) < _cacheExpiration) {
        return cachedEvent.snapshot;
      }
      _eventCache.remove(eventId);
    }

    try {
      final snapshot = await _firestore.collection('events').doc(eventId).get();
      if (snapshot.exists) {
        _eventCache[eventId] = _CachedEvent(
          snapshot: snapshot,
          timestamp: now,
        );
      }
      return snapshot;
    } catch (e) {
      print('Error fetching event: $e');
      return null;
    }
  }

  Stream<String> getEventStatusStream(String eventId) {
    String? userId = getCurrentUserId();
    if (userId == null) {
      return Stream.value('unknown');
    }

    Stream<DocumentSnapshot> eventStream =
        _firestore.collection('events').doc(eventId).snapshots();

    Stream<DocumentSnapshot> userEventStream = _firestore
        .collection('user_events')
        .doc(userId)
        .collection('events')
        .doc(eventId)
        .snapshots();

    return Rx.combineLatest2(
      eventStream,
      userEventStream,
      (DocumentSnapshot eventSnapshot, DocumentSnapshot userEventSnapshot) {
        if (!eventSnapshot.exists) return 'unknown';

        // Get the global event data
        Map<String, dynamic> eventData =
            eventSnapshot.data() as Map<String, dynamic>;
        String globalStatus = eventData['status'] as String? ?? 'unknown';

        // If user has a specific status for this event, use that
        if (userEventSnapshot.exists) {
          return (userEventSnapshot.data() as Map<String, dynamic>)['status']
                  as String? ??
              'unknown';
        }

        // NEW: If event has ended and user has no record, show as 'absent'
        if (globalStatus == 'ended' || globalStatus == 'overdue') {
          // Check if the event has already ended (by comparing endTime with now)
          if (eventData.containsKey('endTime')) {
            DateTime endTime = (eventData['endTime'] as Timestamp).toDate();
            if (DateTime.now().isAfter(endTime)) {
              return 'absent';
            }
          }
        }

        // Otherwise return the global status
        return globalStatus;
      },
    ).onErrorReturn('unknown');
  }

  Future<void> signUpForEvent(String eventId) async {
    String? userId = getCurrentUserId();
    if (userId == null) throw Exception("User not logged in");

    DocumentSnapshot? eventSnapshot = await _getCachedEvent(eventId);
    if (eventSnapshot == null || !eventSnapshot.exists) {
      throw Exception("Event not found!");
    }

    DateTime startTime = eventSnapshot['startTime'].toDate();
    if (DateTime.now().isAfter(startTime)) {
      throw Exception("Event has already started!");
    }

    try {
      await _firestore
          .collection('user_events')
          .doc(userId)
          .collection('events')
          .doc(eventId)
          .set({
        'status': 'awaiting',
        'signUpTime': FieldValue.serverTimestamp(),
      });
      print("User signed up for the event!");
    } catch (e) {
      print("Error signing up for event: $e");
      rethrow;
    }
  }

  Future<void> _processEventActivation() async {
    if (_disposedController.value) return;
    String? currentUserId = getCurrentUserId();
    if (currentUserId == null) return;

    try {
      // Find events that need to become active
      QuerySnapshot soonEvents = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'soon')
          .where('startTime', isLessThan: DateTime.now())
          .get();

      if (soonEvents.docs.isEmpty) return;

      // Update global events status
      WriteBatch globalBatch = _firestore.batch();
      Set<String> activatedEventIds = {};

      for (var eventDoc in soonEvents.docs) {
        globalBatch.update(eventDoc.reference, {'status': 'active'});
        activatedEventIds.add(eventDoc.id);
      }

      try {
        await globalBatch.commit();
        print("Updated ${activatedEventIds.length} global events to active");
      } catch (e) {
        print("Error updating global events to active: $e");
        // If global update fails, don't try to update user events
        return;
      }

      if (activatedEventIds.isEmpty) return;

      // Only update the current user's events
      WriteBatch userBatch = _firestore.batch();
      int updates = 0;

      for (String eventId in activatedEventIds) {
        DocumentReference userEventRef = _firestore
            .collection('user_events')
            .doc(currentUserId)
            .collection('events')
            .doc(eventId);

        try {
          DocumentSnapshot userEventDoc = await userEventRef.get();

          if (userEventDoc.exists && userEventDoc.get('status') == 'awaiting') {
            userBatch.update(userEventRef, {'status': 'active'});
            updates++;
          }
        } catch (e) {
          print("Error processing event $eventId for user $currentUserId: $e");
        }
      }

      if (updates > 0) {
        try {
          await userBatch.commit();
          print("Updated $updates events to active for user $currentUserId");
        } catch (e) {
          print("Error updating user events batch: $e");
        }
      }
    } catch (e) {
      print('Error in _processEventActivation: $e');
    }
  }

  Future<void> _processEventStatus() async {
    if (_disposedController.value) return;

    try {
      // First handle global events separately with improved error handling
      await _updateGlobalEventsToEnded();

      // Then handle user events separately
      String? currentUserId = getCurrentUserId();
      if (currentUserId != null) {
        await _updateUserEventsToEnded(currentUserId);

        // NEW: Handle events the user never signed up for
        await _createAbsentRecordsForMissedEvents(currentUserId);
      }
    } catch (e) {
      print('Error in _processEventStatus: $e');
    }
  }

  // New method to create absent records for events the user didn't sign up for
  Future<void> _createAbsentRecordsForMissedEvents(String userId) async {
    try {
      // Get all ended events from the last 24 hours (to limit the query)
      final DateTime oneDayAgo = DateTime.now().subtract(Duration(days: 1));
      QuerySnapshot recentEndedEvents = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'ended')
          .where('endTime', isGreaterThan: oneDayAgo)
          .get();

      if (recentEndedEvents.docs.isEmpty) return;

      // Get all events the user is already registered for
      QuerySnapshot userEvents = await _firestore
          .collection('user_events')
          .doc(userId)
          .collection('events')
          .get();

      // Create a set of event IDs the user is already registered for
      Set<String> registeredEventIds =
          userEvents.docs.map((doc) => doc.id).toSet();

      // Find events that the user hasn't registered for
      List<String> missedEventIds = recentEndedEvents.docs
          .where((doc) => !registeredEventIds.contains(doc.id))
          .map((doc) => doc.id)
          .toList();

      if (missedEventIds.isEmpty) return;

      // Create 'absent' records for each missed event
      int successCount = 0;
      for (String eventId in missedEventIds) {
        try {
          await _firestore
              .collection('user_events')
              .doc(userId)
              .collection('events')
              .doc(eventId)
              .set({
            'status': 'absent',
            'absentReason': 'not_signed_up',
            'createdAt': FieldValue.serverTimestamp(),
          });
          successCount++;
        } catch (e) {
          print('Error creating absent record for event $eventId: $e');
        }
      }

      if (successCount > 0) {
        print('Created $successCount absent records for missed events');
      }
    } catch (e) {
      print('Error in _createAbsentRecordsForMissedEvents: $e');
    }
  }

  Future<void> _updateGlobalEventsToEnded() async {
    try {
      // Get events that should be ended
      QuerySnapshot events = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'active')
          .where('endTime', isLessThan: DateTime.now())
          .limit(20)
          .get();

      if (events.docs.isEmpty) return;

      // Update global events to "ended" with better error handling
      int successCount = 0;
      for (var eventDoc in events.docs) {
        try {
          await eventDoc.reference.update({'status': 'ended'});
          successCount++;
        } catch (e) {
          print('Error updating event ${eventDoc.id} to ended: $e');
        }
      }

      print('Successfully updated $successCount global events to ended');
    } catch (e) {
      print('Error in _updateGlobalEventsToEnded: $e');
    }
  }

  Future<void> _updateUserEventsToEnded(String userId) async {
    if (_disposedController.value) return;

    try {
      // Get global events that have ended
      QuerySnapshot endedGlobalEvents = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'ended')
          .get();

      if (endedGlobalEvents.docs.isEmpty) return;

      List<String> endedEventIds =
          endedGlobalEvents.docs.map((doc) => doc.id).toList();

      // Get the current user's active events
      QuerySnapshot activeUserEvents = await _firestore
          .collection('user_events')
          .doc(userId)
          .collection('events')
          .where('status', isEqualTo: 'active')
          .get();

      if (activeUserEvents.docs.isEmpty) return;

      int successCount = 0;
      // Process each event individually for better error handling
      for (var userEventDoc in activeUserEvents.docs) {
        if (endedEventIds.contains(userEventDoc.id)) {
          try {
            await userEventDoc.reference.update({
              'status': 'ended',
              'endedTime': FieldValue.serverTimestamp(),
            });
            successCount++;
          } catch (e) {
            print('Error updating user event ${userEventDoc.id} to ended: $e');
          }
        }
      }

      print('Successfully updated $successCount user events to ended');
    } catch (e) {
      print('Error in _updateUserEventsToEnded: $e');
    }
  }

  Future<void> _processEndedToOverdue() async {
    if (_disposedController.value) return;
    String? currentUserId = getCurrentUserId();
    if (currentUserId == null) return;

    try {
      // Get the current user's ended events
      QuerySnapshot endedUserEvents = await _firestore
          .collection('user_events')
          .doc(currentUserId)
          .collection('events')
          .where('status', isEqualTo: 'ended')
          .get();

      if (endedUserEvents.docs.isEmpty) return;

      int successCount = 0;
      DateTime now = DateTime.now();

      // Process each event individually for better error handling
      for (var userEventDoc in endedUserEvents.docs) {
        Map<String, dynamic>? data =
            userEventDoc.data() as Map<String, dynamic>?;

        if (data != null &&
            data.containsKey('endedTime') &&
            data['endedTime'] != null) {
          DateTime endedTime = (data['endedTime'] as Timestamp).toDate();

          if (now.isAfter(endedTime.add(Duration(minutes: 1)))) {
            try {
              await userEventDoc.reference.update({
                'status': 'overdue',
                'overdueTime': now,
              });
              successCount++;
            } catch (e) {
              print('Error updating event ${userEventDoc.id} to overdue: $e');
            }
          }
        } else {
          // If endedTime is missing, update based on current time
          try {
            await userEventDoc.reference.update({
              'status': 'overdue',
              'overdueTime': now,
            });
            successCount++;
          } catch (e) {
            print('Error updating event ${userEventDoc.id} to overdue: $e');
          }
        }
      }

      if (successCount > 0) {
        print('Successfully updated $successCount user events to overdue');
      }
    } catch (e) {
      print('Error in _processEndedToOverdue: $e');
    }
  }

  Future<void> _processAbsentStatus() async {
    if (_disposedController.value) return;
    String? currentUserId = getCurrentUserId();
    if (currentUserId == null) return;

    try {
      // Only get the current user's overdue events
      QuerySnapshot overdueEvents = await _firestore
          .collection('user_events')
          .doc(currentUserId)
          .collection('events')
          .where('status', isEqualTo: 'overdue')
          .get();

      if (overdueEvents.docs.isEmpty) return;

      int successCount = 0;
      DateTime now = DateTime.now();

      // Process each event individually for better error handling
      for (var userEventDoc in overdueEvents.docs) {
        DateTime overdueTime =
            (userEventDoc['overdueTime'] as Timestamp).toDate();

        if (now.isAfter(overdueTime.add(Duration(minutes: 1)))) {
          try {
            await userEventDoc.reference.update({'status': 'absent'});
            successCount++;
          } catch (e) {
            print('Error updating event ${userEventDoc.id} to absent: $e');
          }
        }
      }

      if (successCount > 0) {
        print('Successfully updated $successCount user events to absent');
      }
    } catch (e) {
      print('Error in _processAbsentStatus: $e');
    }
  }

  Future<void> checkInForEvent(String eventId) async {
    String? userId = getCurrentUserId();
    if (userId == null) throw Exception("User not logged in");

    try {
      DocumentSnapshot? eventSnapshot = await _getCachedEvent(eventId);
      if (eventSnapshot == null || !eventSnapshot.exists) {
        throw Exception("Event not found!");
      }

      DocumentReference userEventRef = _firestore
          .collection('user_events')
          .doc(userId)
          .collection('events')
          .doc(eventId);

      DocumentSnapshot userEventDoc = await userEventRef.get();

      if (!userEventDoc.exists) {
        throw Exception("User is not registered for this event");
      }

      String userStatus = userEventDoc['status'];

      // Allow check-in during 'ended' or 'overdue' status
      if (userStatus == 'ended' || userStatus == 'overdue') {
        await userEventRef.update({'status': 'participated'});
        await addPointsToWallet(eventId);
        print("User checked in, marked as participated!");
        return;
      } else if (userStatus == 'absent') {
        throw Exception("You were marked as absent. Cannot check in anymore.");
      } else if (userStatus == 'participated') {
        throw Exception("You have already checked in for this event!");
      } else {
        throw Exception("Cannot check in with current status: $userStatus");
      }
    } catch (e) {
      print("Error checking in for event: $e");
      rethrow;
    }
  }
}

class _CachedEvent {
  final DocumentSnapshot snapshot;
  final DateTime timestamp;

  _CachedEvent({
    required this.snapshot,
    required this.timestamp,
  });
}

// Reward recieving system

Future<void> addPointsToWallet(String eventId) async {
  try {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    // Fetch the event reward points
    DocumentSnapshot eventSnapshot =
        await firestore.collection('events').doc(eventId).get();
    if (!eventSnapshot.exists) {
      throw Exception("Event not found.");
    }
    int rewardPoints = eventSnapshot.get('rewardPoints');

    // Fetch the user's current wallet balance
    DocumentReference userRef = firestore.collection('users').doc(userId);
    DocumentSnapshot userSnapshot = await userRef.get();
    int currentBalance =
        userSnapshot.exists ? userSnapshot.get('wallet_balance') ?? 0 : 0;

    // Update the wallet balance
    int newBalance = currentBalance + rewardPoints;
    await userRef.update({'wallet_balance': newBalance});

    print("✅ Points added successfully! New Balance: $newBalance");
  } catch (e) {
    print("❌ Error updating wallet: $e");
  }
}
