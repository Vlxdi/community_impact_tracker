String? validateMaxParticipants(String? value) {
  if (value == null || value.isEmpty) {
    return 'Cannot be empty';
  }

  int? parsedValue = int.tryParse(value);
  if (parsedValue == null) {
    return 'Invalid number';
  }

  if (parsedValue < 1) {
    return 'Min 1';
  }

  if (parsedValue > 500) {
    return 'Max 500';
  }

  return null;
}
