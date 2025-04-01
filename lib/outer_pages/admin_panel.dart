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
  final TextEditingController maxParticipantsController =
      TextEditingController();
  int maxParticipants = 50; // Default value
  final TextEditingController currentParticipantsController =
      TextEditingController();
  int currentParticipants = 0; // Default value

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

  final Set<String> _selectedEventIds =
      {}; // Store selected event IDs for batch delete
  bool _isBatchDeleteMode = false; // Track if batch delete mode is active

  void _toggleEventSelection(String eventId) {
    setState(() {
      if (_selectedEventIds.contains(eventId)) {
        _selectedEventIds.remove(eventId);
      } else {
        _selectedEventIds.add(eventId);
      }
    });
  }

  void _toggleBatchDeleteMode() {
    setState(() {
      _isBatchDeleteMode = !_isBatchDeleteMode;
      if (!_isBatchDeleteMode) {
        _selectedEventIds
            .clear(); // Clear selections when exiting batch delete mode
      }
    });
  }

  Future<void> _batchDeleteEvents() async {
    if (_selectedEventIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No events selected for deletion!")),
      );
      return;
    }

    bool confirmDelete = await _showDeleteConfirmationDialog();
    if (confirmDelete) {
      try {
        for (String eventId in _selectedEventIds) {
          final DocumentSnapshot event =
              await _firestore.collection('events').doc(eventId).get();
          final data = event.data() as Map<String, dynamic>?;

          if (data != null && data['image'] != null) {
            await _deleteImageFromStorage(data['image']);
          }

          await _firestore.collection('events').doc(eventId).delete();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Selected events deleted successfully!")),
        );

        setState(() {
          _selectedEventIds.clear();
          _isBatchDeleteMode = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

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
        rewardPointsController.text.isEmpty ||
        maxParticipantsController.text.isEmpty) {
      // Removed location requirement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all required fields!")),
      );
      return;
    }

    if (maxParticipantsController.text.isEmpty ||
        int.tryParse(maxParticipantsController.text) == null ||
        int.parse(maxParticipantsController.text) < 1 ||
        int.parse(maxParticipantsController.text) > 500) {
      debugPrint(
          "Validation failed for maxParticipants: ${maxParticipantsController.text}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Max Participants must be between 1 and 500!")),
      );
      return;
    }

// Ensure current participants is set with a default value
    int currentParticipants =
        int.tryParse(currentParticipantsController.text) ?? 0;

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
        'eventId': _isEditing ? _editingEventId : eventRef.id,
        'name': nameController.text,
        'description': descriptionController.text,
        'startTime': Timestamp.fromDate(finalStartTime),
        'endTime': Timestamp.fromDate(finalEndTime),
        'rewardPoints': int.parse(rewardPointsController.text),
        'createdDate':
            _isEditing ? null : Timestamp.now(), // Only set for new events
        'status': _isEditing ? null : 'soon', // Only set for new events
        'maxParticipants': int.parse(maxParticipantsController.text),
        'currentParticipants': currentParticipants,
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
    if (_editingEventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No event selected for update!")),
      );
      return;
    }

    if (nameController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        startDate == null ||
        startTime == null ||
        endDate == null ||
        endTime == null ||
        rewardPointsController.text.isEmpty ||
        maxParticipantsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all required fields!")),
      );
      return;
    }

    // Separate validation for max participants
    int? maxParticipantsValue = int.tryParse(maxParticipantsController.text);
    if (maxParticipantsValue == null ||
        maxParticipantsValue < 1 ||
        maxParticipantsValue > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Max Participants must be between 1 and 500!")),
      );
      return;
    }

    // Ensure current participants is set with a default value
    int currentParticipants =
        int.tryParse(currentParticipantsController.text) ?? 0;

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
        'maxParticipants': int.parse(maxParticipantsController.text),
        'currentParticipants': currentParticipants,
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
      maxParticipantsController.clear();
      maxParticipants = 50; // Reset to default
      currentParticipantsController.clear();
      currentParticipants = 0; // Reset to default
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
      maxParticipantsController.text = eventData['maxParticipants'].toString();
      maxParticipants = int.parse(maxParticipantsController.text);

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
        child: Stack(
          children: [
            Column(
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
                      Text("Max Participants",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Vspace(5),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: maxParticipants.toDouble(),
                              min: 1,
                              max: 500,
                              divisions: 499,
                              label: maxParticipants.toString(),
                              onChanged: (value) {
                                setState(() {
                                  maxParticipants = value.toInt();
                                  maxParticipantsController.text =
                                      maxParticipants.toString();
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: maxParticipantsController,
                              decoration: InputDecoration(
                                labelText: "Max",
                                errorText: _validateMaxParticipants(
                                    maxParticipantsController.text),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (value) {
                                int? parsedValue = int.tryParse(value);
                                if (parsedValue != null &&
                                    parsedValue >= 1 &&
                                    parsedValue <= 500) {
                                  setState(() {
                                    maxParticipants = parsedValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      Vspace(20),
                      Column(
                        spacing: 5,
                        children: [
                          ElevatedButton(
                            onPressed: _isEditing ? _updateEvent : _createEvent,
                            child: Text(
                                _isEditing ? "Save Changes" : "Create Event"),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Existing Events',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          IconButton(
                            icon: Icon(
                              _isBatchDeleteMode
                                  ? Icons.close
                                  : Icons.select_all_rounded,
                              color: Colors.blue,
                            ),
                            onPressed: _toggleBatchDeleteMode,
                          ),
                        ],
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
                                leading: _isBatchDeleteMode
                                    ? Checkbox(
                                        value:
                                            _selectedEventIds.contains(eventId),
                                        onChanged: (isSelected) {
                                          _toggleEventSelection(eventId);
                                        },
                                      )
                                    : (eventData['image'] != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              eventData['image'],
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Icon(Icons.image_not_supported)),
                                title: Text(eventData['name']),
                                subtitle: Text(
                                  eventData['description'].length > 140
                                      ? eventData['description']
                                              .substring(0, 140) +
                                          '...'
                                      : eventData['description'],
                                  maxLines:
                                      2, // Limit the lines to control overflow
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: !_isBatchDeleteMode
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit),
                                            onPressed: () =>
                                                _editEvent(eventData, eventId),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete),
                                            onPressed: () =>
                                                _deleteEvent(eventId),
                                          ),
                                        ],
                                      )
                                    : null,
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
            if (_isBatchDeleteMode && _selectedEventIds.isNotEmpty)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: _batchDeleteEvents,
                  child: Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  tooltip: "Delete Selected Events",
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String? _validateMaxParticipants(String? value) {
  if (value == null || value.isEmpty) {
    return 'Cannot be empty';
  }

  int? parsedValue = int.tryParse(value);
  if (parsedValue == null) {
    return 'Invalid number';
  }

  if (parsedValue < 1) {
    return 'Min 1';
  }

  if (parsedValue > 500) {
    return 'Max 500';
  }

  return null;
}
