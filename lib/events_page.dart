import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  // final TextEditingController latitudeController = TextEditingController();
  // final TextEditingController longitudeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchEventsFromFirebase();
  }

  void fetchEventsFromFirebase() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('events').get();
      print("Fetched ${querySnapshot.docs.length} events");

      setState(() {
        events = querySnapshot.docs.map((doc) {
          print("Processing event: ${doc['name']}");

          return {
            'name': doc['name'],
            'description': doc['description'],
            'startTime': (doc['startTime'] as Timestamp).toDate(),
            'endTime': (doc['endTime'] as Timestamp).toDate(),
            'createdDate': (doc['createdDate'] as Timestamp).toDate(),
            'rewardPoints': doc['rewardPoints'],
            'status': doc['status'],
          };
        }).toList();
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
    print("Event ID: ${events[index]['docId']}");
    print("Event Status: ${events[index]['status']}");

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
                  createdDate: event['createdDate'],
                  //location: event['location'],
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
  final DateTime createdDate;
  // final GeoPoint location;
  final int rewardPoints;
  final String status;
  final VoidCallback onSignIn;

  const EventCard({
    super.key,
    required this.name,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.createdDate,
    //required this.location,
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
          // Left side: Map, title, and description (70% or 75%)
          Flexible(
            flex: 7,
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
                //Add Google maps API
                Container(
                  height: 170,
                  color: Colors.grey[300],
                  child: Center(child: Text("Map here")),
                ),
              ],
            ),
          ),
          // Vertical separator line
          Container(
            width: 2,
            height: 260,
            color: Colors.grey[300],
            margin: EdgeInsets.symmetric(horizontal: 12),
          ),
          // Right side: Event details (30% or 25%)
          Flexible(
            flex: 3,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Unactive",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                // Event details below the status container
                Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Starts: ${formatDate(startTime)}"),
                      Text("Ends: ${formatDate(endTime)}"),
                      Text("Reward: $rewardPoints⭐"),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Call the dialog method here
                          _showEventSignUpDialog(context);
                        }, // Replacing action with "Sign Up"
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(
                              horizontal: 15,
                            )),
                        child: Text(
                          "Sign Up",
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(DateTime date) {
    return DateFormat('d MMM yyyy, hh:mm a').format(date);
  }

  void _showEventSignUpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            padding: EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      'https://via.placeholder.com/300',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Event Title
                  Text(
                    name.isNotEmpty ? name : "Event Name",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Event Description
                  Text(
                    description.isNotEmpty
                        ? description
                        : "No description provided",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),

                  // Event Date & Location
                  Text(
                    'Created on: ${formatDate(createdDate)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Location: Community Hall, Downtown',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),

                  // Sign-Up Button
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // Add sign-up logic here
                        // Retrieves data from user's account resistration
                        Navigator.of(context).pop(); // Close dialog on click
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      ),
                      child: Text(
                        "Sign Up",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
