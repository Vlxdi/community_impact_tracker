import 'package:flutter/material.dart';

Widget buildListTile({
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
