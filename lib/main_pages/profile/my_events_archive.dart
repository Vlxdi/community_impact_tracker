import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_impact_tracker/main.dart';
import 'package:flutter/material.dart';
import '../../widgets/event_card.dart';

class MyEventsArchive extends StatefulWidget {
  final String userId;

  const MyEventsArchive({super.key, required this.userId});

  @override
  State<MyEventsArchive> createState() => _MyEventsArchiveState();
}

class _MyEventsArchiveState extends State<MyEventsArchive> {
  late final Future<List<Map<String, dynamic>>> _archivedEventsFuture;

  @override
  void initState() {
    super.initState();
    _archivedEventsFuture = _fetchArchivedEvents();
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

      final Set<String> userEventIds =
          userEventsSnapshot.docs.map((doc) => doc.id).toSet();

      // Fetch events from the global collection
      final globalEventsSnapshot = await firestore.collection('events').get();

      // Filter and map events that exist in both collections
      final archivedEvents = globalEventsSnapshot.docs
          .where((doc) => userEventIds.contains(doc.id))
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'eventId': doc.id,
          'name': data['name'] ?? 'Unnamed Event',
          'description': data['description'] ?? 'No description available',
          'image': data['image'],
          'startTime':
              (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'endTime':
              (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'rewardPoints': (data['rewardPoints'] as num?)?.toDouble() ?? 0.0,
          'status': data['status'] ?? 'completed',
          'createdDate':
              (data['createdDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'latitude': data['latitude'] ?? 0.0,
          'longitude': data['longitude'] ?? 0.0,
          'maxParticipants': data['maxParticipants'] ?? 0,
          'currentParticipants': data['currentParticipants'] ?? 0,
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
