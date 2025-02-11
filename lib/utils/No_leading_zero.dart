import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If the new input starts with '0' and is not empty, revert to the old value
    if (newValue.text.startsWith('0') && newValue.text.length > 0) {
      return oldValue;
    }
    return newValue;
  }
}
