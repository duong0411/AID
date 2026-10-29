import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/monitor_provider.dart';
import 'ui/connect_page.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  final device = MonitorProvider();
  await device.loadSavedHost();
  runApp(SmartFirstAidApp(device: device));
}

class SmartFirstAidApp extends StatefulWidget {
  const SmartFirstAidApp({super.key, required this.device});

  final MonitorProvider device;

  @override
  State<SmartFirstAidApp> createState() => _SmartFirstAidAppState();
}

class _SmartFirstAidAppState extends State<SmartFirstAidApp> {
  late final MonitorProvider _device = widget.device;

  @override
  void dispose() {
    _device.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _device,
      child: MaterialApp(
        title: 'Smart First AID',
        debugShowCheckedModeBanner: false,
        theme: AidTheme.dark(),
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final device = context.watch<MonitorProvider>();
    if (!device.canEnterSystem) return const ConnectPage();
    return const HomePage();
  }
}
