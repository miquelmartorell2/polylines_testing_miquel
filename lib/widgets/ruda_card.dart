
import 'package:flutter/material.dart';
import 'package:polylines_testing/models/routes.dart';

class RutaCard extends StatelessWidget {
  final RouteMap ruta;
  const RutaCard({super.key, required this.ruta});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(ruta.user_id)),
      title: Text(ruta.user_id),
      subtitle: Text(ruta.descripcion),
      );
  }
}
