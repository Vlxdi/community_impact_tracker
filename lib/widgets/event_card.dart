import 'dart:async';
import 'dart:convert';
import 'package:community_impact_tracker/services/firebase_service.dart';
import 'package:community_impact_tracker/utils/addSpace.dart';
import 'package:community_impact_tracker/utils/getStatusColor.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  final double rewardPoints;
  final int maxParticipants;
  final String status;
  final int currentParticipants;
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
    required this.maxParticipants,
    required this.status,
    required this.currentParticipants, // New field added
    required this.onSignIn,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  GoogleMapController? mapController;
  late final Set<Marker> markers;
  final FirebaseService _firebaseService = FirebaseService();
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  String? checkinToken;

  @override
  void initState() {
    super.initState();
    markers = {
      Marker(
        markerId: MarkerId('eventLocation'),
        position: LatLng(widget.latitude, widget.longitude),
        infoWindow: InfoWindow(title: widget.name),
      ),
    };
    _fetchCheckinToken(); // Fetch the check-in token from Firebase
    _startTimer();
  }

  Future<void> _fetchCheckinToken() async {
    try {
      final token = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get()
          .then((doc) => doc.data()?['checkin_token'] as String?);

      if (mounted) {
        setState(() {
          checkinToken = token;
        });
      }
    } catch (e) {
      print("Error fetching check-in token: $e");
    }
  }

  void _startTimer() {
    if (widget.status != 'active') return;

    DateTime now = DateTime.now();

    // Determine whether we are counting down to start or end
    if (now.isBefore(widget.startTime)) {
      _timeRemaining =
          widget.startTime.difference(now); // Countdown to start time
    } else {
      _timeRemaining = widget.endTime.difference(now); // Countdown to end time
    }

    if (_timeRemaining.isNegative) {
      _timeRemaining = Duration.zero;
      setState(() {}); // Update UI to show 0:0:0 if negative
      return;
    }

    // Start the timer
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          DateTime now = DateTime.now();

          if (now.isBefore(widget.startTime)) {
            _timeRemaining = widget.startTime.difference(now);
          } else {
            _timeRemaining = widget.endTime.difference(now);
          }

          if (_timeRemaining.isNegative) {
            _timeRemaining = Duration.zero;
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant EventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status && widget.status == 'active') {
      _timer?.cancel();
      _startTimer();
    }
  }

  String getButtonText(String status) {
    if (status == 'ended' || status == 'overdue') {
      return "Check In";
    } else if (status == 'awaiting' ||
        status == 'active' ||
        status == 'participated' ||
        status == 'absent') {
      return "Details";
    }
    return "Sign Up";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: _firebaseService.getEventStatusStream(widget.eventId),
      initialData: widget.status,
      builder: (context, snapshot) {
        final currentStatus = snapshot.data ?? widget.status;

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
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: true,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 260,
                color: Colors.grey[300],
                margin: EdgeInsets.symmetric(horizontal: 12),
              ),
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
                          color: getStatusColor(currentStatus),
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          currentStatus,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.status == 'active' &&
                              _timeRemaining > Duration.zero)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                "Time Remaining: ${_timeRemaining.inHours}:${_timeRemaining.inMinutes.remainder(60)}:${_timeRemaining.inSeconds.remainder(60)}",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red),
                              ),
                            )
                          else
                            Column(
                              children: [
                                Text("Starts: ${formatDate(widget.startTime)}"),
                                Text("Ends: ${formatDate(widget.endTime)}"),
                              ],
                            ),
                          Text("Reward: ${widget.rewardPoints.ceil()}⭐"),
                          Vspace(8),
                          ElevatedButton(
                            onPressed: () {
                              if (currentStatus == 'ended' ||
                                  currentStatus == 'overdue') {
                                _showEventCheckInDialog(
                                    context, widget.eventId);
                              } else {
                                _showEventSignUpDialog(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(horizontal: 15),
                            ),
                            child: Text(
                              getButtonText(currentStatus),
                              style:
                                  TextStyle(fontSize: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String formatDate(DateTime date) {
    return DateFormat('d MMM yyyy, hh:mm a').format(date);
  }

  // Sign in information dialog
  void _showEventSignUpDialog(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();

    // Get the current user's ID
    String? userId = firebaseService.getCurrentUserId();
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
                    SizedBox(
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
                    'Location: (${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)})',
                    style: TextStyle(fontSize: 16),
                  ),
                  Vspace(4),

                  // Display the number of signed-up users
                  FutureBuilder<int>(
                    future: _getSignedUpUsersCount(widget.eventId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text(
                          'Loading signed-up users...',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        );
                      } else if (snapshot.hasError) {
                        return Text(
                          'Error loading signed-up users',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${snapshot.data} users have already signed up!',
                              style: TextStyle(fontSize: 16),
                            ),
                            Vspace(4),
                            Text(
                              'Max participants: ${widget.maxParticipants}',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[700]),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  Vspace(20),
                  Text(
                    'Created on: ${formatDate(widget.createdDate)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Vspace(4),
                  // Sign-Up Button
                  Center(
                    child: widget.status != 'awaiting' &&
                            widget.status != 'active' &&
                            widget.status != 'absent' &&
                            widget.status != 'participated'
                        ? ElevatedButton(
                            onPressed: () async {
                              try {
                                await firebaseService
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

  // Fetch the number of signed-up users for the event
  Future<int> _getSignedUpUsersCount(String eventId) async {
    try {
      final userDocsSnapshot = await FirebaseFirestore.instance
          .collection('user_events')
          .get(); // Fetch all user documents in the "user_events" collection

      print(
          'Documents fetched in user_events: ${userDocsSnapshot.docs.length}'); // Debug print

      int count = 0;

      for (var userDoc in userDocsSnapshot.docs) {
        print('Checking user document ID: ${userDoc.id}'); // Debug print

        final eventDoc = await userDoc.reference
            .collection('events')
            .doc(eventId)
            .get(); // Check if the event exists in the user's "events" collection

        if (eventDoc.exists) {
          print('Event found for user: ${userDoc.id}'); // Debug print
          count++; // Increment the count if the event exists
        }
      }

      print('Total users signed up for event $eventId: $count'); // Debug print
      return count;
    } catch (e) {
      print('Error fetching signed-up users count: $e');
      return 0;
    }
  }

  void _showEventCheckInDialog(BuildContext context, String eventId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text("Scan QR Code"),
          ),
          body: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) async {
                  final List<Barcode> barcodes = capture.barcodes;

                  if (barcodes.isNotEmpty) {
                    final String? scannedCode = barcodes.first.rawValue;

                    if (scannedCode == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                "Failed to scan QR code. Please try again.")),
                      );
                      return;
                    }

                    // Close the scanner screen immediately after scanning
                    Navigator.of(context).pop();

                    try {
                      // Validate the scanned QR code value against the check-in token
                      if (scannedCode == checkinToken) {
                        // Handle successful match
                        await _handleSuccessfulMatch(context, eventId);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  "Invalid QR code for this event. Please check the code and try again.")),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                "Error processing QR code: ${e.toString()}")),
                      );
                      print("QR Code Error: $e"); // Log the error for debugging
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text("No QR code detected. Please try again.")),
                    );
                  }
                },
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Align the QR code within the box to scan",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Separate function to handle the async operations
  Future<void> _handleSuccessfulMatch(
      BuildContext context, String eventId) async {
    try {
      await _firebaseService.checkInForEvent(eventId);

      // Check if widget is still mounted before accessing context
      if (!mounted) return;

      // Show success popup
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 80,
              ),
              SizedBox(height: 16),
              Text(
                "Successfully checked in",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      // Check if widget is still mounted before accessing context
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during check-in: $e")),
      );
    }
  }
}
