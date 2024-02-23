import 'dart:convert';
import 'package:polylines_testing/models/routes.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RutasService extends ChangeNotifier {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final String _baseUrl =
      "mmartorellrs2p-default-rtdb.europe-west1.firebasedatabase.app";
  List<RouteMap> rutas = [];
  late RouteMap tempRuta;
  RouteMap? newRutas;

  RutasService() {
    this.loadRutas();
  }

  bool isValidForm() {
    return formKey.currentState?.validate() ?? false;
  }


  loadRutas() async {
    print('object');
    rutas.clear();
    final url = Uri.https(_baseUrl, 'rutas.json');
    print(url);
    
    final response = await http.get(url);
    print(json.decode(response.body));
    final Map<String, dynamic> rutasMap = json.decode(response.body);

    // Mapejam la resposta del servidor, per cada usuari, el convertim a la classe i l'afegim a la llista
    rutasMap.forEach((key, value) {
      final auxRuta = RouteMap.fromMap(value);
      auxRuta.id = key;
      rutas.add(auxRuta);
    });

    notifyListeners();
  }

  Future saveOrCreateRuta() async {
    if (tempRuta.id == null) {
      //Cream l'usuari
      await this.createRuta();
    } else {
      //Actualitzam l'usuari
      await this.updateRuta();
    }
    loadRutas();
  }

  updateRuta() async {

    final url = Uri.https(_baseUrl, 'rutas/${tempRuta.id}.json');
    print(url);
    final response = await http.put(url, body: tempRuta.toJson());
    final decodedData = response.body;
  }

  createRuta() async {
    final url = Uri.https(_baseUrl, 'rutas.json');
    final response = await http.post(url, body: tempRuta.toJson());
    final decodedData = json.decode(response.body);
  }

  deleteRuta(RouteMap ruta) async {
    print(ruta.id);
    print('test');
    final url = Uri.https(_baseUrl, 'rutas/${ruta.id}.json');
    final response = await http.delete(url);
    final decodedData = json.decode(response.body);
    print(decodedData);
    loadRutas();
  }
}
