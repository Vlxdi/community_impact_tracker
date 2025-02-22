import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_impact_tracker/services/firebase_service.dart';
import 'package:community_impact_tracker/utils/AddSpace.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../widgets/event_card.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> events = [];
  Map<String, StreamSubscription<String>> statusSubscriptions = {};
  String selectedFilter = 'Filter 1';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEventsFromFirebase();

    // Initialize all timers through FirebaseService
    _firebaseService.initializeTimers();
  }

  @override
  void dispose() {
    // Cancel all status stream subscriptions
    for (var subscription in statusSubscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  void fetchEventsFromFirebase() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('events').get();
      print("Fetched ${querySnapshot.docs.length} events");

      // First, cancel existing subscriptions
      for (var subscription in statusSubscriptions.values) {
        subscription.cancel();
      }
      statusSubscriptions.clear();

      List<Map<String, dynamic>> fetchedEvents = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        GeoPoint location = data['location'] as GeoPoint;
        String eventId = doc.id;

        Map<String, dynamic> eventData = {
          'eventId': eventId,
          'name': data['name'] ?? 'Unnamed Event',
          'description': data['description'] ?? 'No description available',
          'image': data['image'],
          'startTime': (data['startTime'] as Timestamp).toDate(),
          'endTime': (data['endTime'] as Timestamp).toDate(),
          'createdDate': (data['createdDate'] as Timestamp).toDate(),
          'rewardPoints': data['rewardPoints'] ?? 0,
          'status': data['status'] ?? 'pending',
          'latitude': location.latitude,
          'longitude': location.longitude,
        };

        fetchedEvents.add(eventData);

        // Set up status stream subscription for this event
        statusSubscriptions[eventId] =
            _firebaseService.getEventStatusStream(eventId).listen((status) {
          setState(() {
            // Find the event in our list and update its status
            for (int i = 0; i < events.length; i++) {
              if (events[i]['eventId'] == eventId) {
                events[i]['status'] = status;
                break;
              }
            }
          });
        });
      }

      setState(() {
        events = fetchedEvents;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching events: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void handleSignIn(int index) async {
    String eventId = events[index]['eventId'];

    try {
      await _firebaseService.signUpForEvent(eventId);
      // Don't update the status here - let the stream handle it
    } catch (e) {
      print('Error signing up: $e');
      // Show error message to user
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('EEEE, d MMMM').format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 25),
            children: <TextSpan>[
              TextSpan(
                text: 'Good',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF71CD8C),
                ),
              ),
              TextSpan(
                text: 'Track',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.calendar_month_rounded),
                    onPressed: () {},
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.notifications),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),

          //This week
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, bottom: 8),
              child: Text(
                'This Week',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          //Chips
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: Text(
                      'ongoing',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: const Color.fromARGB(177, 177, 177, 177),
                    selected: selectedFilter == 'Ongoing',
                    showCheckmark: false,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedFilter = 'Ongoing';
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  ),
                  ChoiceChip(
                    label: Text(
                      'recently ended',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: const Color.fromARGB(177, 177, 177, 177),
                    selected: selectedFilter == 'recently ended',
                    showCheckmark: false,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedFilter = 'recently ended';
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  ),
                  ChoiceChip(
                    label: Text(
                      'upcoming',
                      style: TextStyle(fontSize: 12),
                    ),
                    backgroundColor: const Color.fromARGB(177, 177, 177, 177),
                    selected: selectedFilter == 'upcoming',
                    showCheckmark: false,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedFilter = 'upcoming';
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  ),
                ],
              ),
            ),
          ),
          Vspace(6),

          // Events section
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
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
                  status: event['status'],
                  onSignIn: () => handleSignIn(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
