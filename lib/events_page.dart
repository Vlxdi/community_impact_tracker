import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  String selectedFilter = 'Filter 1';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> events = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEventsFromFirebase();
  }

  void fetchEventsFromFirebase() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('events').get();
      setState(() {
        events = querySnapshot.docs.map((doc) {
          return {
            'name': doc['name'],
            'description': doc['description'],
            'startTime': (doc['startTime'] as Timestamp).toDate(),
            'endTime': (doc['endTime'] as Timestamp).toDate(),
            'rewardPoints': doc['rewardPoints'],
            'status': doc['status'],
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching events: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void handleSignIn(int index) async {
    try {
      setState(() {
        events[index]['status'] = 'Awaiting';
      });

      final docId = events[index]['docId'];
      await _firestore
          .collection('events')
          .doc(docId)
          .update({'status': 'Awaiting'});
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('EEEE, d MMMM').format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

    return Scaffold(
      appBar: AppBar(
        title: Text('Community Impact Tracker'),
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
          SizedBox(
            height: 6,
          ),

          // Events below
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return EventCard(
                  name: event['name'],
                  description: event['description'],
                  startTime: event['startTime'],
                  endTime: event['endTime'],
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

// EventCard widget
class EventCard extends StatelessWidget {
  final String name;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final int rewardPoints;
  final String status;
  final VoidCallback onSignIn;

  const EventCard({
    super.key,
    required this.name,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.rewardPoints,
    required this.status,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side: Map, title, and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : "Event Name",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  description.isNotEmpty
                      ? description
                      : "No description provided",
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                SizedBox(height: 8),
                Container(
                  height: 100,
                  color: Colors.grey[300],
                  child: Center(child: Text("Map here")),
                ),
              ],
            ),
          ),
          // Vertical separator line
          Container(
            width: 2,
            height: 100,
            color: Colors.grey[300],
            margin: EdgeInsets.symmetric(horizontal: 12),
          ),
          // Right side: Event details
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Starts: ${formatDate(startTime)}"),
              Text("Ends: ${formatDate(endTime)}"),
              Text("Reward: $rewardPoints⭐"),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: status == 'Not Signed Up' ? onSignIn : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      status == 'Not Signed Up' ? Colors.blue : Colors.grey,
                ),
                child: Text(status == 'Not Signed Up' ? "Sign In" : status),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String formatDate(DateTime date) {
    return DateFormat('d MMM yyyy, hh:mm a').format(date);
  }
}
