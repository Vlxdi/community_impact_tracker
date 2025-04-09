import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationUtils {
  static Future<LatLng> getCurrentLocation(BuildContext context) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LatLng(0, 0);
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location permissions are permanently denied. Please enable them in settings.'),
            duration: Duration(seconds: 3),
          ),
        );
        return const LatLng(0, 0);
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        return LatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
    return const LatLng(0, 0);
  }

  static Set<Marker> createMarker(LatLng position, Function(LatLng) onDragEnd) {
    return {
      Marker(
        markerId: const MarkerId('selected_location'),
        position: position,
        draggable: true,
        onDragEnd: (newPosition) => onDragEnd(newPosition),
      ),
    };
  }

  static Widget buildMapSelector({
    required BuildContext context,
    required LatLng? selectedLocation,
    required Set<Marker> markers,
    required Function(GoogleMapController) onMapCreated,
    required Function(LatLng) onLocationSelected,
  }) {
    return SizedBox(
      width: MediaQuery.of(context).size.width - 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Event Location",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: selectedLocation == null
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      onMapCreated: onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: selectedLocation,
                        zoom: 15,
                      ),
                      markers: markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      onTap: onLocationSelected,
                    ),
            ),
          ),
          if (selectedLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Selected: ${selectedLocation.latitude.toStringAsFixed(6)}, ${selectedLocation.longitude.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }
}
