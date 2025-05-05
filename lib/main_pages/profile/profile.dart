import 'package:community_impact_tracker/main.dart';
import 'package:community_impact_tracker/main_pages/profile/my_events_archive.dart';
import 'package:community_impact_tracker/main_pages/profile/user_data_provider.dart';
import 'package:community_impact_tracker/utils/addSpace.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import '../../widgets/achievement.dart';
import '../../widgets/badge.dart';
import '../settings/settings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  final ProfileController _controller = ProfileController();
  ImageProvider<Object>? _profileImage;
  String _username = "Loading...";
  bool _uploading = false;
  double _totalPoints = 0.0;
  late AnimationController _settingsAnimationController;
  late AnimationController _myEventsAnimationController; // Add this
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _settingsAnimationController = AnimationController(vsync: this);
    _myEventsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Set a duration for the animation
    ); // Remove the repeat call to prevent auto-play
    _initializeProfileData();
  }

  @override
  void dispose() {
    _settingsAnimationController.dispose();
    _myEventsAnimationController.dispose(); // Dispose the new controller
    super.dispose();
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

  void _showProfilePictureDialog() async {
    ImageProvider<Object>? previewImage =
        _profileImage; // Default to current profile image

    // Allow user to pick an image for preview
    bool success = await _controller.pickImage(context, previewMode: true);
    if (success) {
      previewImage = await _controller.loadPreviewImage();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Center(child: Text("Change picture?")),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (previewImage != null)
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: previewImage,
                      child: previewImage == null
                          ? const Icon(Icons.person_2_rounded,
                              size: 70, color: Colors.grey)
                          : null,
                    ),
                  Vspace(10),
                  Text(
                    _username,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Vspace(10),
                  const Text(
                      "Do you want to change your profile picture or leave it as is?"),
                ],
              ),
              actions: [
                Row(
                  spacing: 2,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: () async {
                        bool newSuccess = await _controller.pickImage(context,
                            previewMode: true);
                        if (newSuccess) {
                          ImageProvider<Object>? newPreviewImage =
                              await _controller.loadPreviewImage();
                          setState(() {
                            previewImage = newPreviewImage;
                          });
                        } else {
                          setState(() {
                            previewImage =
                                _profileImage; // Reset to current profile image
                          });
                        }
                      },
                    ),
                    //add an icon button to crop the image
                    IconButton(
                      icon: const Icon(Icons.crop),
                      onPressed: () async {
                        bool newSuccess = await _controller.cropPreviewImage();
                        if (newSuccess) {
                          ImageProvider<Object>? newPreviewImage =
                              await _controller.loadPreviewImage();
                          setState(() {
                            previewImage = newPreviewImage;
                          });
                        } else {
                          setState(() {
                            previewImage = _profileImage;
                          });
                        }
                      },
                    ),

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
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateProfilePicture() async {
    setState(() {
      _uploading = true;
    });

    try {
      // Finalize the image upload
      bool success = await _controller.finalizeImageUpload(context);
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
      extendBodyBehindAppBar: true,
      appBar: TransparentAppBar(
        title: const Text("Profile"),
        leading: IconButton(
          icon: SizedBox(
            width: 30,
            height: 30,
            child: Lottie.asset(
              'assets/animations/appbar_icons/my_events_archive.json',
              controller: _myEventsAnimationController,
              onLoaded: (composition) {
                _myEventsAnimationController.duration = composition.duration;
              },
              repeat: false,
            ),
          ),
          onPressed: () async {
            if (_isNavigating) return;
            _isNavigating = true;

            _myEventsAnimationController.reset();
            _myEventsAnimationController.forward(from: 0.2);
            await Future.delayed(const Duration(milliseconds: 500));
            String? userId = _controller.getCurrentUserId();
            if (userId != null && mounted) {
              await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      MyEventsArchive(userId: userId),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    const begin = Offset(-1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;

                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);

                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              );
            }
            _isNavigating = false;
          },
        ),
        actions: [
          IconButton(
            icon: SizedBox(
              width: 24,
              height: 24,
              child: Lottie.asset(
                'assets/animations/appbar_icons/settings.json',
                controller: _settingsAnimationController,
                onLoaded: (composition) {
                  _settingsAnimationController.duration = composition.duration;
                },
              ),
            ),
            onPressed: () async {
              if (_isNavigating) return;
              _isNavigating = true;

              _settingsAnimationController.forward(from: 0);
              await Future.delayed(const Duration(milliseconds: 500));
              bool? shouldRefresh = await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      SettingsPage(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;

                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);

                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              );
              if (shouldRefresh == true) {
                String username = await _controller.fetchUsername();
                setState(() {
                  _username = username;
                });
              }

              _isNavigating = false;
            },
          ),
        ],
      ),
      body: Container(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: kToolbarHeight + 16),
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
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.green,
                                Color.fromARGB(20, 50, 180, 50)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.green,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.keyboard_double_arrow_up_rounded,
                                  color: Colors.white, size: 40),
                              Text(
                                "Level ${getUserLevel(_totalPoints.toInt())}",
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.lightBlue,
                                Color.fromARGB(20, 50, 180, 255)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.blue,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: _controller.fetchWalletBalance(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data == null ||
                                  !snapshot.data!.exists) {
                                return const Center(
                                  child: Text(
                                    "0.00",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                );
                              }

                              double walletBalance =
                                  (snapshot.data!.get('wallet_balance') ?? 0.0)
                                      .toDouble();

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 40,
                                      color: Colors.white),
                                  Text(
                                    walletBalance.toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Vspace(30),
                const Text("Badges",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                const Text("Achievements",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Vspace(10),
                SingleChildScrollView(
                  child: Column(
                    children: const [
                      AchievementWidget(achievementName: "Completed 5 Events"),
                      AchievementWidget(
                          achievementName: "100 Hours of Service"),
                      AchievementWidget(
                          achievementName: "Top Volunteer in March"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
