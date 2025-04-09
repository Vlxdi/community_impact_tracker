import 'package:community_impact_tracker/outer_pages/admin_utils/locationUtils.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapSelector extends StatelessWidget {
  final LatLng? selectedLocation;
  final Set<Marker> markers;
  final Function(GoogleMapController) onMapCreated;
  final Function(LatLng) onLocationSelected;

  const MapSelector({
    Key? key,
    required this.selectedLocation,
    required this.markers,
    required this.onMapCreated,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LocationUtils.buildMapSelector(
      context: context,
      selectedLocation: selectedLocation,
      markers: markers,
      onMapCreated: onMapCreated,
      onLocationSelected: onLocationSelected,
    );
  }
}
