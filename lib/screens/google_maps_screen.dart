import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:polylines_testing/provider/provider.dart';
import 'package:polylines_testing/screens/home_screen.dart';
import 'package:polylines_testing/widgets/home_controller.dart';
import 'package:provider/provider.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  var tempRuta;

  final _controller = HomeController();
  
  GoogleMapController? mapController;
  LocationData? currentLocation;
  Location location = Location();
  StreamSubscription<LocationData>? locationSubscription;
  List<LatLng> rutaPuntos = [];
  Map<String, Marker> markers = {};

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    super.dispose();
  }

  void initPlatformState() async {
    try {
      var _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          return;
        }
      }

      var _permissionGranted = await location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          return;
        }
      }

      locationSubscription = location.onLocationChanged.listen((LocationData currentLocation) {
        setState(() {
          this.currentLocation = currentLocation;
          _updateCameraToCurrentLocation();
          print(currentLocation);
          print(tempRuta.posicions[0]);
        });
      });

      currentLocation = await location.getLocation();
      _updateCameraToCurrentLocation();
      
      // Construir rutaPuntos con los datos de tempUser.posicions
      for (String position in tempRuta.posicions) {
        List<String> components = position.split(','); // Dividir la cadena en sus componentes
        double lat = double.parse(components[0].trim()); // Obtener la latitud
        double lng = double.parse(components[1].trim()); // Obtener la longitud
        rutaPuntos.add(LatLng(lat, lng)); // Agregar el objeto LatLng a la lista
      }

      // Llamar a la función para pintar la ruta
      await _fetchAndSetPolyline();
    } catch (e) {
      print(e);
    }
  }

  void _updateCameraToCurrentLocation() {
    if (currentLocation != null && mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(
          LatLng(currentLocation!.latitude!, currentLocation!.longitude!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rutaForm = Provider.of<RutasService>(context, listen: false);
    tempRuta = rutaForm.tempRuta;

    return Scaffold(
      body: GoogleMap(
        onMapCreated: _controller.onMapCreated,
        markers: Set<Marker>.of(markers.values),
        initialCameraPosition: CameraPosition(
          target: LatLng(39.725024, 2.905675), // Centro del primer punto de ruta
          zoom: 14.0, // Ajusta el zoom según sea necesario
        ),
        polylines: {
          Polyline(
            polylineId: PolylineId('ruta'),
            color: Colors.blue,
            points: rutaPuntos,
          ),
        },
      ),
    );
  }

  Future<void> _fetchAndSetPolyline() async {
    markers.clear();
    List<LatLng> allRoutePoints = [];

    for (int i = 0; i < rutaPuntos.length - 1; i++) {
      final directionsResponse = await http.get(
        Uri.parse(
            'https://maps.googleapis.com/maps/api/directions/json?origin=${rutaPuntos[i].latitude},${rutaPuntos[i].longitude}&destination=${rutaPuntos[i + 1].latitude},${rutaPuntos[i + 1].longitude}&mode=walking&key=AIzaSyCUDmn8tybGJqitGdBTpS6R4FN7V56JxCE'),
      );

      if (directionsResponse.statusCode == 200) {
        final decodedResponse = json.decode(directionsResponse.body);
        final routes = decodedResponse['routes'];
        if (routes != null && routes.isNotEmpty) {
          final points = _decodePolyline(routes[0]['overview_polyline']['points']);
          List<LatLng> routeCoords = points.map((point) => LatLng(point[0], point[1])).toList();
          allRoutePoints.addAll(routeCoords);
        }
      } else {
        throw Exception('Failed to load directions');
      }
    }

    setState(() {
      markers['start'] = Marker(
        markerId: MarkerId('start'),
        position: rutaPuntos.first,
      );
      markers['end'] = Marker(
        markerId: MarkerId('end'),
        position: rutaPuntos.last,
      );
      markers['current'] = Marker(
        markerId: MarkerId('current'),
        position: LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Icono representativo
      );
      rutaPuntos.clear();
      rutaPuntos.addAll(allRoutePoints);
    });
  }

  List<List<double>> _decodePolyline(String encoded) {
    List<List<double>> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add([lat / 1E5, lng / 1E5]);
    }
    return points;
  }
}
