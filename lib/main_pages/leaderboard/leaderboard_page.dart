import 'package:community_impact_tracker/utils/addSpace.dart';
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
    with SingleTickerProviderStateMixin {
  String searchQuery = '';
  String sortBy = 'level';
  late AnimationController _filterController;

  @override
  void initState() {
    super.initState();
    _filterController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: Text('Leaderboard'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Weekly Top 5 Section
          _buildWeeklyTopSection(),

          Divider(thickness: 1, color: Colors.grey.withOpacity(0.3)),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search for users...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(fontSize: 13),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(
                    width:
                        16), // Adjusted spacing between search and filter button
                GestureDetector(
                  onTap: () {
                    _filterController.reset();
                    _filterController.forward();
                    showModalBottomSheet(
                      barrierColor: Colors.black.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      context: context,
                      builder: (context) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
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
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    width: 32, // Smaller button size
                    height: 32, // Smaller button size
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Lottie.asset(
                        'assets/animations/appbar_icons/filter.json',
                        controller: _filterController,
                        onLoaded: (composition) {
                          _filterController.duration =
                              composition.duration * 0.5; // Faster
                        },
                        repeat: false,
                        width: 20, // Adjusted icon size for smaller button
                        height: 20, // Adjusted icon size for smaller button
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                  } else {
                    return b['wallet_balance'].compareTo(a['wallet_balance']);
                  }
                });

                for (int i = 0; i < fullData.length; i++) {
                  fullData[i]['rank'] = i + 1;
                }

                final leaderboardData = fullData.where((entry) {
                  return entry['username'].toLowerCase().contains(searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: leaderboardData.length,
                  itemBuilder: (context, index) {
                    final entry = leaderboardData[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${entry['rank']}',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            CircleAvatar(
                              backgroundImage:
                                  (entry['profile_picture'] != null &&
                                          entry['profile_picture']
                                              .toString()
                                              .isNotEmpty)
                                      ? NetworkImage(entry['profile_picture'])
                                      : null,
                              child: (entry['profile_picture'] == null ||
                                      entry['profile_picture']
                                          .toString()
                                          .isEmpty)
                                  ? Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                          ],
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry['username'],
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('(${entry['location'] ?? 'Unknown'})',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_double_arrow_up_rounded,
                                color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text('Lvl ${entry['level']}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)),
                            SizedBox(width: 8),
                            Text('${entry['wallet_balance']} ⭐',
                                style: TextStyle(color: Colors.green)),
                          ],
                        ),
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
                        const Color.fromARGB(255, 214, 214, 214)!; // Silver
                    medalIcon = Icons.emoji_events;
                  } else if (index == 2) {
                    medalColor =
                        const Color.fromARGB(255, 182, 124, 106)!; // Bronze
                    medalIcon = Icons.emoji_events;
                  } else {
                    medalColor = Colors.blue[100]!; // Other positions
                    medalIcon = Icons.stars;
                  }

                  return Container(
                    width: 120,
                    margin: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
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
                            CircleAvatar(
                              radius: 35,
                              backgroundImage:
                                  (user['profile_picture'] != null &&
                                          user['profile_picture']
                                              .toString()
                                              .isNotEmpty)
                                      ? NetworkImage(user['profile_picture'])
                                      : null,
                              child: (user['profile_picture'] == null ||
                                      user['profile_picture']
                                          .toString()
                                          .isEmpty)
                                  ? Icon(Icons.person,
                                      size: 35, color: Colors.grey)
                                  : null,
                            ),
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: medalColor,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
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
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              '${user['wallet_balance']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
    );
  }
}
