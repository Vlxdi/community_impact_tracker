import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/event_card.dart';

class MyEventsArchive extends StatefulWidget {
  final String userId;

  const MyEventsArchive({super.key, required this.userId});

  @override
  State<MyEventsArchive> createState() => _MyEventsArchiveState();
}

class _MyEventsArchiveState extends State<MyEventsArchive> {
  Future<List<Map<String, dynamic>>>? _archivedEventsFuture;

  @override
  void initState() {
    super.initState();
    // Only fetch once
    _archivedEventsFuture ??= _fetchArchivedEvents();
  }

  Future<List<Map<String, dynamic>>> _fetchArchivedEvents() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      // Fetch events from the user's subcollection
      final userEventsSnapshot = await firestore
          .collection('user_events')
          .doc(widget.userId)
          .collection('events')
          .get();

      // Only include events where 'absentReason' field does NOT exist
      final userEventDocs = userEventsSnapshot.docs
          .where((doc) => !doc.data().containsKey('absentReason'))
          .toList();

      // Fetch events from the global collection
      final globalEventsSnapshot = await firestore.collection('events').get();
      final Map<String, dynamic> globalEventsMap = {
        for (var doc in globalEventsSnapshot.docs) doc.id: doc.data()
      };

      // Build archived events using the user's event status
      final archivedEvents = userEventDocs.map((userDoc) {
        final eventId = userDoc.id;
        final userData = userDoc.data();
        final globalData = globalEventsMap[eventId] ?? {};

        return {
          'eventId': eventId,
          'name': globalData['name'] ?? 'Unnamed Event',
          'description':
              globalData['description'] ?? 'No description available',
          'image': globalData['image'],
          'startTime': (globalData['startTime'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          'endTime':
              (globalData['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'rewardPoints':
              (globalData['rewardPoints'] as num?)?.toDouble() ?? 0.0,
          // Use the user's event status if available, otherwise fallback to global
          'status': userData['status'] ?? globalData['status'] ?? 'completed',
          'createdDate': (globalData['createdDate'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          'latitude': globalData['latitude'] ?? 0.0,
          'longitude': globalData['longitude'] ?? 0.0,
          'maxParticipants': globalData['maxParticipants'] ?? 0,
          'currentParticipants': globalData['currentParticipants'] ?? 0,
        };
      }).toList();

      return archivedEvents;
    } catch (e) {
      print("Error fetching archived events: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar:
          true, // Added this line to extend content behind app bar
      appBar: AppBar(
        title: const Text('My Events Archive'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _archivedEventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text("Failed to load archived events."),
            );
          }

          final archivedEvents = snapshot.data ?? [];

          if (archivedEvents.isEmpty) {
            return const Center(child: Text("No archived events found."));
          }

          return ListView.builder(
            // Added padding at the top to prevent content from clipping through app bar
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 8, 16, 16),
            itemCount: archivedEvents.length,
            itemBuilder: (context, index) {
              final event = archivedEvents[index];
              return EventCard(
                name: event['name'],
                description: event['description'],
                eventId: event['eventId'],
                image: event['image'],
                startTime: event['startTime'],
                endTime: event['endTime'],
                rewardPoints: event['rewardPoints'],
                status: event['status'],
                createdDate: event['createdDate'],
                latitude: event['latitude'],
                longitude: event['longitude'],
                maxParticipants: event['maxParticipants'],
                currentParticipants: event['currentParticipants'],
                onSignIn: () {}, // Archived events don't need this
                forceShowImage: true, // <-- Image will always be shown
              );
            },
          );
        },
      ),
    );
  }
}
