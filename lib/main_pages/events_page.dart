import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_impact_tracker/services/firebase_service.dart';
import 'package:community_impact_tracker/utils/AddSpace.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart'; // Add this import for location services
import '../widgets/event_card.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late FirebaseService _firebaseService;
  final ScrollController _scrollController = ScrollController();
  final int _eventsPerPage = 10; // Number of events to load per page

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> filteredEvents = [];
  List<Map<String, dynamic>> signedUpEvents = [];
  Map<String, StreamSubscription<String>> statusSubscriptions = {};
  StreamSubscription? _authSubscription;

  String selectedFilter = 'ongoing';
  String selectedSort = 'most_recent';
  bool isLoading = true;
  bool isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreEvents = true;
  Position? userLocation; // Store the user's location

  // Add this line to make showSignedUpSection a class-level variable
  bool showSignedUpSection = false;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();

    // Fetch user's location
    _fetchUserLocation();

    // Set up a single auth state listener
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        print("User logged in: ${user.uid}");
        // Complete refresh of events
        _fullRefresh();
      } else {
        print("User logged out");
        // Clear events when user is logged out
        _clearEvents();
      }
    });

    // Initial events load
    _initializeEvents();
    _scrollController.addListener(_onScroll);

    // Initialize timers
    _firebaseService.initializeTimers();
  }

  // Fetch the user's current location
  Future<void> _fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("Location permissions are denied.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("Location permissions are permanently denied.");
        return;
      }

      userLocation = await Geolocator.getCurrentPosition();
      print(
          "User location fetched: ${userLocation?.latitude}, ${userLocation?.longitude}");
    } catch (e) {
      print("Error fetching user location: $e");
    }
  }

  // Clear all events and subscriptions
  void _clearEvents() {
    setState(() {
      // Cancel existing subscriptions
      for (var subscription in statusSubscriptions.values) {
        subscription.cancel();
      }
      statusSubscriptions.clear();

      // Clear events lists
      events.clear();
      filteredEvents.clear();
      signedUpEvents.clear(); // Clear signed up events

      // Reset pagination
      _lastDocument = null;
      _hasMoreEvents = true;
    });
  }

  // Full refresh after login
  Future<void> _fullRefresh() async {
    _clearEvents();

    // Recreate Firebase service to ensure fresh connection
    _firebaseService = FirebaseService();

    // Fetch fresh data
    await fetchEventsFromFirebase();
  }

  // New method to handle async initialization
  Future<void> _initializeEvents() async {
    if (FirebaseAuth.instance.currentUser != null) {
      await fetchEventsFromFirebase();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    _authSubscription?.cancel();
    for (var subscription in statusSubscriptions.values) {
      subscription.cancel();
    }
    statusSubscriptions.clear(); // Add this to clear the map
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshEvents() async {
    // Reset pagination
    _lastDocument = null;
    _hasMoreEvents = true;
    events.clear();
    filteredEvents.clear();
    signedUpEvents.clear(); // Clear signed up events

    // Cancel existing subscriptions
    for (var subscription in statusSubscriptions.values) {
      subscription.cancel();
    }
    statusSubscriptions.clear();

    // Fetch events again
    await fetchEventsFromFirebase();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // Reached the bottom of the list
      if (_hasMoreEvents && !isLoadingMore) {
        fetchMoreEvents();
      }
    }
  }

  Future<void> fetchEventsFromFirebase() async {
    try {
      // Check if user is logged in
      if (FirebaseAuth.instance.currentUser == null) {
        print("Cannot fetch events: User not logged in");
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      String userId = FirebaseAuth.instance.currentUser!.uid;

      print("Fetching events for user: $userId");

      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      // Fetch user-specific events
      QuerySnapshot userEventsSnapshot = await _firestore
          .collection('user_events')
          .doc(userId)
          .collection('events')
          .get();

      Set<String> userEventIds =
          userEventsSnapshot.docs.map((doc) => doc.id).toSet();

      // Fetch all events from the global collection
      QuerySnapshot allEventsSnapshot = await _firestore
          .collection('events')
          .orderBy('startTime')
          .limit(50) // Higher limit to ensure we get enough events
          .get();

      List<Map<String, dynamic>> fetchedEvents = [];

      for (var doc in allEventsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        GeoPoint location = data['location'] as GeoPoint;
        String eventId = doc.id;
        String status = data['status'] ?? 'pending';

        Map<String, dynamic> eventData = {
          'eventId': eventId,
          'name': data['name'] ?? 'Unnamed Event',
          'description': data['description'] ?? 'No description available',
          'image': data['image'],
          'startTime': (data['startTime'] as Timestamp).toDate(),
          'endTime': (data['endTime'] as Timestamp).toDate(),
          'createdDate': (data['createdDate'] as Timestamp).toDate(),
          'rewardPoints': data['rewardPoints'] ?? 0,
          'status': status,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'isSignedUp': userEventIds.contains(eventId), // Track signup status
          'maxParticipants': data['maxParticipants'] ?? 0, // Handle null safely
          'currentParticipants': data['currentParticipants'] ?? 0,
        };

        fetchedEvents.add(eventData);

        // Set up status subscriptions (same as before)
        if (statusSubscriptions.containsKey(eventId)) {
          statusSubscriptions[eventId]?.cancel();
        }

        statusSubscriptions[eventId] =
            _firebaseService.getEventStatusStream(eventId).listen(
          (status) {
            if (mounted) {
              setState(() {
                for (int i = 0; i < events.length; i++) {
                  if (events[i]['eventId'] == eventId) {
                    events[i]['status'] = status;
                    // Update isSignedUp based on status
                    events[i]['isSignedUp'] = userEventIds.contains(eventId);
                    break;
                  }
                }
                _applyFilter();
              });
            }
          },
          onError: (error) {
            print("Error in event status stream for $eventId: $error");
            if (mounted) {
              for (int i = 0; i < events.length; i++) {
                if (events[i]['eventId'] == eventId) {
                  setState(() {
                    events[i]['status'] = 'error';
                    _applyFilter();
                  });
                  break;
                }
              }
            }
          },
        );
      }

      if (mounted) {
        setState(() {
          events = fetchedEvents;
          isLoading = false;
          // Don't need pagination for this initial load
          _hasMoreEvents = allEventsSnapshot.docs.length >= 50;
          if (_hasMoreEvents && allEventsSnapshot.docs.isNotEmpty) {
            _lastDocument = allEventsSnapshot.docs.last;
          }
          _applyFilter();
        });
      }
    } catch (e) {
      print("Error fetching events: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load events. Please try again.')),
        );
      }
    }
  }

  Future<void> fetchMoreEvents() async {
    if (_hasMoreEvents) {
      setState(() {
        isLoadingMore = true;
      });

      try {
        await fetchEventsFromFirebase();
      } finally {
        setState(() {
          isLoadingMore = false;
        });
      }
    }
  }

  void _applySorting(List<Map<String, dynamic>> eventsList) {
    if (selectedSort == 'most_recent') {
      eventsList.sort((a, b) => b['createdDate'].compareTo(a['createdDate']));
    } else if (selectedSort == 'most_points') {
      eventsList.sort((a, b) => b['rewardPoints'].compareTo(a['rewardPoints']));
    } else if (selectedSort == 'near_me' && userLocation != null) {
      eventsList.sort((a, b) {
        double distanceA = Geolocator.distanceBetween(
          userLocation!.latitude,
          userLocation!.longitude,
          a['latitude'],
          a['longitude'],
        );
        double distanceB = Geolocator.distanceBetween(
          userLocation!.latitude,
          userLocation!.longitude,
          b['latitude'],
          b['longitude'],
        );
        return distanceA.compareTo(distanceB);
      });
    } else if (selectedSort == 'starting_soon') {
      eventsList.sort((a, b) =>
          a['startTime'].compareTo(b['startTime'])); // Sort in ascending order
    } else if (selectedSort == 'duration') {
      eventsList.sort((a, b) {
        Duration durationA = a['endTime'].difference(a['startTime']);
        Duration durationB = b['endTime'].difference(a['startTime']);
        return durationB.compareTo(durationA); // Sort by longest duration
      });
    }
  }

  void _applyFilter() {
    DateTime now = DateTime.now();
    int daysToMonday = (now.weekday == 7) ? 6 : now.weekday - 1;
    DateTime startOfWeek = now.subtract(Duration(days: daysToMonday)).copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    DateTime endOfWeek =
        startOfWeek.add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    DateTime startOfNextWeek = startOfWeek.add(Duration(days: 7));

    for (var event in events) {
      DateTime startTime = event['startTime'];
      if (startTime.isBefore(now) && event['status'] == 'upcoming') {
        event['status'] = 'ongoing';
      }
    }

    List<Map<String, dynamic>> tempFiltered = [];

    if (selectedFilter == 'ongoing') {
      tempFiltered = events.where((event) {
        DateTime startTime = event['startTime'];
        DateTime endTime = event['endTime'];
        String status = event['status'];

        bool isActionable = (status == 'soon' ||
            status == 'active' ||
            status == 'awaiting' ||
            status == 'ended' ||
            status == 'overdue' ||
            status == 'pending');
        bool isWithinThisWeek = (startTime.isAfter(startOfWeek) ||
                startTime.isAtSameMomentAs(startOfWeek)) &&
            (endTime.isBefore(endOfWeek) ||
                endTime.isAtSameMomentAs(endOfWeek));

        return isActionable && isWithinThisWeek;
      }).toList();
    } else if (selectedFilter == 'recently ended') {
      tempFiltered = events.where((event) {
        DateTime endTime = event['endTime'];
        String status = event['status'];

        bool isEndedAndStatusValid =
            (endTime.isBefore(now) || endTime.isAtSameMomentAs(now)) &&
                (status == 'participated' || status == 'absent');

        return isEndedAndStatusValid;
      }).toList();
    } else if (selectedFilter == 'upcoming') {
      tempFiltered = events.where((event) {
        DateTime startTime = event['startTime'];
        return startTime.isAfter(startOfNextWeek);
      }).toList();
    } else {
      tempFiltered = List.from(events);
    }

    // Split into "Your Events" and "Other Events" for the ongoing filter
    if (selectedFilter == 'ongoing' || selectedFilter == 'upcoming') {
      signedUpEvents =
          tempFiltered.where((event) => event['isSignedUp'] == true).toList();
      filteredEvents =
          tempFiltered.where((event) => event['isSignedUp'] != true).toList();

      // Update showSignedUpSection dynamically
      showSignedUpSection = signedUpEvents.isNotEmpty;
    } else {
      // For other filters, don't split
      signedUpEvents = [];
      filteredEvents = tempFiltered;
      showSignedUpSection = false;
    }

    // Apply sorting to both lists
    _applySorting(filteredEvents);
    _applySorting(signedUpEvents);

    setState(() {});
  }

  void handleSignIn(int index, bool isFromSignedUpSection) async {
    List<Map<String, dynamic>> sourceList =
        isFromSignedUpSection ? signedUpEvents : filteredEvents;

    String eventId = sourceList[index]['eventId'];
    String userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      final existingSignUp = await _firestore
          .collection('user_events')
          .doc(userId)
          .collection('events')
          .doc(eventId)
          .get();

      if (existingSignUp.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are already signed up for this event.')),
        );
        return;
      }

      await _firestore.runTransaction((transaction) async {
        DocumentReference eventRef =
            _firestore.collection('events').doc(eventId);
        DocumentSnapshot freshEventDoc = await transaction.get(eventRef);

        if (!freshEventDoc.exists) {
          throw Exception('Event not found');
        }

        Map<String, dynamic> eventData =
            freshEventDoc.data() as Map<String, dynamic>;
        int freshCurrentParticipants = eventData['currentParticipants'] ?? 0;
        int maxParticipants = eventData['maxParticipants'] ?? 0;

        if (freshCurrentParticipants >= maxParticipants) {
          throw Exception('Event is now full');
        }

        transaction.update(
            eventRef, {'currentParticipants': freshCurrentParticipants + 1});

        transaction.set(
            _firestore
                .collection('user_events')
                .doc(userId)
                .collection('events')
                .doc(eventId),
            {'signUpTime': FieldValue.serverTimestamp()});
      });

      final updatedEventDoc =
          await _firestore.collection('events').doc(eventId).get();
      int updatedCurrentParticipants =
          updatedEventDoc.data()?['currentParticipants'] ?? 0;

      print(
          'Event $eventId - Current Participants: $updatedCurrentParticipants');

      setState(() {
        for (var event in events) {
          if (event['eventId'] == eventId) {
            event['currentParticipants'] = updatedCurrentParticipants;
            break;
          }
        }
        _applyFilter();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully signed up for the event!')),
      );
    } catch (e) {
      print('Error signing up for event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign up. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> debugVerifyEventSignUps(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      print('Event Details:');
      print(
          'Current Participants: ${eventDoc.data()?['currentParticipants'] ?? 0}');
      print('Max Participants: ${eventDoc.data()?['maxParticipants'] ?? 0}');

      final userEventsSnapshot =
          await _firestore.collection('user_events').get();
      print('Total user event collections: ${userEventsSnapshot.docs.length}');

      int signedUpCount = 0;
      for (var userDoc in userEventsSnapshot.docs) {
        final eventSignUpDoc =
            await userDoc.reference.collection('events').doc(eventId).get();

        if (eventSignUpDoc.exists) {
          signedUpCount++;
          print('User signed up: ${userDoc.id}');
        }
      }

      print('Total users signed up for event $eventId: $signedUpCount');
    } catch (e) {
      print('Error verifying event sign-ups: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('EEEE, d MMMM').format(now);
    String formattedTime = DateFormat('hh:mm a').format(now);

    // Use the class-level showSignedUpSection variable
    bool showSignedUpSection = this.showSignedUpSection;

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
      body: RefreshIndicator(
        onRefresh: _refreshEvents,
        child: Column(
          children: [
            // Top bar with date, time, and icons
            PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Calendar icon
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(
                          255, 211, 211, 211), // Light grey background
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.calendar_month_rounded),
                      onPressed: () {},
                    ),
                  ),
                  // Date and time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        formattedTime,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  // Notifications icon
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(
                          255, 211, 211, 211), // Light grey background
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.notifications),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            // Filter title (e.g., "This Week", "Past Week", "Next Week")
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, bottom: 8),
                child: Text(
                  selectedFilter == 'ongoing'
                      ? 'This Week'
                      : selectedFilter == 'recently ended'
                          ? 'Past Week'
                          : 'Next Week',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Filter chips (e.g., "ongoing", "recently ended", "upcoming")
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: ['ongoing', 'recently ended', 'upcoming']
                          .map((filter) {
                        return ChoiceChip(
                          label: Text(
                            filter,
                            style: TextStyle(fontSize: 12),
                          ),
                          backgroundColor:
                              const Color.fromARGB(177, 177, 177, 177),
                          selected: selectedFilter == filter,
                          showCheckmark: false,
                          onSelected: (bool selected) {
                            setState(() {
                              selectedFilter = filter;
                              _applyFilter();
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding:
                              EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          shadowColor: Colors.black.withOpacity(0.2),
                          elevation: 4,
                        );
                      }).toList(),
                    ),
                    Spacer(),
                    // Sorting button
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            barrierColor: Colors.black.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            context: context,
                            builder: (context) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildListTile(
                                      icon: Icons.more_time_rounded,
                                      title: 'Most Recent',
                                      isSelected: selectedSort == 'most_recent',
                                      onTap: () {
                                        setState(() {
                                          selectedSort = 'most_recent';
                                          _applySorting(filteredEvents);
                                          _applySorting(signedUpEvents);
                                        });
                                        Navigator.pop(context);
                                      },
                                      isTop: true,
                                    ),
                                    _buildListTile(
                                      icon: Icons.star,
                                      title: 'Most Points',
                                      isSelected: selectedSort == 'most_points',
                                      onTap: () {
                                        setState(() {
                                          selectedSort = 'most_points';
                                          _applySorting(filteredEvents);
                                          _applySorting(signedUpEvents);
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                    _buildListTile(
                                      icon: Icons.my_location_rounded,
                                      title: 'Near Me',
                                      isSelected: selectedSort == 'near_me',
                                      onTap: () {
                                        setState(() {
                                          selectedSort = 'near_me';
                                          _applySorting(filteredEvents);
                                          _applySorting(signedUpEvents);
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                    _buildListTile(
                                      icon: Icons.timelapse_rounded,
                                      title: 'Starting Soon',
                                      isSelected:
                                          selectedSort == 'starting_soon',
                                      onTap: () {
                                        setState(() {
                                          selectedSort = 'starting_soon';
                                          _applySorting(filteredEvents);
                                          _applySorting(signedUpEvents);
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                    _buildListTile(
                                      icon: Icons.hourglass_top_rounded,
                                      title: 'Duration',
                                      isSelected: selectedSort == 'duration',
                                      onTap: () {
                                        setState(() {
                                          selectedSort = 'duration';
                                          _applySorting(filteredEvents);
                                          _applySorting(signedUpEvents);
                                        });
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.tune,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Vspace(6),

            // Events list
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: _scrollController,
                      children: [
                        // Your Events Section
                        if (showSignedUpSection) ...[
                          Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              tilePadding:
                                  EdgeInsets.symmetric(horizontal: 16.0),
                              childrenPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  Text(
                                    'Your Events',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    '${signedUpEvents.length} events',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              children: signedUpEvents.map((event) {
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
                                  currentParticipants:
                                      event['currentParticipants'],
                                  status: event['status'],
                                  onSignIn: () => handleSignIn(
                                      signedUpEvents.indexOf(event), true),
                                );
                              }).toList(),
                            ),
                          ),
                          // Divider between sections
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16.0),
                            child: Divider(
                              thickness: 1,
                              color: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                        ],

                        // Other Events Section
                        Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            tilePadding: EdgeInsets.symmetric(horizontal: 16.0),
                            childrenPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Text(
                                  showSignedUpSection
                                      ? 'Other Events'
                                      : 'Events',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  '${filteredEvents.length} events',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            children: filteredEvents.isEmpty
                                ? [
                                    Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(
                                          child: Text(
                                              'No events in this category')),
                                    )
                                  ]
                                : [
                                    ...filteredEvents.map((event) {
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
                                        maxParticipants:
                                            event['maxParticipants'],
                                        currentParticipants:
                                            event['currentParticipants'],
                                        status: event['status'],
                                        onSignIn: () => handleSignIn(
                                            filteredEvents.indexOf(event),
                                            false),
                                      );
                                    }),
                                    if (isLoadingMore)
                                      Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Center(
                                            child: CircularProgressIndicator()),
                                      ),
                                  ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    bool isTop = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[100] : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: isTop ? Radius.circular(20) : Radius.zero,
          topRight: isTop ? Radius.circular(20) : Radius.zero,
        ),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}
