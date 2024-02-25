import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:polylines_testing/provider/provider.dart';
import 'package:provider/provider.dart';

class MapScreenCreate extends StatefulWidget {
  @override
  _MapScreenCreateState createState() => _MapScreenCreateState();
}

class _MapScreenCreateState extends State<MapScreenCreate> {
  GoogleMapController? mapController;
  LocationData? currentLocation;
  Location location = Location();
  Map<MarkerId, LatLng> markerPositions = {};
  StreamSubscription<LocationData>? locationSubscription;
  List<LatLng> rutaPuntos = [];
  List<LatLng> paintRoute = [];
  bool isSavingRoute = false;
  double totalDistance = 0;
  bool shouldCenterOnUser = true;
  bool isFollowingUser = true;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    super.dispose();
  }

  void _toggleFollowingUser() {
    setState(() {
      isFollowingUser = !isFollowingUser;
      if (isFollowingUser) {
        _updateCameraToCurrentLocation();
      }
    });
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
          if (shouldCenterOnUser) {
            _updateCameraToCurrentLocation();
          }
        });
      });

      currentLocation = await location.getLocation();
      if (shouldCenterOnUser) {
        _updateCameraToCurrentLocation();
      }
    } catch (e) {
      print(e);
    }
  }

  void _updateCameraToCurrentLocation() {
    if (currentLocation != null && mapController != null && isFollowingUser) {
      mapController!.animateCamera(CameraUpdate.newLatLng(
          LatLng(currentLocation!.latitude!, currentLocation!.longitude!)));
      setState(() {});
    }
  }

  void _getCurrentLocation() async {
    try {
      currentLocation = await location.getLocation();
      setState(() {});
    } catch (e) {
      print("Error getting location: $e");
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Creació Manual de Rutes'),
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
    ),
    body: Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: LatLng(39.725024, 2.905675),
            zoom: 14.0,
          ),
          markers: _buildMarkers(),
          onTap: _addMarker,
          polylines: _buildPolylines(),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
        ),
        Positioned(
          bottom: 70.0, // Ajusta la posición vertical del botón de GPS
          left: 16.0,
          child: FloatingActionButton(
            onPressed: _toggleFollowingUser,
            child: Icon(isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed),
          ),
        ),
        Positioned(
  bottom: 16.0,
  left: 20.0, // Ajusta la posición horizontal del botón "Guardar Ruta"
  child: SizedBox(
    width: 240.0, // Establece el ancho del botón
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
),
      ],
    ),
    //floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    //bottomNavigationBar: _buildBottomNavigationBar(),
  );
}




  Set<Marker> _buildMarkers() {
    return Set<Marker>.of(markerPositions.keys.map((markerId) {
      return Marker(
        markerId: markerId,
        position: markerPositions[markerId]!,
        onTap: () => _showMarkerOptions(markerId),
      );
    }));
  }

  Set<Polyline> _buildPolylines() {
    return {
      if (rutaPuntos.isNotEmpty)
        Polyline(
          polylineId: PolylineId('ruta'),
          color: Colors.blue,
          points: paintRoute,
        ),
    };
  }

  Widget _buildBottomNavigationBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 60.0,
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
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
    });
  }

  void _addMarker(LatLng position) {
    final markerId = MarkerId(markerPositions.length.toString());
    setState(() {
      markerPositions[markerId] = position;
      rutaPuntos.add(position);
      if (rutaPuntos.length >= 2) {
        _fetchAndSetPolyline(rutaPuntos);
      }
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
            Text('Latitude: ${markerPositions[markerId]?.latitude}'),
            Text('Longitude: ${markerPositions[markerId]?.longitude}'),
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
              _removeMarker(markerId);
              Navigator.of(context).pop();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _removeMarker(MarkerId markerId) {
    setState(() {
      rutaPuntos.remove(markerPositions[markerId]);
      markerPositions.remove(markerId);
      _fetchAndSetPolyline(rutaPuntos);
    });
  }

  Future<void> _fetchAndSetPolyline(List<LatLng> points) async {
    List<LatLng> allRoutePoints = [];
    isSavingRoute = true;
    for (int i = 0; i < points.length - 1; i++) {
      final directionsResponse = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?origin=${points[i].latitude},${points[i].longitude}&destination=${points[i + 1].latitude},${points[i + 1].longitude}&mode=walking&units=metric&key=AIzaSyCUDmn8tybGJqitGdBTpS6R4FN7V56JxCE',
        ),
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
      paintRoute.clear();
      paintRoute.addAll(allRoutePoints);
      isSavingRoute = false;
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
  final rutaForm = Provider.of<RutasService>(context, listen: false);
  final tempRuta = rutaForm.tempRuta;
  bool isPublic = false;

showDialog(
  context: context,
  barrierDismissible: false,
  builder: (BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        // Obtener el estado actual de la ruta del proveedor
        final tempRuta = Provider.of<RutasService>(context, listen: false).tempRuta;
        // Inicializar las variables de validez de entrada
        bool isNombreValido = tempRuta.nombre.isNotEmpty;
        bool isDescripcionValida = tempRuta.descripcion.isNotEmpty;
        bool isKilometrosValidos = tempRuta.distancia != null;
        bool isPublic = tempRuta.state;
        _establishDistance(rutaPuntos);          
        print("Distnacia total ${totalDistance}");
        tempRuta.distancia = totalDistance;

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
              Row(
                children: [
                  Text('Público:'),
                  SizedBox(width: 10),
                  Switch(
                    value: isPublic,
                    onChanged: (value) {
                      setState(() {
                        isPublic = value; // Actualizar el valor de isPublic
                        tempRuta.state = value; // Actualizar el estado de la ruta
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
                print(isNombreValido);
                print(isDescripcionValida);
              
                if (isNombreValido && isDescripcionValida) {
                  // Convertir los puntos de ruta en una lista de cadenas
                  List<String> dynamicList = rutaPuntos.map((latLng) => '${latLng.latitude}, ${latLng.longitude}').toList();
                  tempRuta.posicions = dynamicList;
                  // Guardar o crear la ruta según corresponda
                  Provider.of<RutasService>(context, listen: false).saveOrCreateRuta();
                  Navigator.of(context).pop();
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
  
  Future<void> _establishDistance(List<LatLng> points) async {
    List<LatLng> allRoutePoints = [];
    isSavingRoute = true;
    double segmentDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final directionsResponse = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?origin=${points[i].latitude},${points[i].longitude}&destination=${points[i + 1].latitude},${points[i + 1].longitude}&mode=walking&units=metric&key=AIzaSyCUDmn8tybGJqitGdBTpS6R4FN7V56JxCE',
        ),
      );

      if (directionsResponse.statusCode == 200) {
        final decodedResponse = json.decode(directionsResponse.body);
        final routes = decodedResponse['routes'];
        if (routes != null && routes.isNotEmpty) {
          final legs = routes[0]['legs'];
          if (legs != null && legs.isNotEmpty) {
            final int distance = legs[0]['distance']['value'];
            segmentDistance += distance.toDouble();
            print("Distance: $distance");
            print("Segment Distance: $segmentDistance");
          }
        }
      } else {
        throw Exception('Failed to load directions');
      }
    }
    print("Segment Distance2: $segmentDistance");
    totalDistance = segmentDistance;
    print("Total Distance: $totalDistance");
  }

}