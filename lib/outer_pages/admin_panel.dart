import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_impact_tracker/utils/AddSpace.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  String? _currentImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isRemovingImage = false;

  DateTime? startDate;
  TimeOfDay? startTime;
  DateTime? endDate;
  TimeOfDay? endTime;

  GoogleMapController? mapController;
  LatLng? selectedLocation;
  Set<Marker> markers = {};

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isEditing = false;
  String? _editingEventId;
  Map<String, dynamic> _initialFormState = {};

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

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024, // Limit image size
        maxHeight: 1024,
        imageQuality: 85, // Compress image
      );

      if (pickedFile != null) {
        setState(() {
          _pickedImage = pickedFile;
          _isRemovingImage = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<String?> _uploadImageToStorage() async {
    if (_pickedImage == null) return null;

    try {
      final String fileName =
          'event_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('event_images').child(fileName);

      final UploadTask uploadTask =
          storageRef.putFile(File(_pickedImage!.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    try {
      final Reference storageRef =
          FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();
    } catch (e) {
      print('Error deleting image from storage: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _createOrUpdateEvent() async {
    if (nameController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        startDate == null ||
        startTime == null ||
        endDate == null ||
        endTime == null ||
        rewardPointsController.text.isEmpty ||
        selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please fill all fields and select a location!")),
      );
      return;
    }

    try {
      String? imageUrl;

      // Handle image upload for new image
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
        'name': nameController.text,
        'description': descriptionController.text,
        'startTime': Timestamp.fromDate(finalStartTime),
        'endTime': Timestamp.fromDate(finalEndTime),
        'rewardPoints': int.parse(rewardPointsController.text),
        'location': GeoPoint(
          selectedLocation!.latitude,
          selectedLocation!.longitude,
        ),
      };

      if (_isEditing && _editingEventId != null) {
        // Handle image update in edit mode
        if (_isRemovingImage) {
          // Delete old image if it exists and user wants to remove it
          if (_currentImageUrl != null) {
            await _deleteImageFromStorage(_currentImageUrl!);
          }
          eventData['image'] = FieldValue.delete();
        } else if (imageUrl != null) {
          // If new image is selected, delete old one and update with new URL
          if (_currentImageUrl != null) {
            await _deleteImageFromStorage(_currentImageUrl!);
          }
          eventData['image'] = imageUrl;
        }
        // If no image changes, don't update the image field

        await _firestore
            .collection('events')
            .doc(_editingEventId)
            .update(eventData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Event Updated Successfully!")),
        );
      } else {
        // Create new event
        if (imageUrl != null) {
          eventData['image'] = imageUrl;
        }
        eventData['createdDate'] = Timestamp.now();
        eventData['status'] = 'Upcoming';

        await _firestore.collection('events').add(eventData);
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

  Future<void> _deleteEvent(String id) async {
    bool confirmDelete = await _showDeleteConfirmationDialog();
    if (confirmDelete) {
      try {
        // Get the event data first
        final DocumentSnapshot event =
            await _firestore.collection('events').doc(id).get();
        final data = event.data() as Map<String, dynamic>?;

        // Delete the image from storage if it exists
        if (data != null && data['image'] != null) {
          await _deleteImageFromStorage(data['image']);
        }

        // Delete the event document
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
        return; // Do nothing if the user cancels
      }
    }

    // Set form data for editing
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

      // Set the initial state
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
        false; // Default to false if the dialog is dismissed
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        // If permission is still denied after requesting, use a default location
        setState(() {
          selectedLocation = LatLng(0, 0);
          _updateMarker();
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        // Handle permanently denied permissions
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Location permissions are permanently denied. Please enable them in settings.'),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          selectedLocation = LatLng(0, 0);
          _updateMarker();
        });
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        );
        setState(() {
          selectedLocation = LatLng(position.latitude, position.longitude);
          _updateMarker();
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      // Use a default location if unable to get current location
      setState(() {
        selectedLocation = LatLng(0, 0);
        _updateMarker();
      });
    }
  }

  void _updateMarker() {
    if (selectedLocation != null) {
      markers.clear();
      markers.add(
        Marker(
          markerId: MarkerId('selected_location'),
          position: selectedLocation!,
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() {
              selectedLocation = newPosition;
            });
          },
        ),
      );
    }
  }

  Widget _buildMapSelector() {
    return Container(
      width: MediaQuery.of(context).size.width - 32, // Full width minus padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Event Location", style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: selectedLocation == null
                  ? Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        mapController = controller;
                      },
                      initialCameraPosition: CameraPosition(
                        target: selectedLocation ?? LatLng(0, 0),
                        zoom: 15,
                      ),
                      markers: markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      onTap: (LatLng position) {
                        setState(() {
                          selectedLocation = position;
                          _updateMarker();
                        });
                      },
                    ),
            ),
          ),
          if (selectedLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Selected: ${selectedLocation!.latitude.toStringAsFixed(6)}, ${selectedLocation!.longitude.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
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
                            startDate != null
                                ? "${startDate!.toLocal()}".split('.')[0]
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
                            endDate != null
                                ? "${endDate!.toLocal()}".split('.')[0]
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
                  Text("Event Image",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _pickImage,
                        child: Text('Select'),
                      ),
                      if (_pickedImage != null || _currentImageUrl != null)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _pickedImage = null;
                              _isRemovingImage = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: Text('Remove'),
                        ),
                    ],
                  ),
                  Vspace(10),
                  // Image preview section
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: !_isRemovingImage
                        ? (_pickedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_pickedImage!.path),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : _currentImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _currentImageUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text('No image selected'),
                                  ))
                        : Center(
                            child: Text('No image selected'),
                          ),
                  ),
                  Vspace(15),
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
            //Logout
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
