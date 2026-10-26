import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_page.dart';
import 'mqtt_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AidApp());
}

class AidApp extends StatefulWidget {
  const AidApp({super.key, this.autoConnect = true});

  final bool autoConnect;

  @override
  State<AidApp> createState() => _AidAppState();
}

class _AidAppState extends State<AidApp> {
  late final AidController controller = AidController(autoConnect: widget.autoConnect);

  @override
  void initState() {
    super.initState();
    controller.start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AID',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF07110E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3DDC97),
          surface: Color(0xFF12201A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF07110E),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        fontFamily: 'Roboto',
      ),
      home: HomePage(controller: controller),
    );
  }
}
