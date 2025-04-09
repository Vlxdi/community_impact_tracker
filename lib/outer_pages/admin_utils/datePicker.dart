import 'package:flutter/material.dart';

class DatePickerUtils {
  static Future<DateTime?> pickStartDateTime(
    BuildContext context,
    DateTime? startDate,
    TimeOfDay? startTime,
  ) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: startTime ?? TimeOfDay.now(),
      );

      if (pickedTime != null) {
        return DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      }
    }
    return null;
  }

  static Future<DateTime?> pickEndDateTime(
    BuildContext context,
    DateTime? startDate,
    TimeOfDay? startTime,
    DateTime? endDate,
    TimeOfDay? endTime,
  ) async {
    if (startDate == null || startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select the start date and time first.")),
      );
      return null;
    }

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: endDate ?? startDate.add(Duration(days: 1)),
      firstDate: startDate,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: endTime ?? TimeOfDay.now(),
      );

      if (pickedTime != null) {
        DateTime selectedEndDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        DateTime selectedStartDateTime = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          startTime.hour,
          startTime.minute,
        );

        if (selectedEndDateTime.isBefore(selectedStartDateTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("End time cannot be before the start time."),
            ),
          );
          return null;
        } else if (selectedEndDateTime
            .isAtSameMomentAs(selectedStartDateTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("End time cannot be the same as the start time."),
            ),
          );
          return null;
        }
        return selectedEndDateTime;
      }
    }
    return null;
  }

  static TimeOfDay getTimeOfDayFromDateTime(DateTime dateTime) {
    return TimeOfDay.fromDateTime(dateTime);
  }
}
