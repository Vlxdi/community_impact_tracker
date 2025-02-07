import 'dart:io';
import 'package:community_impact_tracker/utils/AddSpace.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/achievement.dart';
import '../widgets/badge.dart';
import 'settings/settings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage =
      FirebaseStorage.instance; // Add storage instance
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Add firestore instance
  final ImagePicker _picker = ImagePicker();
  ImageProvider<Object>? _profileImage;
  String _username = "Loading...";
  bool _uploading = false; // Add uploading state

  @override
  void initState() {
    super.initState();
    _fetchUsername();
    _loadProfileImage();
  }

  Future<void> _fetchUsername() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _username = userDoc.data()?['username'] ?? 'New User';
          });
        } else {
          setState(() {
            _username = 'New User';
          });
        }
      } catch (e) {
        print("Failed to fetch username: $e");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _username = 'Offline';
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to fetch profile information')),
        );
      }
    }
  }

  Future<void> _loadProfileImage() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final storageRef = _storage.ref().child(
            'profile_pictures/${user.uid}/${user.uid}.jpg'); // User-specific folder
        final imageUrl = await storageRef.getDownloadURL();
        setState(() {
          _profileImage = NetworkImage(imageUrl);
        });
      } catch (e) {
        if (e is FirebaseException && e.code == 'object-not-found') {
          print("No profile picture found for user ${user.uid}");
        } else {
          print("Failed to load profile image: $e");
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      print("No image selected");
      return;
    }

    final file = File(pickedFile.path);

    setState(() {
      _uploading = true; // Set uploading to true
    });

    try {
      final storageRef = _storage.ref().child(
          'profile_pictures/${user.uid}/${user.uid}.jpg'); // User-specific folder
      final uploadTask = storageRef.putFile(file);

      await uploadTask.whenComplete(() async {
        print("Upload completed for: ${storageRef.fullPath}");
        await _loadProfileImage(); // Refresh profile image after upload

        setState(() {
          _uploading = false; // Set uploading to false after success
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      });
    } catch (e) {
      print("Failed to upload image: $e");

      setState(() {
        _uploading = false; // Set uploading to false even on error
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload profile picture')),
      );
    }
  }

  void _showProfilePictureDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Change picture?"),
          content: const Text(
              "Do you want to change your profile picture or leave it as is?"),
          actions: [
            TextButton(
              child: const Text("Leave it"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Change it"),
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              bool? shouldRefresh = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
              if (shouldRefresh == true) {
                _fetchUsername();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _showProfilePictureDialog,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _profileImage,
                        child: _profileImage == null
                            ? Icon(Icons.person_2_rounded,
                                size: 70, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        width: 25,
                        height: 25,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cameraswitch_rounded,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Vspace(10),
              Center(
                child: Text(
                  _username,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Vspace(10),
              // User level and wallet balance
              Center(
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.keyboard_double_arrow_up_rounded,
                            color: Colors.green, size: 30),
                        Text("Level 10",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Vspace(5),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_rounded, size: 30),
                        Text("Wallet Balance: 500",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              Vspace(30),

              // Badges section
              Text("Badges",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Vspace(10),
              SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8.0,
                    children: <Widget>[
                      BadgeWidget(badgeName: "Community Star"),
                      BadgeWidget(badgeName: "Volunteer Leader"),
                      BadgeWidget(badgeName: "Helping Hand"),
                      BadgeWidget(badgeName: "Feedback Giver"),
                    ],
                  ),
                ),
              ),

              Vspace(10),

              // Achievements section
              Text("Achievements",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Vspace(10),
              SingleChildScrollView(
                child: Column(
                  children: [
                    AchievementWidget(achievementName: "Completed 5 Events"),
                    AchievementWidget(achievementName: "100 Hours of Service"),
                    AchievementWidget(
                        achievementName: "Top Volunteer in March"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
