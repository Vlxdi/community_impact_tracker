import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  Future<bool> pickImage(BuildContext context) async {
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

    final file = File(pickedFile.path);

    try {
      final storageRef =
          _storage.ref().child('profile_pictures/${user.uid}/${user.uid}.jpg');
      print("Uploading to path: ${storageRef.fullPath}");

      final uploadTask = storageRef.putFile(file);

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
