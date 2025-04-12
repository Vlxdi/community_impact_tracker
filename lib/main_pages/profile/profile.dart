import 'package:community_impact_tracker/main_pages/profile/my_events_archive.dart';
import 'package:community_impact_tracker/main_pages/profile/user_data_provider.dart';
import 'package:community_impact_tracker/utils/addSpace.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/achievement.dart';
import '../../widgets/badge.dart';
import '../settings/settings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileController _controller = ProfileController();
  ImageProvider<Object>? _profileImage;
  String _username = "Loading...";
  bool _uploading = false;
  double _totalPoints = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeProfileData();
  }

  Future<void> _initializeProfileData() async {
    // Fetch initial data
    String username = await _controller.fetchUsername();
    double points = await _controller.fetchTotalPoints();
    ImageProvider<Object>? profileImage = await _controller.loadProfileImage();

    // Update state with fetched data
    setState(() {
      _username = username;
      _totalPoints = points;
      _profileImage = profileImage;
    });
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
                _updateProfilePicture();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateProfilePicture() async {
    setState(() {
      _uploading = true;
    });

    try {
      bool success = await _controller.pickImage(context);
      if (success) {
        ImageProvider<Object>? newImage = await _controller.loadProfileImage();
        setState(() {
          _profileImage = newImage;
        });
      }
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              bool? shouldRefresh = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
              if (shouldRefresh == true) {
                String username = await _controller.fetchUsername();
                setState(() {
                  _username = username;
                });
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
                            ? const Icon(Icons.person_2_rounded,
                                size: 70, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        width: 25,
                        height: 25,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cameraswitch_rounded,
                            size: 15,
                          ),
                        ),
                      ),
                      if (_uploading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
              const Vspace(10),
              Center(
                child: Text(
                  _username,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const Vspace(10),
              // User level and wallet balance
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.keyboard_double_arrow_up_rounded,
                            color: Colors.green, size: 30),
                        Text(
                          "Level ${getUserLevel(_totalPoints.toInt())}",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Vspace(5),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _controller.fetchWalletBalance(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        if (!snapshot.hasData ||
                            snapshot.data == null ||
                            !snapshot.data!.exists) {
                          return const Text("Wallet Balance: 0.00",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold));
                        }

                        double walletBalance =
                            (snapshot.data!.get('wallet_balance') ?? 0.0)
                                .toDouble();

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded,
                                size: 30),
                            Text(
                                "Wallet Balance: ${walletBalance.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Vspace(30),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    String? userId = _controller.getCurrentUserId();
                    if (userId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyEventsArchive(userId: userId),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.event_note),
                  label: const Text("My Events Archive"),
                ),
              ),
              const Vspace(30),

              // Badges section
              const Text("Badges",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Vspace(10),
              SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8.0,
                    children: const <Widget>[
                      BadgeWidget(badgeName: "Community Star"),
                      BadgeWidget(badgeName: "Volunteer Leader"),
                      BadgeWidget(badgeName: "Helping Hand"),
                      BadgeWidget(badgeName: "Feedback Giver"),
                    ],
                  ),
                ),
              ),

              const Vspace(10),

              // Achievements section
              const Text("Achievements",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Vspace(10),
              SingleChildScrollView(
                child: Column(
                  children: const [
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
