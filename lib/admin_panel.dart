import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminPanel extends StatefulWidget {
  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController rewardPointsController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();

  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isEditing = false;
  String? _editingEventId;

  void _logout(BuildContext context) async {
    try {
      await _auth.signOut(); // Log out the admin
      Navigator.pushReplacementNamed(
          context, '/login'); // Navigate to the login page
    } catch (e) {
      print("Logout failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  Future<void> _createOrUpdateEvent() async {
    if (nameController.text.isNotEmpty &&
        descriptionController.text.isNotEmpty &&
        startDate != null &&
        startTime != null &&
        endDate != null &&
        endTime != null &&
        rewardPointsController.text.isNotEmpty &&
        latitudeController.text.isNotEmpty &&
        longitudeController.text.isNotEmpty) {
      try {
        DateTime finalStartTime = DateTime(
          startDate!.year,
          startDate!.month,
          startDate!.day,
          startTime!.hour,
          startTime!.minute,
        );
        DateTime finalEndTime = DateTime(
          endDate!.year,
          endDate!.month,
          endDate!.day,
          endTime!.hour,
          endTime!.minute,
        );

        if (_isEditing && _editingEventId != null) {
          // Update event
          await _firestore.collection('events').doc(_editingEventId).update({
            'name': nameController.text,
            'description': descriptionController.text,
            'startTime': Timestamp.fromDate(finalStartTime),
            'endTime': Timestamp.fromDate(finalEndTime),
            'rewardPoints': int.parse(rewardPointsController.text),
            'location': GeoPoint(
              double.parse(latitudeController.text),
              double.parse(longitudeController.text),
            ),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Event Updated Successfully!")),
          );
        } else {
          // Create new event
          await _firestore.collection('events').add({
            'name': nameController.text,
            'description': descriptionController.text,
            'startTime': Timestamp.fromDate(finalStartTime),
            'endTime': Timestamp.fromDate(finalEndTime),
            'rewardPoints': int.parse(rewardPointsController.text),
            'location': GeoPoint(
              double.parse(latitudeController.text),
              double.parse(longitudeController.text),
            ),
            'createdDate': Timestamp.now(),
            'status': 'Upcoming',
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Event Created Successfully!")),
          );
        }

        _clearForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields!")),
      );
    }
  }

  void _clearForm() {
    setState(() {
      nameController.clear();
      descriptionController.clear();
      rewardPointsController.clear();
      latitudeController.clear();
      longitudeController.clear();
      startDate = null;
      startTime = null;
      endDate = null;
      endTime = null;
      _isEditing = false;
      _editingEventId = null;
    });
  }

  Future<void> _deleteEvent(String id) async {
    bool confirmDelete = await _showDeleteConfirmationDialog();
    if (confirmDelete) {
      try {
        await _firestore.collection('events').doc(id).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Event Deleted Successfully!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm Delete'),
            content: Text('Are you sure you want to delete this event?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _editEvent(Map<String, dynamic> eventData, String id) {
    setState(() {
      nameController.text = eventData['name'];
      descriptionController.text = eventData['description'];
      rewardPointsController.text = eventData['rewardPoints'].toString();
      GeoPoint location = eventData['location'];
      latitudeController.text = location.latitude.toString();
      longitudeController.text = location.longitude.toString();
      startDate = (eventData['startTime'] as Timestamp).toDate();
      endDate = (eventData['endTime'] as Timestamp).toDate();
      startTime = TimeOfDay.fromDateTime(startDate!);
      endTime = TimeOfDay.fromDateTime(endDate!);
      _isEditing = true;
      _editingEventId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Panel"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: "Event Name"),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: "Description"),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: rewardPointsController,
                    decoration: InputDecoration(labelText: "Reward Points"),
                    keyboardType: TextInputType.number,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latitudeController,
                          decoration: InputDecoration(labelText: "Latitude"),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: longitudeController,
                          decoration: InputDecoration(labelText: "Longitude"),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _createOrUpdateEvent,
                    child: Text(_isEditing ? "Save Changes" : "Create Event"),
                  ),
                  // Button to create another event
                  if (_isEditing)
                    ElevatedButton(
                      onPressed: _clearForm,
                      child: Text("Create Another Event"),
                    ),
                  TextButton(
                    onPressed: _clearForm,
                    child: Text("Clear Form"),
                  ),
                  Divider(),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('events').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      final events = snapshot.data!.docs;
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          var eventData =
                              events[index].data() as Map<String, dynamic>;
                          var eventId = events[index].id;
                          return ListTile(
                            title: Text(eventData['name']),
                            subtitle: Text(eventData['description']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () =>
                                      _editEvent(eventData, eventId),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () => _deleteEvent(eventId),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
