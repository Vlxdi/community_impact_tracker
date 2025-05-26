import 'dart:ui';

import 'package:community_impact_tracker/utils/addSpace.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:community_impact_tracker/widgets/build_list_tile.dart';

class LeaderboardPage extends StatefulWidget {
  @override
  _LeaderboardPageState createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with TickerProviderStateMixin {
  String searchQuery = '';
  String sortBy = 'level';
  late AnimationController _filterController;
  AnimationController? _searchAnimationController; // Add for search icon
  final FocusNode _searchFocusNode = FocusNode(); // Add for search bar focus
  String? currentUserLocation;

  @override
  void initState() {
    super.initState();
    _filterController = AnimationController(vsync: this);
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 800), // Default, will be updated by Lottie
    );
    _searchFocusNode.addListener(_onSearchFocusChange);
    _fetchCurrentUserLocation();
  }

  void _onSearchFocusChange() {
    if (_searchFocusNode.hasFocus) {
      if (_searchAnimationController != null) {
        _searchAnimationController!.forward(from: 0.25);
        _searchAnimationController!.repeat(min: 0.25);
      }
    } else {
      if (_searchAnimationController != null) {
        _searchAnimationController!.stop();
        _searchAnimationController!.reset();
      }
    }
  }

  Future<void> _fetchCurrentUserLocation() async {
    final currentUserId = FirebaseAuth
        .instance.currentUser?.uid; // Fetch the currently logged-in user's ID
    if (currentUserId == null) {
      return; // Handle the case where no user is logged in
    }
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    if (userDoc.exists) {
      setState(() {
        currentUserLocation = userDoc.data()?['location'];
      });
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    _searchAnimationController?.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Weekly Top 5 Section
          _buildWeeklyTopSection(),

          Container(
            height: 4,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 10,
                  offset: Offset(0, 0),
                ),
              ],
            ),
          ),

          Divider(thickness: 1, color: Colors.grey.withOpacity(0.3)),

          // --- REPLACED SEARCH BAR WITH ANIMATED VERSION ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white60, Colors.white10],
                          ),
                          border: Border.all(
                            color: const Color.fromARGB(80, 124, 124, 124),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          focusNode: _searchFocusNode,
                          autofocus: false,
                          onTap: () {
                            if (_searchAnimationController != null) {
                              _searchAnimationController!.forward(from: 0.25);
                              _searchAnimationController!.repeat(min: 0.25);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Search for users...',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 5.0),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Lottie.asset(
                                  'assets/animations/search.json',
                                  controller: _searchAnimationController,
                                  onLoaded: (composition) {
                                    if (_searchAnimationController != null) {
                                      _searchAnimationController!.duration =
                                          composition.duration;
                                      if (_searchFocusNode.hasFocus) {
                                        _searchAnimationController!
                                            .forward(from: 0.25);
                                        _searchAnimationController!
                                            .repeat(min: 0.25);
                                      }
                                    }
                                  },
                                  repeat: false,
                                ),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.2),
                            contentPadding: EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(fontSize: 14),
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value.toLowerCase();
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Hspace(16),
                GestureDetector(
                  onTap: () {
                    _filterController.reset();
                    _filterController.forward();
                    showModalBottomSheet(
                      context: context,
                      barrierColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) {
                        return Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 30,
                              child: Container(
                                decoration: const BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 20),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                          10, 124, 124, 124),
                                      border: Border.all(
                                        color: const Color.fromARGB(
                                            80, 124, 124, 124),
                                        width: 2,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        topRight: Radius.circular(20),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        buildListTile(
                                          icon: Icons.leaderboard,
                                          title: 'Sort by Level',
                                          isSelected: sortBy == 'level',
                                          onTap: () {
                                            setState(() {
                                              sortBy = 'level';
                                            });
                                            Navigator.pop(context);
                                          },
                                          isTop: true,
                                        ),
                                        buildListTile(
                                          icon: Icons.star,
                                          title: 'Sort by Points',
                                          isSelected: sortBy == 'points',
                                          onTap: () {
                                            setState(() {
                                              sortBy = 'points';
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                        buildListTile(
                                          icon: Icons.location_on,
                                          title: 'Local Users',
                                          isSelected: sortBy == 'location',
                                          onTap: () {
                                            setState(() {
                                              sortBy = 'location';
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.fromRGBO(255, 255, 255, 0.6),
                          Colors.white10
                        ],
                      ),
                      border: Border.all(
                        color: const Color.fromARGB(80, 124, 124, 124),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withOpacity(0.1), // Add light shadow
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Lottie.asset(
                        'assets/animations/appbar_icons/filter.json',
                        controller: _filterController,
                        onLoaded: (composition) {
                          _filterController.duration =
                              composition.duration * 0.5;
                        },
                        repeat: false,
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // --- END REPLACEMENT ---

          Vspace(16),
          // All-Time Leaderboard
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text('All Users',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
          ),
          Vspace(8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No data available'));
                }

                List<Map<String, dynamic>> fullData =
                    snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'username': data['username'] ?? 'Unknown',
                    'wallet_balance': data['wallet_balance'] ?? 0,
                    'profile_picture': data['profile_picture'],
                    'location': data['location'],
                    'level': data['level'] ?? 0,
                  };
                }).toList();

                fullData.sort((a, b) {
                  if (sortBy == 'level') {
                    return b['level'].compareTo(a['level']);
                  } else if (sortBy == 'points') {
                    return b['wallet_balance'].compareTo(a['wallet_balance']);
                  } else if (sortBy == 'location') {
                    return a['location']
                        .toString()
                        .compareTo(b['location'].toString());
                  }
                  return 0;
                });

                for (int i = 0; i < fullData.length; i++) {
                  fullData[i]['rank'] = i + 1;
                }

                final leaderboardData = fullData.where((entry) {
                  if (sortBy == 'location') {
                    return currentUserLocation != null &&
                        entry['location'] == currentUserLocation;
                  }
                  return entry['username'].toLowerCase().contains(searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: leaderboardData.length,
                  itemBuilder: (context, index) {
                    final entry = leaderboardData[index];
                    return Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Shadow beneath the card, spreading out and not clipped
                          Positioned.fill(
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    28), // slightly larger than card
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFF71CD8C), Colors.white30],
                                  ),
                                  border: Border.all(
                                    color:
                                        const Color.fromARGB(80, 124, 124, 124),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  // Remove boxShadow here to avoid double shadow
                                ),
                                child: ListTile(
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${entry['rank']}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      SizedBox(width: 8),
                                      CircleAvatar(
                                        backgroundImage:
                                            (entry['profile_picture'] != null &&
                                                    entry['profile_picture']
                                                        .toString()
                                                        .isNotEmpty)
                                                ? NetworkImage(
                                                    entry['profile_picture'])
                                                : null,
                                        child:
                                            (entry['profile_picture'] == null ||
                                                    entry['profile_picture']
                                                        .toString()
                                                        .isEmpty)
                                                ? Icon(Icons.person,
                                                    color: Colors.grey)
                                                : null,
                                      ),
                                    ],
                                  ),
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(entry['username'],
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                          '(${entry['location'] ?? 'Unknown'})',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // --- Level Container (mini style) with shadow ---
                                      Container(
                                        width: 54,
                                        height: 50,
                                        margin: EdgeInsets.only(right: 6),
                                        child: Stack(
                                          children: [
                                            // Shadow
                                            Positioned(
                                              left: 4,
                                              right: 4,
                                              bottom: 2,
                                              child: Container(
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.18),
                                                      blurRadius: 10,
                                                      spreadRadius: 1,
                                                      offset: Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Actual container
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color.fromARGB(
                                                        80, 124, 124, 124),
                                                    width: 1.2,
                                                  ),
                                                  gradient:
                                                      const LinearGradient(
                                                    colors: [
                                                      Color.fromARGB(
                                                          213, 113, 205, 141),
                                                      Color.fromARGB(
                                                          255, 48, 172, 85)
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .keyboard_double_arrow_up_rounded,
                                                        color: Colors.white,
                                                        size: 18),
                                                    Text(
                                                      "Lvl ${entry['level']}",
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // --- Points Container (mini style) with shadow ---
                                      Container(
                                        width: 54,
                                        height: 50,
                                        child: Stack(
                                          children: [
                                            // Shadow
                                            Positioned(
                                              left: 4,
                                              right: 4,
                                              bottom: 2,
                                              child: Container(
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.18),
                                                      blurRadius: 10,
                                                      spreadRadius: 1,
                                                      offset: Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Actual container
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color.fromARGB(
                                                        80, 124, 124, 124),
                                                    width: 1.2,
                                                  ),
                                                  gradient:
                                                      const LinearGradient(
                                                    colors: [
                                                      Colors.blue,
                                                      Color.fromARGB(
                                                          255, 162, 221, 255)
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                ),
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .account_balance_wallet_rounded,
                                                        size: 18,
                                                        color: Colors.white),
                                                    Text(
                                                      '${entry['wallet_balance']}',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTopSection() {
    // Get the start of the current week (Sunday)
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday % 7));
    final endOfWeek =
        startOfWeek.add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    final startTimestamp = Timestamp.fromDate(startOfWeek);
    final endTimestamp = Timestamp.fromDate(endOfWeek);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top This Week',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 180,
          child: StreamBuilder<QuerySnapshot>(
            // Query the user collection for weekly top users based on wallet_balance
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('wallet_balance', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No users found',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              // Get top 5 users
              final topUsers = snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'username': data['username'] ?? 'Unknown',
                  'wallet_balance': data['wallet_balance'] ?? 0,
                  'profile_picture': data['profile_picture'],
                  'location': data['location'],
                  'level': data['level'] ?? 0,
                };
              }).toList();

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 10),
                itemCount: topUsers.length,
                itemBuilder: (context, index) {
                  final user = topUsers[index];

                  // Colors for the medals
                  Color medalColor;
                  IconData medalIcon;

                  if (index == 0) {
                    medalColor =
                        const Color.fromARGB(255, 255, 199, 13); // Gold
                    medalIcon = Icons.emoji_events;
                  } else if (index == 1) {
                    medalColor =
                        const Color.fromARGB(255, 214, 214, 214); // Silver
                    medalIcon = Icons.emoji_events;
                  } else if (index == 2) {
                    medalColor =
                        const Color.fromARGB(255, 182, 124, 106); // Bronze
                    medalIcon = Icons.emoji_events;
                  } else {
                    medalColor = Colors.blue[100]!; // Other positions
                    medalIcon = Icons.stars;
                  }

                  // Gradient backgrounds for top 3 and blue for 4th/5th
                  Gradient? cardGradient;
                  if (index == 0) {
                    cardGradient = const LinearGradient(
                      colors: [
                        Color(0xFFFFE066), // bright yellow
                        Color(0x8FFFFFFF), // light
                        Color(0xFFFFE066), // bright yellow
                        Color(0xFFFFC300), // deep yellow
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    );
                  } else if (index == 1) {
                    cardGradient = const LinearGradient(
                      colors: [
                        Color(0xFFBDBDBD), // deep silver
                        Color(0x8FFFFFFF), // light
                        Color(0xFFE0E0E0), // light silver
                        Color(0xFFBDBDBD), // deep silver
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    );
                  } else if (index == 2) {
                    cardGradient = const LinearGradient(
                      colors: [
                        Color(0xFFD7B899), // light bronze
                        Color(0x8FFFFFFF), // light
                        Color(0xFFD7B899), // light bronze
                        Color(0xFFB97A56), // deep bronze
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    );
                  } else if (index == 3 || index == 4) {
                    cardGradient = LinearGradient(
                      colors: [
                        Color.fromARGB(143, 255, 255, 255),
                        const Color(0xFFBBDEFB),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    );
                  } else {
                    cardGradient = const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white60, Colors.white10],
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 120,
                          decoration: BoxDecoration(
                            gradient: cardGradient,
                            border: Border.all(
                              color: const Color.fromARGB(80, 124, 124, 124),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  // Add shadow behind the image
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.18),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 35,
                                      backgroundImage:
                                          (user['profile_picture'] != null &&
                                                  user['profile_picture']
                                                      .toString()
                                                      .isNotEmpty)
                                              ? NetworkImage(
                                                  user['profile_picture'])
                                              : null,
                                      child: (user['profile_picture'] == null ||
                                              user['profile_picture']
                                                  .toString()
                                                  .isEmpty)
                                          ? Icon(Icons.person,
                                              size: 35, color: Colors.grey)
                                          : null,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: medalColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${user['username']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.star,
                                      size: 16,
                                      color: Colors.amber,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.18),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ]),
                                  SizedBox(width: 4),
                                  Text(
                                    '${user['wallet_balance']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.18),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
