// profile.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  // Function to show a dialog for changing the profile picture
  void _showProfilePictureDialog() {
    if (_profileImage == null) {
      _pickImage(); // If no profile picture is selected yet, allow the user to choose one
    } else {
      // If the user already has a profile picture, show the dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Profile Picture"),
            content: Text(
                "Do you want to change your profile picture or leave it as is?"),
            actions: [
              TextButton(
                child: Text("Leave it"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("Change it"),
                onPressed: () {
                  Navigator.of(context).pop();
                  _pickImage(); // Let the user select a new image
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Navigate to the settings page when pressed
              // Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile picture with click action
              Center(
                child: GestureDetector(
                  onTap:
                      _showProfilePictureDialog, // Show dialog when profile picture is tapped
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : AssetImage('assets/default_profile_pic.jpg')
                            as ImageProvider, // Use default image if none is selected
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Profile information with icons
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, color: Colors.yellow, size: 30),
                        SizedBox(width: 10),
                        Text(
                          "Level: 10",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet,
                            color: Colors.green, size: 30),
                        SizedBox(width: 10),
                        Text(
                          "Wallet Balance: 500 Points",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),

              // Badges section
              Text(
                "Badges",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    BadgeWidget(badgeName: "Community Star"),
                    BadgeWidget(badgeName: "Volunteer Leader"),
                    BadgeWidget(badgeName: "Helping Hand"),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Achievements section
              Text(
                "Achievements",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Column(
                children: [
                  AchievementWidget(achievementName: "Completed 5 Events"),
                  AchievementWidget(achievementName: "100 Hours of Service"),
                  AchievementWidget(achievementName: "Top Volunteer in March"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BadgeWidget extends StatelessWidget {
  final String badgeName;

  BadgeWidget({required this.badgeName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          badgeName,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class AchievementWidget extends StatelessWidget {
  final String achievementName;

  AchievementWidget({required this.achievementName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.greenAccent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.yellow),
          SizedBox(width: 10),
          Text(
            achievementName,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
