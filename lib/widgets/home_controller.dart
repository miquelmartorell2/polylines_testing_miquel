import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:polylines_testing/utils/map_style.dart';

class HomeController {
  void onMapCreated(GoogleMapController controller){
    controller.setMapStyle(mapStyle);
  }
}