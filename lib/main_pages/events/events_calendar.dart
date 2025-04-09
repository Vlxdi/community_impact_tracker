import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventsCalendarPage extends StatefulWidget {
  const EventsCalendarPage({Key? key}) : super(key: key);

  @override
  _EventsCalendarPageState createState() => _EventsCalendarPageState();
}

class _EventsCalendarPageState extends State<EventsCalendarPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<DateTime, List<Map<String, dynamic>>> eventsByDate = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('events').get();
      Map<DateTime, List<Map<String, dynamic>>> tempEventsByDate = {};

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime startDate = (data['startTime'] as Timestamp).toDate();

        DateTime eventDate =
            DateTime(startDate.year, startDate.month, startDate.day);
        if (!tempEventsByDate.containsKey(eventDate)) {
          tempEventsByDate[eventDate] = [];
        }
        tempEventsByDate[eventDate]!.add({
          'name': data['name'] ?? 'Unnamed Event',
          'description': data['description'] ?? 'No description available',
          'startTime': startDate,
          'endTime': (data['endTime'] as Timestamp).toDate(),
          'eventId': data['eventId'],
          'createdDate': data['createdDate'],
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'rewardPoints': data['rewardPoints'],
          'maxParticipants': data['maxParticipants'],
          'status': data['status'],
          'currentParticipants': data['currentParticipants'],
        });
      }

      setState(() {
        eventsByDate = tempEventsByDate;
      });
    } catch (e) {
      print('Error fetching events: $e');
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return eventsByDate[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events Calendar'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text('Select a date to see events'))
                : ListView(
                    children: _getEventsForDay(_selectedDay!).map((event) {
                      return ListTile(
                        title: Text(event['name']),
                        subtitle: Text(
                          '${event['startTime']} - ${event['endTime']}',
                        ),
                        onTap: () {
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
                                    maxHeight:
                                        MediaQuery.of(context).size.height *
                                            0.8,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Event Title
                                        Text(
                                          event['name'],
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Event Description
                                        Text(
                                          event['description'],
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 16),

                                        // Event Details
                                        Text(
                                            'Event ID: ${event['eventId'] ?? 'Unknown ID'}'),
                                        Text(
                                            'Created Date: ${event['createdDate'] ?? DateTime.now()}'),
                                        Text(
                                            'Latitude: ${event['latitude'] ?? 0.0}'),
                                        Text(
                                            'Longitude: ${event['longitude'] ?? 0.0}'),
                                        Text(
                                            'Reward Points: ${event['rewardPoints'] ?? 0}'),
                                        Text(
                                            'Max Participants: ${event['maxParticipants'] ?? 0}'),
                                        Text(
                                            'Status: ${event['status'] ?? 'Unknown'}'),
                                        Text(
                                            'Current Participants: ${event['currentParticipants'] ?? 0}'),
                                        Text(
                                            'Start Time: ${event['startTime']}'),
                                        Text('End Time: ${event['endTime']}'),
                                        const SizedBox(height: 16),

                                        // Close Button
                                        Center(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 15, vertical: 10),
                                            ),
                                            child: const Text(
                                              'Close',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white),
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
                        },
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
