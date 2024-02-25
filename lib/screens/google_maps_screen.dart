import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:polylines_testing/provider/provider.dart';
import 'package:provider/provider.dart';
import 'package:card_swiper/card_swiper.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  var tempRuta;

  GoogleMapController? mapController;
  LocationData? currentLocation;
  Location location = Location();
  StreamSubscription<LocationData>? locationSubscription;
  List<LatLng> rutaPuntos = [];
  Map<String, Marker> markers = {};
  bool isFollowingUser = false;
  bool centerFirstPoint = true;

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
  
  void _toggleFollowingUser() {
    setState(() {
      isFollowingUser = !isFollowingUser;
      if (isFollowingUser) {
        _updateCameraToCurrentLocation();
      }
    });
  }

  void _updateCameraToCurrentLocation() {
  if (currentLocation != null && mapController != null && isFollowingUser) {
    mapController!.animateCamera(CameraUpdate.newLatLng(
        LatLng(currentLocation!.latitude!, currentLocation!.longitude!)));
  } else if (rutaPuntos.isNotEmpty && mapController != null && centerFirstPoint) {
    mapController!.animateCamera(CameraUpdate.newLatLng(rutaPuntos.first));
    centerFirstPoint = false;
  }
  }

  @override
  Widget build(BuildContext context) {
    final rutaForm = Provider.of<RutasService>(context, listen: false);
    tempRuta = rutaForm.tempRuta;

    return Scaffold(
      appBar: AppBar(
      title: Text('Ruta'),
      centerTitle: true,
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
            onMapCreated: (controller) {
              mapController = controller;
            },
            markers: Set<Marker>.of(markers.values),
            initialCameraPosition: const CameraPosition(
              target: LatLng(0,0), // Centro del primer punto de ruta
              zoom: 15.0, // Ajusta el zoom según sea necesario
            ),
            polylines: {
              Polyline(
                polylineId: PolylineId('ruta'),
                color: Colors.blue,
                points: rutaPuntos,
              ),
            },
            myLocationEnabled: true, // Mostrar el círculo de la ubicación actual
            myLocationButtonEnabled: false, // Deshabilita el botón de ubicación actual de Google Maps
          ),
          //FloatingActionButton(
        //onPressed: () {
         // _showImagePopup(context);
       // },
       // child: Icon(Icons.image),
     // ),
          Positioned(
          bottom: 82.0, // Ajusta la posición vertical del botón GPS
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
      onPressed: _finishRoute,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      child: Text(
        'Finalizar ruta',
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
    rutaPuntos.clear();
    rutaPuntos.addAll(allRoutePoints);

    if (rutaPuntos.isNotEmpty) {
      markers['start'] = Marker(
        markerId: MarkerId('start'),
        position: rutaPuntos.first,
      );
      markers['end'] = Marker(
        markerId: MarkerId('end'),
        position: rutaPuntos.last,
      );
    }
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
void _finishRoute() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Has finalizado la ruta?'),
        content: Text('¿Estás seguro de que deseas finalizar la ruta?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              // Aquí puedes realizar cualquier acción necesaria cuando el usuario finaliza la ruta
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Volver a la página principal (cerrar el diálogo y la página del mapa)
            },
            child: Text('Sí'),
          ),
        ],
      ),
    );
  }
}

/*
  void _showImagePopup(BuildContext context) {
  final size = MediaQuery.of(context).size;
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: Container(
          width: double.infinity,
          height: size.height * 0.5,
          child: Swiper(
            itemCount: 5, // Mostrar cinco imágenes
            layout: SwiperLayout.STACK,
            itemWidth: size.width * 0.6,
            itemHeight: size.height * 0.4,
            itemBuilder: (BuildContext context, int index) {
              // Aquí cargamos las imágenes desde internet utilizando NetworkImage
              String imageUrl;
              switch (index) {
                case 0:
                  imageUrl = "https://snazzy-maps-cdn.azureedge.net/assets/25-blue-water.png?v=20170626083602";
                  break;
                case 1:
                  imageUrl = "https://snazzy-maps-cdn.azureedge.net/assets/93-lost-in-the-desert.png?v=20170626082912";
                  break;
                case 2:
                  imageUrl = "https://snazzy-maps-cdn.azureedge.net/assets/79-black-and-white.png?v=20170626082438";
                  break;
                case 3:
                  imageUrl = "https://snazzy-maps-cdn.azureedge.net/assets/39-paper.png?v=20170626083424";
                  break;
                case 4:
                  imageUrl = "https://snazzy-maps-cdn.azureedge.net/assets/134-light-dream.png?v=20170626074023";
                  break;
                default:
                  imageUrl = "";
              }
              return Image.network(
                imageUrl,
                fit: BoxFit.contain,
              );
            },
          ),
        ),
      );
    },
  );
}
*/
