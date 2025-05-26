import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:community_impact_tracker/services/firebase_service.dart';
import 'package:community_impact_tracker/utils/addSpace.dart';
import 'package:community_impact_tracker/utils/getStatusColor.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:math';

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
  final bool forceShowImage; // <--- Add this line

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
    this.forceShowImage = false, // <--- Add this line
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard>
    with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  late final Set<Marker> markers;
  final FirebaseService _firebaseService = FirebaseService();
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  String? checkinToken;
  double _progress = 0.0;
  Future<int>? _signedUpUsersCountFuture; // <-- Add this

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
    _signedUpUsersCountFuture =
        _getSignedUpUsersCount(widget.eventId); // <-- Cache future
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

    // Calculate progress
    final total = widget.endTime.difference(widget.startTime).inSeconds;
    final elapsed = now.difference(widget.startTime).inSeconds;
    setState(() {
      _progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
    });

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

          // Update progress here
          final total = widget.endTime.difference(widget.startTime).inSeconds;
          final elapsed = now.difference(widget.startTime).inSeconds;
          _progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;

          if (_timeRemaining.isNegative) {
            _timeRemaining = Duration.zero;
            _timer?.cancel();
          }
        });
      }
    });
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      _signedUpUsersCountFuture =
          _getSignedUpUsersCount(widget.eventId); // <-- Update if event changes
    }
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Stack(
                children: [
                  // Card content
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white60, Colors.white10],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color.fromARGB(80, 124, 124, 124),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: Offset(0, 4),
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
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Vspace(4),
                              Text(
                                widget.description,
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[700]),
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.fade,
                              ),
                              Vspace(8),
                              // --- Swap image and map based on currentStatus ---
                              Builder(
                                builder: (context) {
                                  // --- Always show image if forceShowImage is true ---
                                  if (widget.forceShowImage) {
                                    return (widget.image != null &&
                                            widget.image!.isNotEmpty)
                                        ? SizedBox(
                                            height: 170,
                                            width: double.infinity,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                widget.image!,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            height: 170,
                                            width: double.infinity,
                                            color: Colors.grey[300],
                                            child: Icon(
                                              Icons.image_not_supported,
                                              size: 40,
                                              color: Colors.grey[600],
                                            ),
                                          );
                                  }
                                  final isSoonOrParticipatedOrAbsent =
                                      currentStatus == "soon" ||
                                          currentStatus == "participated" ||
                                          currentStatus == "absent";
                                  if (isSoonOrParticipatedOrAbsent) {
                                    // Show image in place of map, faded out from the right side
                                    return (widget.image != null &&
                                            widget.image!.isNotEmpty)
                                        ? SizedBox(
                                            height: 170,
                                            width: double.infinity,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: ShaderMask(
                                                shaderCallback: (Rect bounds) {
                                                  return LinearGradient(
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                    colors: [
                                                      Colors.white,
                                                      Colors.transparent
                                                    ],
                                                    stops: [0.7, 1.0],
                                                  ).createShader(bounds);
                                                },
                                                blendMode: BlendMode.dstIn,
                                                child: Image.network(
                                                  widget.image!,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            height: 170,
                                            width: double.infinity,
                                            color: Colors.grey[300],
                                            child: Icon(
                                              Icons.image_not_supported,
                                              size: 40,
                                              color: Colors.grey[600],
                                            ),
                                          );
                                  } else {
                                    // Show map as usual
                                    return Container(
                                      height: 170,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: GoogleMap(
                                        onMapCreated:
                                            (GoogleMapController controller) {
                                          mapController = controller;
                                        },
                                        initialCameraPosition: CameraPosition(
                                          target: LatLng(widget.latitude,
                                              widget.longitude),
                                          zoom: 15.0,
                                        ),
                                        markers: markers,
                                        mapType: MapType.normal,
                                        zoomControlsEnabled: true,
                                        mapToolbarEnabled: false,
                                        myLocationButtonEnabled: true,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          flex: 3,
                          child: Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Timer/reward column
                                Column(
                                  children: [
                                    if (widget.status == 'active' &&
                                        _timeRemaining > Duration.zero)
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: SizedBox(
                                          height: 90,
                                          width: 90,
                                          child: UTimeMeter(
                                            progress: _progress,
                                            timeLabel: _formatDurationShort(
                                                _timeRemaining),
                                            ended: _progress >= 1.0 ||
                                                _timeRemaining == Duration.zero,
                                          ),
                                        ),
                                      )
                                    else
                                      Column(
                                        children: [
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: "Starts: ",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                TextSpan(
                                                  text: DateFormat(
                                                          'd MMM \'\nat\' hh:mm a')
                                                      .format(widget.startTime),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Vspace(8),
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: "Ends: ",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                TextSpan(
                                                  text: DateFormat(
                                                          'd MMM \'\nat\' hh:mm a')
                                                      .format(widget.endTime),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    Divider(
                                      indent: 10,
                                      endIndent: 10,
                                      color: const Color.fromARGB(
                                          80, 124, 124, 124),
                                      thickness: 2,
                                    ),
                                    Text(
                                        "Reward: ${widget.rewardPoints.ceil()}⭐"),
                                    Vspace(8),
                                  ],
                                ),
                                // Button is now outside the timer/reward column but still in the right area
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20.0),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFF2196F3), // blue
                                            Colors.white10
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(16.0),
                                        border: Border.all(
                                          color: const Color.fromARGB(
                                              80, 124, 124, 124),
                                          width: 2,
                                        ),
                                      ),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 32, // Smaller height
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16.0),
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 15, // Smaller font
                                              fontWeight: FontWeight.bold,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                          onPressed: () {
                                            if (currentStatus == 'ended' ||
                                                currentStatus == 'overdue') {
                                              _showEventCheckInDialog(
                                                  context, widget.eventId);
                                            } else {
                                              _showEventSignUpDialog(context);
                                            }
                                          },
                                          child: Text(
                                            getButtonText(currentStatus),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge pinned to upper right
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      constraints: BoxConstraints(
                        minWidth: 120,
                        maxWidth: 120, // Adjust as needed
                      ),
                      decoration: BoxDecoration(
                        gradient: getStatusColor(currentStatus),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(12),
                        ),
                        border: Border(
                          right: BorderSide(
                            color: const Color.fromARGB(
                                80, 124, 124, 124), // Match card border color
                            width: 2, // Match card border width
                          ),
                          top: BorderSide(
                            color: const Color.fromARGB(
                                80, 124, 124, 124), // Match card border color
                            width: 2, // Match card border width
                          ),
                          left: BorderSide(
                            color: const Color.fromARGB(
                                80, 124, 124, 124), // Match card border color
                            width: 2, // Match card border width
                          ),
                          bottom: BorderSide(
                            color: const Color.fromARGB(
                                80, 124, 124, 124), // Match card border color
                            width: 2, // Match card border width
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          currentStatus,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
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
      barrierColor: Colors.transparent, // No barrier color
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Stack(
            children: [
              // --- Add ConstrainedBox for min/max size ---
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 320,
                  maxWidth: 420,
                  minHeight: 320,
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 15,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white60, Colors.white10],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color.fromARGB(80, 124, 124, 124),
                            width: 2,
                          ),
                        ),
                        padding: EdgeInsets.all(16),
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                        ),
                        child: SingleChildScrollView(
                          child: StreamBuilder<String>(
                            stream: _firebaseService
                                .getEventStatusStream(widget.eventId),
                            initialData: widget.status,
                            builder: (context, snapshot) {
                              final currentStatus =
                                  snapshot.data ?? widget.status;
                              final isSoonOrParticipatedOrAbsent =
                                  currentStatus == "soon" ||
                                      currentStatus == "participated" ||
                                      currentStatus == "absent";
                              // Only one of image/map should show at the top, depending on status
                              Widget topWidget;
                              if (isSoonOrParticipatedOrAbsent) {
                                // Show map at the top
                                topWidget = SizedBox(
                                  height: 200,
                                  width: double.infinity,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: GoogleMap(
                                      onMapCreated:
                                          (GoogleMapController controller) {
                                        mapController = controller;
                                      },
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(
                                            widget.latitude, widget.longitude),
                                        zoom: 15.0,
                                      ),
                                      markers: markers,
                                      mapType: MapType.normal,
                                      zoomControlsEnabled: true,
                                      mapToolbarEnabled: false,
                                      myLocationButtonEnabled: true,
                                    ),
                                  ),
                                );
                              } else {
                                // Show image at the top
                                topWidget = (widget.image != null &&
                                        widget.image!.isNotEmpty)
                                    ? SizedBox(
                                        height: 200,
                                        width: double.infinity,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                            widget.image!,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 200,
                                        width: double.infinity,
                                        color: Colors.grey[300],
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 40,
                                          color: Colors.grey[600],
                                        ),
                                      );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  topWidget,
                                  Vspace(16),
                                  // Event Title
                                  Text(
                                    widget.name.isNotEmpty
                                        ? widget.name
                                        : "Event Name",
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
                                  Vspace(8),
                                  Divider(
                                    color: const Color.fromARGB(80, 0, 0, 0),
                                    thickness: 2,
                                  ),
                                  Vspace(8),
                                  Text(
                                    'Location: (${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)})',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  Vspace(4),
                                  // Display the number of signed-up users
                                  FutureBuilder<int>(
                                    future: _signedUpUsersCountFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return Text(
                                          'Loading signed-up users...',
                                          style: TextStyle(
                                              fontSize: 16, color: Colors.grey),
                                        );
                                      } else if (snapshot.hasError) {
                                        return Text(
                                          'Error loading signed-up users',
                                          style: TextStyle(
                                              fontSize: 16, color: Colors.red),
                                        );
                                      } else {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${snapshot.data} users have already signed up!',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            Vspace(4),
                                            Text(
                                              'Max participants: ${widget.maxParticipants}',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black),
                                            ),
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                  Vspace(20),
                                  Text(
                                    'Created on: ${formatDate(widget.createdDate)}',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.black),
                                  ),
                                  Vspace(4),
                                  // Sign-Up Button
                                  Center(
                                    child: widget.status != 'awaiting' &&
                                            widget.status != 'active' &&
                                            widget.status != 'absent' &&
                                            widget.status != 'participated'
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(20.0),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                  sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Color(0xFF2196F3), // blue
                                                      Colors.white10
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16.0),
                                                  border: Border.all(
                                                    color: const Color.fromARGB(
                                                        80, 124, 124, 124),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: SizedBox(
                                                  width: double.infinity,
                                                  height: 32,
                                                  child: TextButton(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.black,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16.0),
                                                      ),
                                                      textStyle:
                                                          const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                    ),
                                                    onPressed: () async {
                                                      try {
                                                        await firebaseService
                                                            .signUpForEvent(
                                                                widget.eventId);
                                                        Navigator.of(context)
                                                            .pop(); // Close dialog on success
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                                SnackBar(
                                                          content: Text(
                                                              "Signed up successfully!"),
                                                          backgroundColor:
                                                              Colors.green,
                                                        ));
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                                SnackBar(
                                                          content: Text(
                                                              "Error: ${e.toString()}"),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ));
                                                      }
                                                    },
                                                    child: Text(
                                                      "Sign Up",
                                                      style: TextStyle(
                                                          fontSize: 16,
                                                          color: Colors.black,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : SizedBox.shrink(),
                                  )
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // --- Floating Share Button ---
              Positioned(
                bottom: 24,
                right: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Shadow underneath the share button
                    Positioned(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 16,
                              spreadRadius: 2,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topCenter,
                              colors: [Colors.blue, Colors.white10],
                            ),
                            border: Border.all(
                              color: const Color.fromARGB(80, 124, 124, 124),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(50, 0, 0, 0),
                                blurRadius: 15,
                                spreadRadius: 1,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          width: 48,
                          height: 48,
                          child: IconButton(
                            icon: Icon(Icons.share,
                                color: Colors.black, size: 24),
                            tooltip: 'Share Event',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text("Coming Soon!"),
                                  content: Text(
                                      "The sharing option is in development and coming soon!"),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text("Can't wait!"),
                                    ),
                                  ],
                                ),
                              );
                              // Implement your share logic here, e.g. using Share.share from 'share_plus'
                              // Use share_plus to share the event details
                              // Make sure to import 'package:share_plus/share_plus.dart';
                              // and add share_plus to your pubspec.yaml dependencies.
                              // Remove the comment below to enable sharing:
                              // Share.share(shareText, subject: widget.name);
                              // Make a way to share the whole event card
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    bool isProcessing = false; // Add a flag to prevent multiple triggers

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text("Scan QR Code"),
        ),
        body: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) async {
                if (isProcessing) return; // Prevent multiple triggers
                isProcessing = true;

                final List<Barcode> barcodes = capture.barcodes;

                if (barcodes.isNotEmpty) {
                  final String? scannedCode = barcodes.first.rawValue;

                  if (scannedCode == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              "Failed to scan QR code. Please try again.")),
                    );
                    isProcessing = false; // Reset the flag
                    return;
                  }

                  try {
                    // Validate the scanned QR code value against the check-in token
                    if (scannedCode == checkinToken) {
                      // Handle successful match
                      Navigator.of(context)
                          .pop(); // Close the QR scanner screen
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
                  } finally {
                    isProcessing = false; // Reset the flag
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text("No QR code detected. Please try again.")),
                  );
                  isProcessing = false; // Reset the flag
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
    ));
  }

  Future<void> _handleSuccessfulMatch(
      BuildContext context, String eventId) async {
    try {
      await _firebaseService.checkInForEvent(eventId);

      // Check if widget is still mounted before accessing context
      if (!mounted) return;

      // Show success dialog on the event page
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
                "Successfully checked in!",
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

  String _formatDurationShort(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else if (minutes > 0) {
      return "${minutes}m";
    } else {
      return "${seconds}s";
    }
  }
}

// --- UTimeMeter Widget and Painter ---

class UTimeMeter extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String timeLabel;
  final bool ended;

  const UTimeMeter({
    Key? key,
    required this.progress,
    required this.timeLabel,
    this.ended = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: UTimeMeterPainter(progress: progress, ended: ended),
      child: Center(
        child: ended
            ? Text(
                "Ended",
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 4, color: Colors.redAccent)],
                ),
              )
            : Text(
                timeLabel,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 2, color: Colors.white)],
                ),
              ),
      ),
    );
  }
}

