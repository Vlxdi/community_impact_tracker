import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';

// Level thresholds list moved from profile.dart
final List<int> levelThresholds = [
  0,
  50,
  120,
  210,
  320,
  450,
  600,
  770,
  960,
  1170,
  1400,
  1650,
  1920,
  2210,
  2520,
  2850,
  3200,
  3570,
  3960,
  4370,
  4800,
  5250,
  5720,
  6210,
  6720,
  7250,
  7800,
  8370,
  8960,
  10000
];

int getUserLevel(int totalPoints) {
  for (int i = levelThresholds.length - 1; i >= 0; i--) {
    if (totalPoints >= levelThresholds[i]) {
      return i + 1;
    }
  }
  return 1;
}

class ProfileController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  File? _previewFile;

  // Constructor
  ProfileController();

  Future<String> fetchUsername() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          return userDoc.data()?['username'] ?? 'New User';
        } else {
          return 'New User';
        }
      } catch (e) {
        print("Failed to fetch username: $e");
        return 'Offline';
      }
    }
    return 'Not logged in';
  }

  Future<double> fetchTotalPoints() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          double totalPoints =
              (userDoc.data()?['total_points'] ?? 0.0).toDouble();

          // Calculate the user's level
          int userLevel = getUserLevel(totalPoints.toInt());

          // Update the user's level in the database
          await _firestore.collection('users').doc(user.uid).update({
            'level': userLevel,
          });

          return totalPoints;
        }
      } catch (e) {
        print("Failed to fetch total points: $e");
      }
    }
    return 0.0;
  }

  Future<ImageProvider<Object>?> loadProfileImage() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final storageRef = _storage
            .ref()
            .child('profile_pictures/${user.uid}/${user.uid}.jpg');
        final imageUrl = await storageRef.getDownloadURL();
        return NetworkImage(imageUrl);
      } catch (e) {
        if (e is FirebaseException && e.code == 'object-not-found') {
          print("No profile picture found for user ${user.uid}");
        } else {
          print("Failed to load profile image: $e");
        }
        return null;
      }
    }
    return null;
  }

  Future<File?> cropImage(String imagePath) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: imagePath,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: Colors.blue,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Crop Image',
              minimumAspectRatio: 1.0,
            ),
          ],
        );

        if (croppedFile != null) {
          return File(croppedFile.path);
        } else {
          print("Cropping canceled by user.");
        }
      } else {
        print("Cropping not supported on this platform.");
      }
    } catch (e) {
      print("Error during cropping: $e");
    }

    return null; // Return null if cropping fails
  }

  Future<bool> cropPreviewImage() async {
    if (_previewFile == null) {
      print("No preview file to crop.");
      return false;
    }

    final cropped = await cropImage(_previewFile!.path);
    if (cropped != null) {
      _previewFile = cropped;
      return true;
    }

    return false;
  }

  Future<bool> pickImage(BuildContext context,
      {bool previewMode = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      print("User is NULL! Not logged in.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('You must be logged in to upload a profile picture.')),
      );
      return false;
    }

    print("Current User UID: ${user.uid}");

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      print("No image selected");
      return false;
    }

    File imageFile = File(pickedFile.path);

    if (previewMode) {
      _previewFile = imageFile;
      return true;
    }

    try {
      final storageRef =
          _storage.ref().child('profile_pictures/${user.uid}/${user.uid}.jpg');
      print("Uploading to path: ${storageRef.fullPath}");

      final uploadTask = storageRef.putFile(imageFile);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.state == TaskState.running) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print("Upload Progress: ${progress * 100}%");
        }
      });

      await uploadTask.whenComplete(() async {
        final imageUrl = await storageRef.getDownloadURL();
        await _firestore.collection('users').doc(user.uid).update({
          'profile_picture': imageUrl,
        });
        print("Profile picture URL stored in Firestore: $imageUrl");
      });

      return true;
    } catch (e) {
      print("Failed to upload image: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload profile picture: $e')),
      );

      return false;
    }
  }

  Future<ImageProvider<Object>?> loadPreviewImage() async {
    if (_previewFile != null) {
      return FileImage(_previewFile!);
    }
    return null;
  }

  Future<bool> finalizeImageUpload(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null || _previewFile == null) {
      print("No user or preview file available for upload.");
      return false;
    }

    try {
      final storageRef =
          _storage.ref().child('profile_pictures/${user.uid}/${user.uid}.jpg');
      print("Uploading to path: ${storageRef.fullPath}");

      final uploadTask = storageRef.putFile(_previewFile!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.state == TaskState.running) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print("Upload Progress: ${progress * 100}%");
        }
      });

      await uploadTask.whenComplete(() async {
        final imageUrl = await storageRef.getDownloadURL();

        await _firestore.collection('users').doc(user.uid).update({
          'profile_picture': imageUrl,
        });

        print("Profile picture URL stored in Firestore: $imageUrl");
      });

      _previewFile = null;
      return true;
    } catch (e) {
      print("Failed to upload image: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload profile picture: $e')),
      );

      return false;
    }
  }

  Stream<DocumentSnapshot> fetchWalletBalance() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore.collection('users').doc(user.uid).snapshots();
    }
    return Stream.empty();
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
}
