import 'dart:ui';
import 'dart:ui' as ui;

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

class CustomShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
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
    double points = await _controller.fetchTotalPoints();
    ImageProvider<Object>? profileImage = await _controller.loadProfileImage();
    String username = await _controller.fetchUsername(); // Fetch username

    // Update state with fetched data
    setState(() {
      _totalPoints = points;
      _profileImage = profileImage;
      _username = username; // Set the username
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
      barrierColor: Colors.transparent, // Make the barrier transparent
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3), // Shadow color
                      blurRadius: 30,
                      spreadRadius: 15,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white60, Colors.white10],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color.fromARGB(80, 124, 124, 124),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Change picture?",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Vspace(16),
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
                            "Do you want to change your profile picture or leave it as is?",
                            textAlign: TextAlign.center,
                          ),
                          Vspace(16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  backgroundColor: Colors.transparent,
                                  side: const BorderSide(color: Colors.black26),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text("Cancel"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.swap_horiz),
                                    onPressed: () async {
                                      bool newSuccess =
                                          await _controller.pickImage(context,
                                              previewMode: true);
                                      if (newSuccess) {
                                        ImageProvider<Object>? newPreviewImage =
                                            await _controller
                                                .loadPreviewImage();
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
                                  IconButton(
                                    icon: const Icon(Icons.crop),
                                    onPressed: () async {
                                      bool newSuccess =
                                          await _controller.cropPreviewImage();
                                      if (newSuccess) {
                                        ImageProvider<Object>? newPreviewImage =
                                            await _controller
                                                .loadPreviewImage();
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
                                ],
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black,
                                  backgroundColor:
                                      const Color.fromARGB(125, 33, 149, 243),
                                  side: const BorderSide(color: Colors.black26),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text("Change"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _updateProfilePicture();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                ClipPath(
                  clipper: CustomShapeClipper(),
                  child: Container(
                    height: 350, // Adjust height as needed
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Color(0xFF71CD8C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              GestureDetector(
                                onTap: _showProfilePictureDialog,
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundImage: _profileImage,
                                  child: _profileImage == null
                                      ? const Icon(Icons.person_2_rounded,
                                          size: 70, color: Colors.grey)
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                width: 30,
                                height: 30,
                                child: GestureDetector(
                                  onTap: _showProfilePictureDialog,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 5, sigmaY: 5),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.white60,
                                              Colors.white10
                                            ],
                                          ),
                                          border: Border.all(
                                            color: const Color.fromARGB(
                                                80, 124, 124, 124),
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        child: const Icon(
                                          Icons.cameraswitch_rounded,
                                          size: 16,
                                          color: Color.fromARGB(255, 0, 0, 0),
                                        ),
                                      ),
                                    ),
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
                        const SizedBox(height: 10),
                        StreamBuilder<String>(
                          stream: _controller.usernameStream(),
                          builder: (context, snapshot) {
                            String username = snapshot.data ?? _username;
                            return Text(
                              username,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
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
                                  border: Border.all(
                                    color:
                                        const Color.fromARGB(80, 124, 124, 124),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color.fromARGB(213, 113, 205, 141),
                                      Color.fromARGB(255, 48, 172, 85)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                        Icons.keyboard_double_arrow_up_rounded,
                                        color: Colors.white,
                                        size: 40),
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
                                  border: Border.all(
                                    color:
                                        const Color.fromARGB(80, 124, 124, 124),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.blue,
                                      Color.fromARGB(255, 162, 221, 255)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
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
                                        (snapshot.data!.get('wallet_balance') ??
                                                0.0)
                                            .toDouble();

                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                            Icons
                                                .account_balance_wallet_rounded,
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
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // My Events Archive Button (styled like favorites/cart)
                    Container(
                      margin:
                          EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white60, Colors.white10],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color.fromARGB(80, 124, 124, 124),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GestureDetector(
                          onTap: () async {
                            if (_isNavigating) return;
                            _isNavigating = true;

                            _myEventsAnimationController.forward(from: 0.3);
                            await Future.delayed(
                                const Duration(milliseconds: 500));
                            String? userId = _controller.getCurrentUserId();
                            if (userId != null && mounted) {
                              await Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      MyEventsArchive(userId: userId),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    const begin = Offset(-1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeInOut;

                                    var tween = Tween(begin: begin, end: end)
                                        .chain(CurveTween(curve: curve));
                                    var offsetAnimation =
                                        animation.drive(tween);

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
                          child: Transform.scale(
                            scale: 0.75, // was 0.75, now smaller
                            alignment: Alignment(0.0, -0.3),
                            child: Lottie.asset(
                              'assets/animations/appbar_icons/my_events_archive.json',
                              controller: _myEventsAnimationController,
                              onLoaded: (composition) {
                                _myEventsAnimationController.duration =
                                    composition.duration;
                              },
                              repeat: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Settings Button (styled like favorites/cart)
                    Container(
                      margin:
                          EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white60, Colors.white10],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color.fromARGB(80, 124, 124, 124),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GestureDetector(
                          onTap: () async {
                            if (_isNavigating) return;
                            _isNavigating = true;

                            _settingsAnimationController.forward(from: 0);
                            await Future.delayed(
                                const Duration(milliseconds: 500));
                            bool? shouldRefresh = await Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        SettingsPage(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
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
                              String username =
                                  await _controller.fetchUsername();
                              setState(() {
                                _username = username;
                              });
                            }

                            _isNavigating = false;
                          },
                          child: Transform.scale(
                            scale: 0.6, // was 0.75, now smaller
                            child: Lottie.asset(
                              'assets/animations/appbar_icons/settings.json',
                              controller: _settingsAnimationController,
                              onLoaded: (composition) {
                                _settingsAnimationController.duration =
                                    composition.duration;
                              },
                              repeat: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        AchievementWidget(
                            achievementName: "Completed 5 Events"),
                        AchievementWidget(
                            achievementName: "100 Hours of Service"),
                        AchievementWidget(
                            achievementName: "Top Volunteer in March"),
                        AchievementWidget(
                            achievementName: "Most points in one week"),
                        AchievementWidget(
                            achievementName:
                                "Thrifty: No money spent last month"),
                        AchievementWidget(
                            achievementName:
                                "Thrifty: No money spent last month"),
                        AchievementWidget(
                            achievementName:
                                "Thrifty: No money spent last month"),
                        AchievementWidget(
                            achievementName:
                                "Thrifty: No money spent last month"),
                        AchievementWidget(
                            achievementName:
                                "Thrifty: No money spent last month"),
                      ],
                    ),
                  ),
                  Vspace(20), // Add extra space at the bottom
                  Center(
                    child: Text("No more achievemnts 🕸"),
                  ),
                  Vspace(80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
