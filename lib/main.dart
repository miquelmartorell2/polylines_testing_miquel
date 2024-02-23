import 'package:flutter/material.dart';
import 'package:polylines_testing/provider/provider.dart';
import 'package:polylines_testing/screens/google_maps_create_auto_screen.dart';
import 'package:polylines_testing/screens/google_maps_create_screen.dart';
import 'package:polylines_testing/screens/google_maps_screen.dart';
import 'package:polylines_testing/screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => RutasService())],
    child:MyApp()));
  }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: 'home',
      routes: {
        'home': (_) => HomeScreen(),
        'mapa': (_) => MapScreen(),
        'crear': (_) => MapScreenCreate(),
        'crearAuto': (_) => MapScreenCreateAuto()
      },
    );
  }
}
