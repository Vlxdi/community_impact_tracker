import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/event_card.dart';

class MyEventsArchive extends StatelessWidget {
  final String userId;

  const MyEventsArchive({Key? key, required this.userId}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchArchivedEvents() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      // Fetch events from the user's subcollection
      final userEventsSnapshot = await firestore
          .collection('user_events')
          .doc(userId)
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
      appBar: AppBar(
        title: const Text('My Events Archive'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchArchivedEvents(),
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
              );
            },
          );
        },
      ),
    );
  }
}