class UTimeMeterPainter extends CustomPainter {
  final double progress;
  final bool ended;

  UTimeMeterPainter({required this.progress, this.ended = false});

  Color _getProgressColor(double t) {
    // 0.0 -> green, 0.5 -> yellow, 1.0 -> red
    if (t < 0.5) {
      // Green to Yellow
      double p = t / 0.5;
      return Color.lerp(Colors.green, Colors.yellow, p)!;
    } else {
      // Yellow to Red
      double p = (t - 0.5) / 0.5;
      return Color.lerp(Colors.yellow, Colors.red, p)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 14;
    final double radius = (size.width / 2) - strokeWidth / 2;
    final Offset center = Offset(size.width / 2, size.height / 2 + 8);

    // Draw background U-track
    final Paint trackPaint = Paint()
      ..color = Colors.grey.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);

    // U-shape: from left-bottom, up, over the top, down to right-bottom (inverted U)
    final double startAngle = pi; // 180 deg (left base)
    final double sweepAngle = pi; // 180 deg (to right base)

    canvas.drawArc(arcRect, startAngle, sweepAngle, false, trackPaint);

    // Draw shadow/glow for progress
    if (!ended && progress > 0) {
      final Paint shadowPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.black.withOpacity(0.12), Colors.transparent],
        ).createShader(arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(
          arcRect, startAngle, sweepAngle * progress, false, shadowPaint);
    }

