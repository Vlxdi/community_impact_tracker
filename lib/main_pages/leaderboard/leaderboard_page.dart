import 'package:community_impact_tracker/utils/addSpace.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardPage extends StatefulWidget {
  @override
  _LeaderboardPageState createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  String searchQuery = '';
  String sortBy = 'level'; // Default sorting by level

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Leaderboard'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16.0), // Equal padding on both sides
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40, // Shorter height
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(30), // Circular shape
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search for users...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.white, // White background
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style:
                          TextStyle(fontSize: 13), // Slightly smaller text size
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () {
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
                                _buildListTile(
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
                                _buildListTile(
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
                      padding: EdgeInsets.all(6),
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
                      child: Icon(
                        Icons.tune,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Vspace(16),
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

                final leaderboardData = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'username': data['username'] ?? 'Unknown',
                    'wallet_balance': data['wallet_balance'] ?? 0,
                    'profile_picture': data['profile_picture'],
                    'location': data['location'],
                    'level': data['level'] ?? 0,
                  };
                }).where((entry) {
                  return entry['username']
                      .toLowerCase()
                      .contains(searchQuery); // Filter by search query
                }).toList();

                leaderboardData.sort((a, b) {
                  if (sortBy == 'level') {
                    return b['level'].compareTo(a['level']); // Sort by level
                  } else {
                    return b['wallet_balance']
                        .compareTo(a['wallet_balance']); // Sort by points
                  }
                });

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
                            Text('${index + 1}',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            CircleAvatar(
                              backgroundImage: entry['profile_picture'] != null
                                  ? NetworkImage(entry['profile_picture'])
                                  : null,
                              child: entry['profile_picture'] == null
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

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    bool isTop = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[100] : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: isTop ? Radius.circular(20) : Radius.zero,
          topRight: isTop ? Radius.circular(20) : Radius.zero,
        ),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}
