import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:polylines_testing/provider/provider.dart';
import 'package:provider/provider.dart';

class MapScreenCreateAuto extends StatefulWidget {
  @override
  _MapScreenCreateStateAuto createState() => _MapScreenCreateStateAuto();
}

class _MapScreenCreateStateAuto extends State<MapScreenCreateAuto> {
  GoogleMapController? mapController;
  LocationData? currentLocation;
  Location location = Location();
  Map<String, Marker> markers = {};
  List<LatLng> rutaPuntos = [];
  List<LatLng> paintRoute= [];
  StreamSubscription<LocationData>? locationSubscription;
  Timer? timer;
  bool isRouteInProgress = false;
  double totalDistance = 0;
  bool isSavingRoute = false; // Variable para controlar el estado del botón
  

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _getCurrentLocation() async {
    try {
      currentLocation = await location.getLocation();
      setState(() {
        //markers[MarkerId('current')] =
        //    LatLng(currentLocation!.latitude!, currentLocation!.longitude!);
      });
    } catch (e) {
      print("Error getting location: $e");
    }
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
        });
      });

      currentLocation = await location.getLocation();
      _updateCameraToCurrentLocation();
    } catch (e) {
      print(e);
    }
  }

  void _updateCameraToCurrentLocation() {
    if (currentLocation != null && mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(
          LatLng(currentLocation!.latitude!, currentLocation!.longitude!)));
      setState(() {
        markers['current'] = Marker(
        markerId: MarkerId('current'),
        position: LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Icono representativo
      );
      });
    }
  }

  void _toggleRouteProgress() {
    setState(() {
      isRouteInProgress = !isRouteInProgress;
      if (isRouteInProgress) {
        timer = Timer.periodic(Duration(seconds: 15), (timer) {
          _saveCurrentPosition();
        });
      } else {
        timer?.cancel();
      }
    });
  }

  void _saveCurrentPosition() async {
    if (!isRouteInProgress) return;
    try {
      currentLocation = await location.getLocation();
      setState(() {
        rutaPuntos.add(
            LatLng(currentLocation!.latitude!, currentLocation!.longitude!));
        print(rutaPuntos);
        _fetchAndSetPolyline(rutaPuntos);
      });
    } catch (e) {
      print("Error saving location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(39.725024, 2.905675),
              zoom: 14.0,
            ),
            markers: Set<Marker>.of(markers.values),
            polylines: {
              if (rutaPuntos.isNotEmpty)
                Polyline(
                  polylineId: PolylineId('ruta'),
                  color: Colors.blue,
                  points: paintRoute,
                ),
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _toggleRouteProgress,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  isRouteInProgress ? 'Pausar Ruta' : 'Iniciar Ruta',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.0),
            Expanded(
              child: ElevatedButton(
                onPressed: isSavingRoute ? null : _showSaveRouteDialog,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  'Guardar Ruta',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
    });
  }

  void _showMarkerOptions(MarkerId markerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Marker Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Text('Latitude: ${markers[markerId]?.latitude}'),
            //Text('Longitude: ${markerPositions[markerId]?.longitude}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAndSetPolyline(List<LatLng> points) async {
    List<LatLng> allRoutePoints = [];
    double segmentDistance = 0;
    isSavingRoute = true;
    for (int i = 0; i < points.length - 1; i++) {
      final directionsResponse = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?origin=${points[i].latitude},${points[i].longitude}&destination=${points[i + 1].latitude},${points[i + 1].longitude}&mode=walking&key=AIzaSyCUDmn8tybGJqitGdBTpS6R4FN7V56JxCE',
        ),
      );

      if (directionsResponse.statusCode == 200) {
        final decodedResponse = json.decode(directionsResponse.body);
        final routes = decodedResponse['routes'];

        if (routes != null && routes.isNotEmpty) {
          final legs = routes[0]['legs'];
          if (legs != null && legs.isNotEmpty) {
            final int distance = legs[0]['distance']['value'];
            segmentDistance = distance.toDouble();
            print("Distance: $distance");
            print("Segment Distance: $segmentDistance");
          }

          final points = _decodePolyline(routes[0]['overview_polyline']['points']);
          List<LatLng> routeCoords = points.map((point) => LatLng(point[0], point[1])).toList();
          allRoutePoints.addAll(routeCoords);
        }
      } else {
        throw Exception('Failed to load directions');
      }
    }
    print("Segment Distance2: $segmentDistance");
    totalDistance += segmentDistance;
    print("Total Distance: $totalDistance");
    
    setState(() {
      isSavingRoute = false;
      markers['start'] = Marker(
        markerId: MarkerId('start'),
        position: rutaPuntos.first,
      );
      markers['end'] = Marker(
        markerId: MarkerId('end'),
        position: rutaPuntos.last,
      );
      paintRoute.clear();
      paintRoute.addAll(allRoutePoints);
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

  void _showSaveRouteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final tempRuta = Provider.of<RutasService>(context, listen: false).tempRuta;
            bool isNombreValido = tempRuta.nombre.isNotEmpty;
            bool isDescripcionValida = tempRuta.descripcion.isNotEmpty;
            bool isKilometrosValidos = tempRuta.distancia != null;
            bool isPublic = tempRuta.state;

            return AlertDialog(
              title: Text('Guardar Ruta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    decoration: InputDecoration(labelText: 'Nombre'),
                    onChanged: (value) {
                      setState(() {
                        isNombreValido = value.isNotEmpty;
                        tempRuta.nombre = value;
                      });
                    },
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'Descripción'),
                    onChanged: (value) {
                      setState(() {
                        isDescripcionValida = value.isNotEmpty;
                        tempRuta.descripcion = value;
                      });
                    },
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: 'Kilometros'),
                    onChanged: (value) {
                      setState(() {
                        isKilometrosValidos = value.isNotEmpty && double.tryParse(value) != null;
                        tempRuta.distancia = totalDistance;
                      });
                    },
                  ),
                  Row(
                    children: [
                      Text('Público:'),
                      SizedBox(width: 10),
                      Switch(
                        value: isPublic,
                        onChanged: (value) {
                          setState(() {
                            isPublic = value;
                            tempRuta.state = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!isRouteInProgress) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Debes iniciar la ruta primero')));
                      return;
                    }
                    if (isNombreValido && isDescripcionValida && isKilometrosValidos) {
                      List<String> dynamicList = rutaPuntos.map((latLng) => '${latLng.latitude}, ${latLng.longitude}').toList();
                      tempRuta.posicions = dynamicList;
                      Provider.of<RutasService>(context, listen: false).saveOrCreateRuta();
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Todos los campos son obligatorios')));
                    }
                  },
                  child: Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}