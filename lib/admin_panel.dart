import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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

  XFile? _pickedImage;
  final ImagePicker _imagePicker = ImagePicker();

  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isEditing = false;
  String? _editingEventId;

  void _logout(BuildContext context) async {
    bool confirmLogout = await _showLogoutConfirmationDialog();
    if (confirmLogout) {
      try {
        await _auth.signOut();
        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        print("Logout failed: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed. Please try again.')),
        );
      }
    }
  }

  Future<bool> _showLogoutConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm Logout'),
            content: Text(
                'Are you sure you want to log out from Administrator Account?\n(You will not be able to access Admin Panel as a regular user)'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _pickStartDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: startTime ?? TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          startDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          startTime = pickedTime;
        });
      }
    }
  }

  Future<void> _pickEndDateTime() async {
    if (startDate == null || startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select the start date and time first.")),
      );
      return;
    }

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate:
          startDate!, // Start date must be at least the selected start date
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: endTime ?? TimeOfDay.now(),
      );

      if (pickedTime != null) {
        DateTime selectedEndDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        DateTime selectedStartDateTime = DateTime(
          startDate!.year,
          startDate!.month,
          startDate!.day,
          startTime!.hour,
          startTime!.minute,
        );

        if (selectedEndDateTime.isBefore(selectedStartDateTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("End time cannot be before the start time."),
            ),
          );
        } else if (selectedEndDateTime
            .isAtSameMomentAs(selectedStartDateTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("End time cannot be the same as the start time."),
            ),
          );
        } else {
          setState(() {
            endDate = pickedDate;
            endTime = pickedTime;
          });
        }
      }
    }
  }

  Future<void> _selectAndUploadImage() async {
    try {
      print("Starting image selection...");
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        print("Image selected: ${pickedFile.path}");
        setState(() {
          _pickedImage = pickedFile;
        });

        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('event_images')
            .child(fileName);

        print("Uploading to path: event_images/$fileName");

        final uploadTask = storageRef.putFile(File(_pickedImage!.path));
        final snapshot = await uploadTask.whenComplete(() {
          print("Upload complete");
        });

        print("Fetching download URL...");
        final downloadUrl = await snapshot.ref.getDownloadURL();
        print("Download URL fetched: $downloadUrl");

        await _firestore.collection('events').add({
          'image': downloadUrl,
          // Include other fields as required
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image uploaded successfully!')),
        );
      } else {
        print("No image selected.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No image selected')),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  Future<void> _createOrUpdateEvent() async {
    if (nameController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        startDate == null ||
        startTime == null ||
        endDate == null ||
        endTime == null ||
        rewardPointsController.text.isEmpty ||
        latitudeController.text.isEmpty ||
        longitudeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields!")),
      );
      return;
    }

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

    if (finalEndTime.isBefore(finalStartTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "End date and time cannot be before the start date and time.")),
      );
      return;
    }

    if (finalEndTime.isAtSameMomentAs(finalStartTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "End date and time cannot be the same as the start date and time.")),
      );
      return;
    }

    try {
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

        // If the deleted event was being edited, clear the form and reset the state
        if (_isEditing && _editingEventId == id) {
          _clearForm();
        }
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

      if (eventData['location'] is GeoPoint) {
        GeoPoint location = eventData['location'];
        latitudeController.text = location.latitude.toString();
        longitudeController.text = location.longitude.toString();
      } else {
        // Handle invalid or missing location data
        latitudeController.text = '0.0';
        longitudeController.text = '0.0';
      }

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
                    maxLength: 100,
                  ),
                  TextField(
                    controller: rewardPointsController,
                    decoration: InputDecoration(labelText: "Reward Points"),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Start Date and Time",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        height: 5,
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _pickStartDateTime,
                            child: Text("Select"),
                          ),
                          SizedBox(width: 16),
                          Text(
                            startDate != null
                                ? "${startDate!.toLocal()}".split('.')[0]
                                : "Not Selected",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text("End Date and Time",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        height: 5,
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _pickEndDateTime,
                            child: Text("Select"),
                          ),
                          SizedBox(width: 16),
                          Text(
                            endDate != null
                                ? "${endDate!.toLocal()}".split('.')[0]
                                : "Not Selected",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text("Location",
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                  SizedBox(height: 15),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _selectAndUploadImage,
                        child: Text('Upload Image'),
                      ),
                      SizedBox(width: 10),
                      if (_pickedImage != null) Text('Image Selected'),
                    ],
                  ),
                  SizedBox(height: 15),
                  Column(
                    spacing: 5,
                    children: [
                      ElevatedButton(
                        onPressed: _createOrUpdateEvent,
                        child:
                            Text(_isEditing ? "Save Changes" : "Create Event"),
                      ),
                      ElevatedButton(
                        onPressed: _clearForm,
                        child: Text("Clear Form"),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  if (_isEditing)
                    ElevatedButton(
                      onPressed: _clearForm,
                      child: Text("Create New Event"),
                    ),
                  Divider(),
                  SizedBox(
                    height: 16,
                  ),

                  //Existing events list section
                  Text(
                    'Existing Events',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    height: 5,
                  ),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, top: 16.0),
              child: ElevatedButton(
                onPressed: () => _logout(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
