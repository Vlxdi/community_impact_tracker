import 'package:flutter/material.dart';
import 'package:community_impact_tracker/widgets/event_card.dart';

Widget buildEventCard({
  required BuildContext context,
  required Map<String, dynamic> event,
  required VoidCallback onSignIn,
}) {
  return EventCard(
    name: event['name'],
    description: event['description'],
    eventId: event['eventId'],
    image: event['image'],
    startTime: event['startTime'],
    endTime: event['endTime'],
    createdDate: event['createdDate'],
    latitude: event['latitude'],
    longitude: event['longitude'],
    rewardPoints: event['rewardPoints'],
    maxParticipants: event['maxParticipants'],
    currentParticipants: event['currentParticipants'],
    status: event['status'],
    onSignIn: onSignIn,
  );
}
