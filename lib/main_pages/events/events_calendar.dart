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

  final Map<int, Color> colorsets = {
    1: const Color.fromARGB(20, 2, 179, 8),
    2: const Color.fromARGB(40, 2, 179, 8),
    3: const Color.fromARGB(60, 2, 179, 8),
    4: const Color.fromARGB(80, 2, 179, 8),
    5: const Color.fromARGB(100, 2, 179, 8),
    6: const Color.fromARGB(120, 2, 179, 8),
    7: const Color.fromARGB(150, 2, 179, 8),
    8: const Color.fromARGB(180, 2, 179, 8),
    9: const Color.fromARGB(220, 2, 179, 8),
    10: const Color.fromARGB(255, 2, 179, 8),
  };

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

  Color _getDayColor(DateTime day) {
    int eventCount = _getEventsForDay(day).length;
    if (eventCount == 0) return Colors.transparent;
    return colorsets[eventCount.clamp(1, 10)]!;
  }

  Color _getHeatmapColor(DateTime day) {
    int eventCount = _getEventsForDay(day).length;
    if (eventCount == 0) return Colors.transparent; // No events, no color
    return colorsets[eventCount.clamp(1, 10)]!; // Clamp event count to 1-10
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
              defaultDecoration: BoxDecoration(
                color: Colors.transparent, // Default no color
                shape: BoxShape.rectangle,
              ),
              todayDecoration: BoxDecoration(
                color: _getHeatmapColor(_focusedDay), // Heatmap color for today
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              outsideDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.rectangle,
              ),
              disabledDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.rectangle,
              ),
              holidayDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.rectangle,
              ),
              weekendDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.rectangle,
              ),
              markerDecoration: const BoxDecoration(), // Remove dots
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                return Container(
                  decoration: BoxDecoration(
                    color: _getHeatmapColor(day), // Heatmap color for each day
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.all(4.0),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(color: Colors.black),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorsets[1],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Fewer events'),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorsets[10],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('More events'),
                  ],
                ),
              ],
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
