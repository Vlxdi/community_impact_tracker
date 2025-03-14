import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_impact_tracker/utils/AddSpace.dart';
import 'package:community_impact_tracker/utils/No_leading_zero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'ap_utils/auth_utils.dart';
import 'ap_utils/date_picker_utils.dart';
import 'ap_utils/image_picker_utils.dart';
import 'ap_utils/location_utils.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

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
  String? _currentImageUrl;
  bool _isRemovingImage = false;

  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;

  GoogleMapController? mapController;
  LatLng? selectedLocation;
  Set<Marker> markers = {};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isEditing = false;
  String? _editingEventId;
  Map<String, dynamic> _initialFormState = {};

// Date & Time picker
  Future<void> _pickStartDateTime() async {
    final DateTime? selectedDateTime = await DatePickerUtils.pickStartDateTime(
      context,
      startDate,
      startTime,
    );

    if (selectedDateTime != null) {
      setState(() {
        startDate = selectedDateTime;
        startTime = DatePickerUtils.getTimeOfDayFromDateTime(selectedDateTime);
      });
    }
  }

  Future<void> _pickEndDateTime() async {
    final DateTime? selectedDateTime = await DatePickerUtils.pickEndDateTime(
      context,
      startDate,
      startTime,
      endDate,
      endTime,
    );

    if (selectedDateTime != null) {
      setState(() {
        endDate = selectedDateTime;
        endTime = DatePickerUtils.getTimeOfDayFromDateTime(selectedDateTime);
      });
    }
  }

