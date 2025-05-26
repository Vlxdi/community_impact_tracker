import 'dart:ui';
import 'package:flutter/material.dart';

// Returns a LinearGradient for each status, or null for transparent/default.
LinearGradient? getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'soon':
      return LinearGradient(
        colors: [Colors.grey[300]!, Colors.grey[400]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case 'awaiting':
      return LinearGradient(
        colors: [Colors.blue[300]!, Colors.blue[700]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case 'active':
      return LinearGradient(
        colors: [
          Color.fromARGB(213, 113, 205, 141), // #71CD8C with alpha
          Color(0xFF71CD8C)
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case 'ended':
      return LinearGradient(
        colors: [Colors.orange[300]!, Colors.orange[700]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case 'overdue':
      return LinearGradient(
        colors: [Colors.red[300]!, Colors.red[700]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    case 'absent':
    case 'participated':
      return LinearGradient(
        colors: [Colors.grey[700]!, Colors.grey[900]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    default:
      return null;
  }
}
