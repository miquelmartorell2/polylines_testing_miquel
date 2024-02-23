import 'dart:convert';

class RouteMap {
  RouteMap({
    this.id,
    required this.posicions,
    required this.state,
    required this.user_id,
    required this.nombre,
    required this.descripcion,
    required this.distancia
    
  });
  String? id;
  List<dynamic> posicions;
  bool state;
  String user_id;
  String nombre;
  String descripcion;
  double? distancia;
  

  factory RouteMap.fromJson(String str) => RouteMap.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory RouteMap.fromMap(Map<String, dynamic> json) => RouteMap(
        posicions: json["posicions"],
        state: json["state"],
        user_id: json["user_id"],
        nombre: json["nombre"],
        descripcion: json["descripcion"],
        distancia: json["distancia"]
      );

  Map<String, dynamic> toMap() => {
        "posicions": posicions,
        "state": state,
        "user_id": user_id,
        "nombre": nombre,
        "descripcion": descripcion,
        "distancia": distancia
      };

  RouteMap copy() => RouteMap(posicions: posicions, state: state, user_id: user_id, nombre: nombre, descripcion: descripcion, distancia: distancia, id : id);
}
