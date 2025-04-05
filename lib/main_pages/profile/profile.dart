import 'dart:io';
import 'package:community_impact_tracker/main_pages/profile/my_events_archive.dart';
import 'package:community_impact_tracker/utils/AddSpace.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../widgets/achievement.dart';
import '../../widgets/badge.dart';
import '../settings/settings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

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
  double _totalPoints = 0.0; // Change type to double

  @override
  void initState() {
    super.initState();
    _fetchUsername();
    _loadProfileImage();
    _fetchTotalPoints(); // Fetch total points on initialization
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

  Future<void> _fetchTotalPoints() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _totalPoints = (userDoc.data()?['total_points'] ?? 0.0)
                .toDouble(); // Ensure double
          });

          // Calculate the user's level
          int userLevel = getUserLevel(
              _totalPoints.toInt()); // Convert to int for level calculation

          // Update the user's level in the database
          await _firestore.collection('users').doc(user.uid).update({
            'level': userLevel,
          });
        }
      } catch (e) {
        print("Failed to fetch total points: $e");
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
    if (user == null) {
      print("User is NULL! Not logged in."); // Important check
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('You must be logged in to upload a profile picture.')),
      );
      return;
    }

    print("Current User UID: ${user.uid}"); // Print the UID

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
      final storageRef =
          _storage.ref().child('profile_pictures/${user.uid}/${user.uid}.jpg');
      print("Uploading to path: ${storageRef.fullPath}"); // Print the full path

      final uploadTask = storageRef.putFile(file);

      // Add a listener to the upload task for progress updates (optional):
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.state == TaskState.running) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print("Upload Progress: ${progress * 100}%");
          // You can use this progress to update a progress bar in your UI
        }
      });

      await uploadTask.whenComplete(() async {
        final imageUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'profile_picture': imageUrl,
        });

        print("Profile picture URL stored in Firestore: $imageUrl");
        await _loadProfileImage();
      });
    } catch (e) {
      print("Failed to upload image: $e");

      setState(() {
        _uploading = false; // Set uploading to false even on error
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to upload profile picture: $e')), // Show the actual error
      );
    }
  }

  Widget _fetchWalletBalance() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData ||
            snapshot.data == null ||
            !snapshot.data!.exists) {
          return const Text("Wallet Balance: 0.00",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
        }

        double walletBalance = (snapshot.data!.get('wallet_balance') ?? 0.0)
            .toDouble(); // Ensure double

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_rounded, size: 30),
            Text("Wallet Balance: ${walletBalance.toStringAsFixed(2)}",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.keyboard_double_arrow_up_rounded,
                            color: Colors.green, size: 30),
                        Text(
                          "Level ${getUserLevel(_totalPoints.toInt())}", // Use fetched total points
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Vspace(5),
                    _fetchWalletBalance(),
                  ],
                ),
              ),
              Vspace(30),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyEventsArchive(
                            userId: FirebaseAuth.instance.currentUser!.uid),
                      ),
                    );
                  },
                  icon: Icon(Icons.event_note),
                  label: Text("My Events Archive"),
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
