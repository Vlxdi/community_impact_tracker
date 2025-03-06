import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_impact_tracker/services/firebase_service.dart';
import 'package:community_impact_tracker/utils/AddSpace.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
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
  late FirebaseService _firebaseService;
  final ScrollController _scrollController = ScrollController();
  final int _eventsPerPage = 10; // Number of events to load per page

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> filteredEvents = [];
  Map<String, StreamSubscription<String>> statusSubscriptions = {};
  StreamSubscription? _authSubscription;

  String selectedFilter = 'ongoing';
  bool isLoading = true;
  bool isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreEvents = true;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();

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

      print(
          "Fetching events for user: ${FirebaseAuth.instance.currentUser?.uid}");

      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      DateTime now = DateTime.now();
      int daysToMonday = (now.weekday == 7) ? 6 : now.weekday - 1;
      DateTime startOfWeek = now
          .subtract(Duration(days: daysToMonday))
          .copyWith(
              hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      DateTime endOfWeek = startOfWeek
          .add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      DateTime startOfNextWeek = startOfWeek.add(Duration(days: 7));

      // First, determine if we need to do a filter-specific query or load all events
      if (events.isEmpty) {
        // If we're loading the first page and selected filter is "upcoming" or "ongoing"
        // And we expect these to have few events, load all events up to a reasonable limit
        if (selectedFilter == 'upcoming' || selectedFilter == 'ongoing') {
          // Load a larger batch of events to ensure we capture all categories
          QuerySnapshot allEventsSnapshot = await _firestore
              .collection('events')
              .orderBy('startTime')
              .limit(50) // Higher limit to ensure we get enough events
              .get();

          print(
              "Initial load returned ${allEventsSnapshot.docs.length} total events");

          List<Map<String, dynamic>> fetchedEvents = [];

          for (var doc in allEventsSnapshot.docs) {
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

          return; // Exit early since we handled everything
        }
      }

      // Regular pagination for "recently ended" filter or subsequent loads
      Query query = _firestore
          .collection('events')
          .orderBy('startTime')
          .limit(_eventsPerPage);

      // If we have a last document, start after it for pagination
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot querySnapshot = await query.get();
      print("Standard query returned ${querySnapshot.docs.length} events");

      // Check if we've reached the end of available events
      if (querySnapshot.docs.length < _eventsPerPage) {
        _hasMoreEvents = false;
      }

      // Store the last document for next pagination
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
      }

      List<Map<String, dynamic>> fetchedEvents = [];

      for (var doc in querySnapshot.docs) {
        // Same event processing as before
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

        // Status subscription setup (same as before)
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
          events.addAll(fetchedEvents);
          isLoading = false;
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

  void _applyFilter() {
    DateTime now = DateTime.now();

    // Calculate the start and end of the current week (Monday to Sunday)
    int daysToMonday = (now.weekday == 7) ? 6 : now.weekday - 1;
    DateTime startOfWeek = now.subtract(Duration(days: daysToMonday)).copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    DateTime endOfWeek =
        startOfWeek.add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    // Calculate the start of next week
    DateTime startOfNextWeek = startOfWeek.add(Duration(days: 7));

    // Update event statuses for the week transition
    events.forEach((event) {
      DateTime startTime = event['startTime'];
      if (startTime.isBefore(now) && event['status'] == 'upcoming') {
        event['status'] = 'ongoing';
      }
    });

    // Filter events based on selected filter
    if (selectedFilter == 'ongoing') {
      filteredEvents = events.where((event) {
        DateTime startTime = event['startTime'];
        DateTime endTime = event['endTime'];
        String status = event['status'];

        // Include events that:
        // 1. Have status "soon", "active", "awaiting", "ended" or "overdue"
        // 2. And occur within this week (Monday to Sunday)
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
      filteredEvents = events.where((event) {
        DateTime endTime = event['endTime'];
        String status = event['status'];

        // Only include events with status "participated" or "absent"
        // that have ended (end time is before now)
        bool isEndedAndStatusValid =
            (endTime.isBefore(now) || endTime.isAtSameMomentAs(now)) &&
                (status == 'participated' || status == 'absent');

        return isEndedAndStatusValid;
      }).toList();
    } else if (selectedFilter == 'upcoming') {
      filteredEvents = events.where((event) {
        DateTime startTime = event['startTime'];

        // Include events that:
        // 1. Start in the next week or later
        return startTime.isAfter(startOfNextWeek);
      }).toList();
    } else {
      // Default case - show all events
      filteredEvents = List.from(events);
    }
  }

  void handleSignIn(int index) async {
    String eventId = filteredEvents[index]['eventId'];

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
      body: RefreshIndicator(
        onRefresh: _refreshEvents,
        child: Column(
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

            // Dynamically changing the text based on selected filter
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

            // Chips
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
                      selected: selectedFilter == 'ongoing',
                      showCheckmark: false,
                      onSelected: (bool selected) {
                        setState(() {
                          selectedFilter = 'ongoing';
                          _applyFilter();
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
                          _applyFilter();
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
                          _applyFilter();
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
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : filteredEvents.isEmpty
                      ? Center(child: Text('No events in this category'))
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount:
                              filteredEvents.length + (isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < filteredEvents.length) {
                              final event = filteredEvents[index];
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
                            } else {
                              // Show loading indicator at the bottom when loading more
                              return Padding(
                                padding: EdgeInsets.all(8.0),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
