import 'package:geolocator/geolocator.dart';

void applySorting(List<Map<String, dynamic>> eventsList, String selectedSort,
    Position? userLocation) {
  if (selectedSort == 'most_recent') {
    eventsList.sort((a, b) => b['createdDate'].compareTo(a['createdDate']));
  } else if (selectedSort == 'most_points') {
    eventsList.sort((a, b) => b['rewardPoints'].compareTo(a['rewardPoints']));
  } else if (selectedSort == 'near_me' && userLocation != null) {
    eventsList.sort((a, b) {
      double distanceA = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        a['latitude'],
        a['longitude'],
      );
      double distanceB = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        b['latitude'],
        b['longitude'],
      );
      return distanceA.compareTo(distanceB);
    });
  } else if (selectedSort == 'starting_soon') {
    eventsList.sort((a, b) => a['startTime'].compareTo(b['startTime']));
  } else if (selectedSort == 'duration') {
    eventsList.sort((a, b) {
      Duration durationA = a['endTime'].difference(a['startTime']);
      Duration durationB = b['endTime'].difference(b['startTime']);
      return durationB.compareTo(durationA);
    });
  } else if (selectedSort == 'most_participants') {
    eventsList
        .sort((a, b) => b['maxParticipants'].compareTo(a['maxParticipants']));
  }
}

List<Map<String, dynamic>> applyFilter(
  List<Map<String, dynamic>> events,
  String selectedFilter,
  Position? userLocation,
  DateTime now,
) {
  int daysToMonday = (now.weekday == 7) ? 6 : now.weekday - 1;
  DateTime startOfWeek = now
      .subtract(Duration(days: daysToMonday))
      .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
  DateTime endOfWeek =
      startOfWeek.add(Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  DateTime startOfNextWeek = startOfWeek.add(Duration(days: 7));

  for (var event in events) {
    DateTime startTime = event['startTime'];
    if (startTime.isBefore(now) && event['status'] == 'upcoming') {
      event['status'] = 'ongoing';
    }
  }

  if (selectedFilter == 'ongoing') {
    return events.where((event) {
      DateTime startTime = event['startTime'];
      DateTime endTime = event['endTime'];
      String status = event['status'];

      bool isActionable = (status == 'soon' ||
          status == 'active' ||
          status == 'awaiting' ||
          status == 'ended' ||
          status == 'overdue' ||
          status == 'pending');
      bool isWithinThisWeek = (startTime.isAfter(startOfWeek) ||
              startTime.isAtSameMomentAs(startOfWeek)) &&
          (endTime.isBefore(endOfWeek) || endTime.isAtSameMomentAs(endOfWeek));

      return isActionable && isWithinThisWeek;
    }).toList();
  } else if (selectedFilter == 'recently ended') {
    return events.where((event) {
      DateTime endTime = event['endTime'];
      String status = event['status'];

      bool isEndedAndStatusValid =
          (endTime.isBefore(now) || endTime.isAtSameMomentAs(now)) &&
              (status == 'participated' || status == 'absent');

      return isEndedAndStatusValid;
    }).toList();
  } else if (selectedFilter == 'upcoming') {
    return events.where((event) {
      DateTime startTime = event['startTime'];
      return startTime.isAfter(startOfNextWeek);
    }).toList();
  } else {
    return List.from(events);
  }
}