// Image picker
  Future<void> _pickImage() async {
    final XFile? pickedFile = await ImageUtils.pickImage(context);
    if (pickedFile != null) {
      setState(() {
        _pickedImage = pickedFile;
        _isRemovingImage = false;
      });
    }
  }

  Future<String?> _uploadImageToStorage() async {
    if (_pickedImage == null) return null;
    return await ImageUtils.uploadImageToStorage(
      context,
      _pickedImage!,
      'event_images',
    );
  }

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    await ImageUtils.deleteImageFromStorage(imageUrl);
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _createEvent() async {
    if (nameController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        startDate == null ||
        startTime == null ||
        endDate == null ||
        endTime == null ||
        rewardPointsController.text.isEmpty) {
      // Removed location requirement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all required fields!")),
      );
      return;
    }

    try {
      String? imageUrl;

      if (_pickedImage != null) {
        imageUrl = await _uploadImageToStorage();
      }

      final DateTime finalStartTime = DateTime(
        startDate!.year,
        startDate!.month,
        startDate!.day,
        startTime!.hour,
        startTime!.minute,
      );

      final DateTime finalEndTime = DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
        endTime!.hour,
        endTime!.minute,
      );

      final DocumentReference eventRef = _firestore.collection('events').doc();
      final String eventId = eventRef.id;

      final Map<String, dynamic> eventData = {
        'eventId': eventId,
        'name': nameController.text,
        'description': descriptionController.text,
        'startTime': Timestamp.fromDate(finalStartTime),
        'endTime': Timestamp.fromDate(finalEndTime),
        'rewardPoints': int.parse(rewardPointsController.text),
        'createdDate': Timestamp.now(),
        'status': 'soon',
      };

      if (selectedLocation != null) {
        // Location is now optional
        eventData['location'] = GeoPoint(
          selectedLocation!.latitude,
          selectedLocation!.longitude,
        );
      }

      if (imageUrl != null) {
        eventData['image'] = imageUrl;
      }

      await eventRef.set(eventData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Event Created Successfully!")),
      );

      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _updateEvent() async {
    if (nameController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        startDate == null ||
        startTime == null ||
        endDate == null ||
        endTime == null ||
        rewardPointsController.text.isEmpty) {
      // Removed location requirement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all required fields!")),
      );
      return;
    }

    try {
      String? imageUrl;

      if (_pickedImage != null) {
        imageUrl = await _uploadImageToStorage();
      }

      final DateTime finalStartTime = DateTime(
        startDate!.year,
        startDate!.month,
        startDate!.day,
        startTime!.hour,
        startTime!.minute,
      );

      final DateTime finalEndTime = DateTime(
        endDate!.year,
        endDate!.month,
        endDate!.day,
        endTime!.hour,
        endTime!.minute,
      );

      final Map<String, dynamic> eventData = {
        'eventId': _editingEventId,
        'name': nameController.text,
        'description': descriptionController.text,
        'startTime': Timestamp.fromDate(finalStartTime),
        'endTime': Timestamp.fromDate(finalEndTime),
        'rewardPoints': int.parse(rewardPointsController.text),
      };

      if (selectedLocation != null) {
        // Location is now optional
        eventData['location'] = GeoPoint(
          selectedLocation!.latitude,
          selectedLocation!.longitude,
        );
      }

      if (_isRemovingImage) {
        if (_currentImageUrl != null) {
          await _deleteImageFromStorage(_currentImageUrl!);
        }
        eventData['image'] = FieldValue.delete();
      } else if (imageUrl != null) {
        if (_currentImageUrl != null) {
          await _deleteImageFromStorage(_currentImageUrl!);
        }
        eventData['image'] = imageUrl;
      }

      await _firestore
          .collection('events')
          .doc(_editingEventId)
          .update(eventData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Event Updated Successfully!")),
      );

      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _deleteEvent(String id) async {
    bool confirmDelete = await _showDeleteConfirmationDialog();
    if (confirmDelete) {
      try {
        final DocumentSnapshot event =
            await _firestore.collection('events').doc(id).get();
        final data = event.data() as Map<String, dynamic>?;

        if (data != null && data['image'] != null) {
          await _deleteImageFromStorage(data['image']);
        }

        await _firestore.collection('events').doc(id).delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Event Deleted Successfully!")),
        );

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
      _pickedImage = null;
      _currentImageUrl = null;
      _isRemovingImage = false;
    });
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

  void _editEvent(Map<String, dynamic> eventData, String id) async {
    if (_hasUnsavedChanges()) {
      bool proceed = await _showUnsavedChangesDialog();
      if (!proceed) {
        return;
      }
    }

    setState(() {
      nameController.text = eventData['name'];
      descriptionController.text = eventData['description'];
      rewardPointsController.text = eventData['rewardPoints'].toString();

      if (eventData['location'] is GeoPoint) {
        GeoPoint location = eventData['location'];
        selectedLocation = LatLng(location.latitude, location.longitude);
        _updateMarker();
      }

      startDate = (eventData['startTime'] as Timestamp).toDate();
      endDate = (eventData['endTime'] as Timestamp).toDate();
      startTime = TimeOfDay.fromDateTime(startDate!);
      endTime = TimeOfDay.fromDateTime(endDate!);

      _isEditing = true;
      _editingEventId = id;
      _currentImageUrl = eventData['image'];
      _pickedImage = null;
      _isRemovingImage = false;

      _setInitialFormState();
    });
  }

  void _setInitialFormState() {
    _initialFormState = {
      'name': nameController.text,
      'description': descriptionController.text,
      'rewardPoints': rewardPointsController.text,
      'startDate': startDate,
      'startTime': startTime,
      'endDate': endDate,
      'endTime': endTime,
      'location': selectedLocation,
      'image': _pickedImage,
    };
  }

  bool _hasUnsavedChanges() {
    return _initialFormState['name'] != nameController.text ||
        _initialFormState['description'] != descriptionController.text ||
        _initialFormState['rewardPoints'] != rewardPointsController.text ||
        _initialFormState['startDate'] != startDate ||
        _initialFormState['startTime'] != startTime ||
        _initialFormState['endDate'] != endDate ||
        _initialFormState['endTime'] != endTime ||
        _initialFormState['location'] != selectedLocation ||
        _initialFormState['image'] != _pickedImage;
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Unsaved Changes'),
            content: Text(
                'You have unsaved changes. Do you want to discard them and continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

// Location setter
  Future<void> _getCurrentLocation() async {
    final location = await LocationUtils.getCurrentLocation(context);
    setState(() {
      selectedLocation = location;
      _updateMarker();
    });
  }

  void _updateMarker() {
    if (selectedLocation != null) {
      setState(() {
        markers = LocationUtils.createMarker(
          selectedLocation!,
          (newPosition) {
            setState(() {
              selectedLocation = newPosition;
            });
          },
        );
      });
    }
  }

  Widget _buildMapSelector() {
    return LocationUtils.buildMapSelector(
      context: context,
      selectedLocation: selectedLocation,
      markers: markers,
      onMapCreated: (GoogleMapController controller) {
        mapController = controller;
      },
      onLocationSelected: (LatLng position) {
        setState(() {
          selectedLocation = position;
          _updateMarker();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Panel"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => AuthUtils.logout(context),
          ),
        ],
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
                    maxLength: 40,
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: "Description"),
                    maxLines: 5,
                    maxLength: 1000,
                  ),
                  TextField(
                    controller: rewardPointsController,
                    decoration: InputDecoration(labelText: "Reward Points"),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      NoLeadingZeroFormatter(), // Prevents leading zero
                    ],
                  ),
                  Vspace(10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Start Date and Time",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Vspace(5),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _pickStartDateTime,
                            child: Text("Select"),
                          ),
                          Hspace(16),
                          Text(
                            startDate != null && startTime != null
                                ? "${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')} ${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}"
                                : "Not Selected",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      Vspace(10),
                      Text("End Date and Time",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Vspace(5),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _pickEndDateTime,
                            child: Text("Select"),
                          ),
                          Hspace(16),
                          Text(
                            endDate != null && endTime != null
                                ? "${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')} ${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}"
                                : "Not Selected",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Vspace(10),
                  Text("Location",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: _buildMapSelector(),
                  ),
                  Vspace(15),
                  ImageUtils.buildImagePreview(
                    pickedImage: _pickedImage,
                    currentImageUrl: _currentImageUrl,
                    isRemovingImage: _isRemovingImage,
                    onPickImage: _pickImage,
                    onRemoveImage: () {
                      setState(() {
                        _pickedImage = null;
                        _isRemovingImage = true;
                      });
                    },
                  ),
                  Vspace(15),
                  Column(
                    spacing: 5,
                    children: [
                      ElevatedButton(
                        onPressed: _isEditing ? _updateEvent : _createEvent,
                        child:
                            Text(_isEditing ? "Save Changes" : "Create Event"),
                      ),
                      ElevatedButton(
                        onPressed: _clearForm,
                        child: Text("Clear Form"),
                      ),
                    ],
                  ),
                  Vspace(10),
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
                  Vspace(5),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('events').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      final events = snapshot.data!.docs;
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          var eventData =
                              events[index].data() as Map<String, dynamic>;
                          var eventId = events[index].id;
                          return ListTile(
                            leading: eventData['image'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      eventData['image'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(Icons.image_not_supported),
                            title: Text(eventData['name']),
                            subtitle: Text(
                              eventData['description'].length > 140
                                  ? eventData['description'].substring(0, 140) +
                                      '...'
                                  : eventData['description'],
                              maxLines:
                                  2, // Limit the lines to control overflow
                              overflow: TextOverflow.ellipsis,
                            ),
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
