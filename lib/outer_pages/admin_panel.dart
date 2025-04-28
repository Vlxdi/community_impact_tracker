import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_impact_tracker/outer_pages/admin_shop_panel.dart';
import 'package:community_impact_tracker/utils/addSpace.dart';
import 'package:community_impact_tracker/utils/noLeadingZero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:community_impact_tracker/outer_pages/admin_utils/maxParticipantsValidations.dart';
import 'package:community_impact_tracker/outer_pages/admin_utils/mapSelector.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:saver_gallery/saver_gallery.dart';

import 'admin_utils/authUtils.dart';
import 'admin_utils/datePicker.dart';
import 'admin_utils/imagePicker.dart';
import 'admin_utils/locationUtils.dart';

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

  bool _isShopPanel = false; // Track the current panel

  void _togglePanel() {
    setState(() {
      _isShopPanel = !_isShopPanel;
    });
    if (_isShopPanel) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminShopPage()),
      );
    }
  }

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

      // Generate a secure token for check-in
      final String checkinToken = _generateSecureToken();

      final Map<String, dynamic> eventData = {
        'eventId': eventId,
        'name': nameController.text,
        'description': descriptionController.text,
        'startTime': Timestamp.fromDate(finalStartTime),
        'endTime': Timestamp.fromDate(finalEndTime),
        'rewardPoints': int.parse(rewardPointsController.text),
        'createdDate': Timestamp.now(),
        'status': 'soon',
        'maxParticipants': int.parse(maxParticipantsController.text),
        'currentParticipants': currentParticipants,
        'checkin_token': checkinToken, // Add the secure token
      };

      if (selectedLocation != null) {
        eventData['location'] = GeoPoint(
          selectedLocation!.latitude,
          selectedLocation!.longitude,
        );
      }

      if (imageUrl != null) {
        eventData['image'] = imageUrl;
      }

      await eventRef.set(eventData);

      // Generate and display the QR code
      _showQRCodePopup(eventId, checkinToken);

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

  String _generateSecureToken() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        "_" +
        UniqueKey().toString();
  }

  void _showQRCodePopup(String eventId, String checkinToken) {
    final qrData = checkinToken; // Only include the check-in token value

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Event QR Code"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Show this QR code to the participants at the end of the event, so they can check in!",
              textAlign: TextAlign.center,
            ),
            Vspace(10),
            SizedBox(
              width: 200.0,
              height: 200.0,
              child: QrImageView(
                data: qrData, // Use the check-in token value as QR code data
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            Vspace(10),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _downloadQRCode(qrData),
                icon: Icon(Icons.download),
                label: Text("Download"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Close"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQRCode(String qrData) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: qrData, // Use the check-in token value as QR code data
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );

        final pictureRecorder = ui.PictureRecorder();
        final canvas = Canvas(pictureRecorder);
        final size = 200.0;
        final paintSize = Size(size, size);

        painter.paint(canvas, paintSize);
        final picture = pictureRecorder.endRecording();
        final image = await picture.toImage(size.toInt(), size.toInt());
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          throw Exception("Failed to convert QR code to bytes.");
        }

        final imageBytes = byteData.buffer.asUint8List();

        // Save the image to the gallery
        await SaverGallery.saveImage(
          imageBytes,
          fileName: 'event_qr_code.png',
          skipIfExists: false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("QR Code saved to gallery.")),
        );

        // Close the dialog after saving
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving QR Code: $e")),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Panel - Events"),
        actions: [
          IconButton(
            icon:
                Icon(_isShopPanel ? Icons.event : Icons.shopping_cart_rounded),
            onPressed: _togglePanel,
          ),
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
                        child: MapSelector(
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
                        ),
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
                          Hspace(60),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: maxParticipantsController,
                              decoration: InputDecoration(
                                labelText: "Max",
                                errorText: validateMaxParticipants(
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
                      Vspace(16),
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
