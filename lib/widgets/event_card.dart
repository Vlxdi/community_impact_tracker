import 'dart:ui';
import 'package:community_impact_tracker/services/firebase_service.dart';
import 'package:community_impact_tracker/utils/AddSpace.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EventCard extends StatefulWidget {
  final String name;
  final String description;
  final String eventId;
  final String? image;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdDate;
  final double latitude;
  final double longitude;
  final int rewardPoints;
  final String status;
  final VoidCallback onSignIn;

  const EventCard({
    super.key,
    required this.name,
    required this.description,
    required this.eventId,
    this.image,
    required this.startTime,
    required this.endTime,
    required this.createdDate,
    required this.latitude,
    required this.longitude,
    required this.rewardPoints,
    required this.status,
    required this.onSignIn,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  GoogleMapController? mapController;
  late final Set<Marker> markers;
  final FirebaseService _firebaseService = FirebaseService();
  late String status;

  @override
  void initState() {
    super.initState();
    status = widget.status;

    // Initialize markers with event location
    markers = {
      Marker(
        markerId: MarkerId('eventLocation'),
        position: LatLng(widget.latitude, widget.longitude),
        infoWindow: InfoWindow(title: widget.name),
      ),
    };
  }

  void updateStatus(String newStatus) {
    setState(() {
      status = newStatus; // Update the status in real-time
    });
  }

  // Color getStatusColor(String status) {
  //   switch (status) {
  //     case 'soon':
  //       return Colors.grey;
  //     case 'awaiting':
  //       return Colors.blue;
  //     case 'Active':
  //       return Colors.green;
  //     case 'ended':
  //       return Colors.orange;
  //     case 'overdue':
  //       return Colors.red;
  //     case 'absent':
  //     case 'participated':
  //       return Colors.grey[800]!;
  //     default:
  //       return Colors.black;
  //   }
  // }

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
          Flexible(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Vspace(4),
                Text(
                  widget.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Vspace(8),
                Container(
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: LatLng(widget.latitude, widget.longitude),
                      zoom: 15.0,
                    ),
                    markers: markers,
                    mapType: MapType.normal,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
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
                      color: status == 'soon'
                          ? Colors.grey[300]
                          : status == 'awaiting'
                              ? Colors.blue
                              : status == 'active'
                                  ? Colors.green
                                  : status == 'ended'
                                      ? Colors.orange
                                      : status == 'overdue'
                                          ? Colors.red
                                          : status == 'absent' ||
                                                  status == 'participated'
                                              ? Colors.grey[800]
                                              : Colors.transparent,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      status,
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
                      Text("Starts: ${formatDate(widget.startTime)}"),
                      Text("Ends: ${formatDate(widget.endTime)}"),
                      Text("Reward: ${widget.rewardPoints}⭐"),
                      Vspace(8),
                      ElevatedButton(
                        onPressed: () {
                          // Check if the status is 'ended' or 'overdue' to show the check-in dialog
                          if (widget.status == 'ended' ||
                              widget.status == 'overdue') {
                            _showEventCheckInDialog(context,
                                widget.eventId); // Open the check-in dialog
                          } else {
                            // Otherwise, show the sign-up dialog
                            _showEventSignUpDialog(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(horizontal: 15),
                        ),
                        child: Text(
                          // Change the button text based on the status
                          widget.status == 'ended' || widget.status == 'overdue'
                              ? "Check In" // If status is 'ended' or 'overdue', show "Check In"
                              : widget.status == 'awaiting' ||
                                      widget.status == 'active' ||
                                      widget.status == 'participated' ||
                                      widget.status == 'absent'
                                  ? "Details" // Show "Details" for other statuses
                                  : "Sign Up", // Otherwise, show "Sign Up"
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

  // Sign in information dialog
  void _showEventSignUpDialog(BuildContext context) {
    final FirebaseService _firebaseService = FirebaseService();

    // Get the current user's ID
    String? userId = _firebaseService.getCurrentUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("You must be signed in to join an event."),
        backgroundColor: Colors.red,
      ));
      return;
    }

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
                  if (widget.image != null && widget.image!.isNotEmpty)
                    Container(
                      height: 200,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.image!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    ),
                  Vspace(16),

                  // Event Title
                  Text(
                    widget.name.isNotEmpty ? widget.name : "Event Name",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Vspace(8),

                  Text(
                    widget.description.isNotEmpty
                        ? widget.description
                        : "No description provided",
                    style: TextStyle(fontSize: 16),
                  ),
                  Vspace(16),

                  Text(
                    'Created on: ${formatDate(widget.createdDate)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Vspace(4),
                  Text(
                    'Location: Coming soon...',
                    style: TextStyle(fontSize: 16),
                  ),
                  Vspace(20),

                  // Sign-Up Button
                  Center(
                    child: widget.status != 'awaiting' ||
                            widget.status != 'active' ||
                            widget.status != 'absent' ||
                            widget.status != 'participated'
                        ? ElevatedButton(
                            onPressed: () async {
                              try {
                                await _firebaseService
                                    .signUpForEvent(widget.eventId);
                                Navigator.of(context)
                                    .pop(); // Close dialog on success
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text("Signed up successfully!"),
                                  backgroundColor: Colors.green,
                                ));
                              } catch (e) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text("Error: ${e.toString()}"),
                                  backgroundColor: Colors.red,
                                ));
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 10),
                            ),
                            child: Text(
                              "Sign Up",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          )
                        : SizedBox
                            .shrink(), // Hides the button when status is "Awaiting"
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEventCheckInDialog(BuildContext context, String eventId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Are you ready to check in?'),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                try {
                  await _firebaseService.checkInForEvent(eventId);
                  Navigator.of(context)
                      .pop(); // Close the dialog after successful check-in
                } catch (e) {
                  // Handle error (you can show a message to the user here)
                  print('Error: $e');
                  Navigator.of(context)
                      .pop(); // Close the dialog even if there's an error
                }
              },
              child: Text('Check In'),
            ),
          ],
        );
      },
    );
  }
}