    // Draw progress U-bar with color interpolated along progress
    if (progress > 0) {
      final int steps = 60;
      for (int i = 0; i < steps; i++) {
        double t0 = i / steps;
        double t1 = (i + 1) / steps;
        if (t1 > progress) t1 = progress;
        if (t0 >= t1) break;
        final Paint segPaint = Paint()
          ..color = ended ? Colors.red : _getProgressColor((t0 + t1) / 2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;
        double a0 = startAngle + sweepAngle * t0;
        double a1 = startAngle + sweepAngle * t1;
        canvas.drawArc(arcRect, a0, a1 - a0, false, segPaint);
      }
      // Draw rounded caps at both ends
      final double capRadius = strokeWidth / 2;
      final Paint capPaint = Paint()
        ..color = ended ? Colors.red : _getProgressColor(0)
        ..style = PaintingStyle.fill;
      // Start cap
      final Offset startCap = Offset(
        center.dx + radius * cos(startAngle),
        center.dy + radius * sin(startAngle),
      );
      canvas.drawCircle(startCap, capRadius, capPaint);
      // End cap (only if progress > 0)
      if (progress > 0) {
        final Paint endCapPaint = Paint()
          ..color = ended ? Colors.red : _getProgressColor(progress)
          ..style = PaintingStyle.fill;
        final double endAngle = startAngle + sweepAngle * progress;
        final Offset endCap = Offset(
          center.dx + radius * cos(endAngle),
          center.dy + radius * sin(endAngle),
        );
        canvas.drawCircle(endCap, capRadius, endCapPaint);
      }
    }

    // If ended, draw blinking edge or highlight
    if (ended) {
      final Paint edgePaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant UTimeMeterPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.ended != ended;
  }
}
