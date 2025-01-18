import 'dart:ui';

import 'package:community_impact_tracker/utils/AddSpace.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventCard extends StatelessWidget {
  final String name;
  final String description;
  final String? image;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdDate;
  // final GeoPoint location;
  final int rewardPoints;
  final String status;
  final VoidCallback onSignIn;

  const EventCard({
    super.key,
    required this.name,
    required this.description,
    this.image,
    required this.startTime,
    required this.endTime,
    required this.createdDate,
    //required this.location,
    required this.rewardPoints,
    required this.status,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side: Map, title, and description (70% or 75%)
          Flexible(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : "Event Name",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Vspace(4),
                Text(
                  description.isNotEmpty
                      ? description
                      : "No description provided",
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.fade,
                ),
                Vspace(8),
                //Add Google maps API
                Container(
                  height: 170,
                  color: Colors.grey[300],
                  child: Center(child: Text("Map here")),
                ),
              ],
            ),
          ),
          // Vertical separator line
          Container(
            width: 2,
            height: 260,
            color: Colors.grey[300],
            margin: EdgeInsets.symmetric(horizontal: 12),
          ),
          // Right side: Event details (30% or 25%)
          Flexible(
            flex: 3,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Unactive",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                // Event details below the status container
                Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Starts: ${formatDate(startTime)}"),
                      Text("Ends: ${formatDate(endTime)}"),
                      Text("Reward: $rewardPoints⭐"),
                      Vspace(8),
                      ElevatedButton(
                        onPressed: () {
                          // Call the dialog method here
                          _showEventSignUpDialog(context);
                        }, // Replacing action with "Sign Up"
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(
                              horizontal: 15,
                            )),
                        child: Text(
                          "Sign Up",
                          style: TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(DateTime date) {
    return DateFormat('d MMM yyyy, hh:mm a').format(date);
  }

  // Sign in information dialog
  void _showEventSignUpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            padding: EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image != null && image!.isNotEmpty)
                    Container(
                      height: 200,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          image!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                    ),
                  Vspace(16),

                  // Event Title
                  Text(
                    name.isNotEmpty ? name : "Event Name",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Vspace(8),

                  // Event Description
                  Text(
                    description.isNotEmpty
                        ? description
                        : "No description provided",
                    style: TextStyle(fontSize: 16),
                  ),
                  Vspace(16),

                  // Event Date & Location
                  Text(
                    'Created on: ${formatDate(createdDate)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Vspace(4),
                  Text(
                    'Location: Community Hall, Downtown',
                    style: TextStyle(fontSize: 16),
                  ),
                  Vspace(20),

                  // Sign-Up Button
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // Add sign-up logic here
                        // Retrieves data from user's account resistration
                        Navigator.of(context).pop(); // Close dialog on click
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      ),
                      child: Text(
                        "Sign Up",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
