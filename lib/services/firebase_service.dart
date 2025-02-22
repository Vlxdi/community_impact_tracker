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
        if (!_isInitialized) {
          _isInitialized = true;
          initializeTimers();
        }
      } else {
        _stopAllTimers();
        _isInitialized = false;
      }
    });
  }

  void _stopAllTimers() {
    _eventActivationTimer?.cancel();
    _absentStatusTimer?.cancel();
    _eventStatusTimer?.cancel();
    _eventCache.clear();
  }

  Future<void> dispose() async {
    _disposedController.add(true);
    _stopAllTimers();
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
    _eventActivationTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _processEventActivation();
    });
  }

  void _startAbsentStatusTimer() {
    _absentStatusTimer?.cancel();
    _absentStatusTimer = Timer.periodic(Duration(seconds: 45), (_) {
      _processAbsentStatus();
    });
  }

  void _startEventStatusTimer() {
    _eventStatusTimer?.cancel();
    _eventStatusTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _processEventStatus();
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
        if (userEventSnapshot.exists) {
          return (userEventSnapshot.data() as Map<String, dynamic>)['status']
                  as String? ??
              'unknown';
        }
        return (eventSnapshot.data() as Map<String, dynamic>)['status']
                as String? ??
            'unknown';
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

    try {
      // Fetch all events that should now be "active"
      QuerySnapshot eventsSnapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'soon')
          .where('startTime', isLessThan: DateTime.now())
          .get();

      if (eventsSnapshot.docs.isEmpty) return;

      // Update global events to "active"
      WriteBatch globalBatch = _firestore.batch();
      Set<String> eventIds = {};

      for (var eventDoc in eventsSnapshot.docs) {
        globalBatch.update(eventDoc.reference, {'status': 'active'});
        eventIds.add(eventDoc.id);
      }

      await globalBatch.commit();

      if (eventIds.isEmpty) return;

      // Update user events from "awaiting" to "active"
      QuerySnapshot userEventsSnapshot = await _firestore
          .collectionGroup('events')
          .where('status', isEqualTo: 'awaiting')
          .get();

      WriteBatch userBatch = _firestore.batch();
      bool hasUserUpdates = false;

      for (var userEventDoc in userEventsSnapshot.docs) {
        if (eventIds.contains(userEventDoc.id)) {
          userBatch.update(userEventDoc.reference, {'status': 'active'});
          hasUserUpdates = true;
        }
      }

      if (hasUserUpdates) {
        await userBatch.commit();
      }
    } catch (e) {
      print('Error in event activation: $e');
    }
  }

  Future<void> _processEventStatus() async {
    if (_disposedController.value) return;

    try {
      // First, handle global events separately
      await _updateGlobalEventsToEnded();

      // Then, handle user events separately
      await _updateUserEventsToEnded();
    } catch (e) {
      print('Error in _processEventStatus: $e');
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

      // Update global events to "ended"
      WriteBatch batch = _firestore.batch();
      for (var eventDoc in events.docs) {
        batch.update(eventDoc.reference, {'status': 'ended'});
      }

      await batch.commit();
    } catch (e) {
      print('Error updating global events to ended: $e');
    }
  }

  Future<void> _updateUserEventsToEnded() async {
    try {
      QuerySnapshot endedGlobalEvents = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'ended')
          .get();

      if (endedGlobalEvents.docs.isEmpty) return;

      List<String> endedEventIds =
          endedGlobalEvents.docs.map((doc) => doc.id).toList();

      QuerySnapshot activeUserEvents = await _firestore
          .collectionGroup('events')
          .where('status', isEqualTo: 'active')
          .get();

      if (activeUserEvents.docs.isEmpty) return;

      WriteBatch batch = _firestore.batch();
      int batchSize = 0;
      DateTime now = DateTime.now();

      for (var userEventDoc in activeUserEvents.docs) {
        if (endedEventIds.contains(userEventDoc.id)) {
          batch.update(userEventDoc.reference, {
            'status': 'overdue',
            'overdueTime': now,
          });
          batchSize++;

          if (batchSize >= 100) {
            await batch.commit();
            batch = _firestore.batch();
            batchSize = 0;
          }
        }
      }

      if (batchSize > 0) {
        await batch.commit();
      }
    } catch (e) {
      print('Error updating user events to overdue: $e');
    }
  }

  Future<void> _processAbsentStatus() async {
    if (_disposedController.value) return;

    try {
      QuerySnapshot overdueEvents = await _firestore
          .collectionGroup('events')
          .where('status', isEqualTo: 'overdue')
          .get();

      if (overdueEvents.docs.isEmpty) return;

      WriteBatch batch = _firestore.batch();
      int batchSize = 0;
      DateTime now = DateTime.now();

      for (var userEventDoc in overdueEvents.docs) {
        DateTime overdueTime =
            (userEventDoc['overdueTime'] as Timestamp).toDate();

        if (now.isAfter(overdueTime.add(Duration(minutes: 1)))) {
          batch.update(userEventDoc.reference, {'status': 'absent'});
          batchSize++;
        }

        if (batchSize >= 100) {
          await batch.commit();
          batch = _firestore.batch();
          batchSize = 0;
        }
      }

      if (batchSize > 0) {
        await batch.commit();
      }
    } catch (e) {
      print('Error processing absent status: $e');
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

      DateTime endTime = eventSnapshot['endTime'].toDate();
      DateTime now = DateTime.now();
      String userStatus = userEventDoc['status'];

      // Only allow check-in during 'ended' status within 1 minute window
      if (userStatus == 'ended' &&
          now.isBefore(endTime.add(Duration(minutes: 1)))) {
        await userEventRef.update({'status': 'participated'});
        print("User checked in, marked as participated!");
      } else {
        await userEventRef.update({'status': 'absent'});
        print("Check-in period expired, marked as absent.");
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
