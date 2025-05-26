import 'dart:ui';

import 'package:flutter/material.dart';

Widget buildListTile({
  required IconData icon,
  required String title,
  required bool isSelected,
  required VoidCallback onTap,
  bool isTop = false,
  Color selectedColor =
      Colors.blue, // Kept for compatibility, but not used for gradient
  Color color = Colors.white60, // New parameter for gradient's first color
}) {
  return ClipRRect(
    borderRadius: BorderRadius.only(
      topLeft: isTop ? Radius.circular(20) : Radius.zero,
      topRight: isTop ? Radius.circular(20) : Radius.zero,
    ),
    child: Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue,
                  const Color.fromARGB(170, 33, 149, 243),
                  const Color.fromARGB(130, 33, 149, 243),
                  const Color.fromARGB(100, 33, 149, 243),
                  const Color.fromARGB(50, 33, 149, 243),
                  const Color.fromARGB(30, 33, 149, 243),
                  const Color.fromARGB(10, 33, 149, 243),
                  Colors.white10
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomCenter,
                colors: [color, Colors.white10],
              ),
        color: null, // Always null, since gradient is always used
        borderRadius: BorderRadius.only(
          topLeft: isTop ? Radius.circular(20) : Radius.zero,
          topRight: isTop ? Radius.circular(20) : Radius.zero,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(title),
        onTap: onTap,
      ),
    ),
  );
}
