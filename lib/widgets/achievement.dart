import 'package:community_impact_tracker/utils/AddSpace.dart';
import 'package:flutter/material.dart';

class AchievementWidget extends StatelessWidget {
  final String achievementName;

  const AchievementWidget({super.key, required this.achievementName});

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
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(Icons.star, color: Colors.yellow),
          Hspace(10),
          Expanded(
            // Wrap the text in Expanded
            child: Text(
              achievementName,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
