import 'package:flutter/material.dart';
import 'package:polylines_testing/models/routes.dart';
import 'package:provider/provider.dart';
import 'package:polylines_testing/provider/provider.dart';
import 'package:polylines_testing/ui/loading.dart';
import 'package:polylines_testing/widgets/ruda_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rutaService = Provider.of<RutasService>(context);
    List<RouteMap> rutas = rutaService.rutas;

    return Scaffold(
      appBar: AppBar(
        title: Text('Home Screen'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // Lógica para recargar las rutas
              rutaService.loadRutas();
            },
          ),
        ],
      ),
      body: rutas.isEmpty
          ? Loading()
          : ListView.builder(
              itemCount: rutas.length,
              itemBuilder: ((context, index) {
                return Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: AlignmentDirectional.centerEnd,
                    color: Colors.red,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0.0, 0.0, 10.0, 0.0),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                  ),
                  child: GestureDetector(
                    child: RutaCard(ruta: rutas[index]),
                    onTap: () {
                      rutaService.tempRuta = rutas[index].copy();
                      Navigator.of(context).pushNamed('mapa');
                    },
                  ),
                  onDismissed: (direction) {
                    if (rutas.length < 2) {
                      rutaService.loadRutas();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('No es pot esborrar tots els elements!')));
                    } else {
                      rutaService.deleteRuta(rutas[index]);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              '${rutaService.rutas[index].user_id} esborrat')));
                    }
                  },
                );
              }),
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              rutaService.tempRuta = RouteMap(nombre: '', descripcion: '', distancia: 0, state: false, user_id: 'testing', posicions: List.empty());
              Navigator.of(context).pushNamed('crear');
            },
            child: const Icon(Icons.add),
          ),
          SizedBox(width: 16), // Espacio entre botones
          FloatingActionButton(
            onPressed: () {
              rutaService.tempRuta = RouteMap(nombre: '', descripcion: '', distancia: 0, state: false, user_id: 'testing', posicions: List.empty());
              Navigator.of(context).pushNamed('crearAuto');
            },
            child: const Icon(Icons.create),
          ),
        ],
      ),
    );
  }
}
