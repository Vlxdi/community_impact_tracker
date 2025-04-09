import 'dart:ui';

import 'package:flutter/material.dart';

Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'soon':
      return Colors.grey[300]!;
    case 'awaiting':
      return Colors.blue;
    case 'active':
      return Colors.green;
    case 'ended':
      return Colors.orange;
    case 'overdue':
      return Colors.red;
    case 'absent':
    case 'participated':
      return Colors.grey[800]!;
    default:
      return Colors.transparent;
  }
}
