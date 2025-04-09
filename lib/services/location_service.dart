import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services are disabled.");
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("Location permissions are denied.");
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("Location permissions are permanently denied.");
        return null;
      }

      Position userLocation = await Geolocator.getCurrentPosition();
      print(
          "User location fetched: ${userLocation.latitude}, ${userLocation.longitude}");
      return userLocation;
    } catch (e) {
      print("Error fetching user location: $e");
      return null;
    }
  }
}
