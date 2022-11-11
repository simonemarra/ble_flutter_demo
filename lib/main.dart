import 'package:flutter/material.dart';
import 'package:flutter_ble/pages/device_connected.dart';
import 'package:flutter_ble/providers/ble_provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BleProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        primarySwatch: Colors.indigo,
      ),
      home: const MyHomePage(title: 'Flutter Demo BLE'),
      onGenerateRoute: onGenerateRoute,
    );
  }
}

// crate a getter for onGenerateRoute
RouteFactory get onGenerateRoute => (RouteSettings settings) {
      final String? name = settings.name;
      final Map<String, dynamic>? arguments = settings.arguments == null ? null : settings.arguments as Map<String, dynamic>;
      switch (name) {
        case '/device_connected':
          final device = arguments!['device'];
          return MaterialPageRoute(
            builder: (context) => DeviceConnectedInfoPage(device: device),
            settings: settings,
          );
        default:
          return MaterialPageRoute(
            builder: (context) => const MyHomePage(title: 'Flutter Demo BLE'),
            settings: settings,
          );
      }
    };

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    final BleProvider bleProvider = Provider.of<BleProvider>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(18),
                child: FittedBox(
                  child: Text(
                    BleProvider.bleStatusText(bleProvider.bleStatus),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    elevation: 0,
                    color: Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    child: ListView.builder(
                      reverse: false,
                      itemCount: bleProvider.scanResultsList.length < 10 ? bleProvider.scanResultsList.length : 10,
                      itemBuilder: (BuildContext context, int index) {
                        final data = bleProvider.scanResultsList[index];
                        return ListTile(
                          title: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${data.name} - rssi: ${data.rssi}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          subtitle: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(data.id),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              await bleProvider.stopBleScan();
                              // ignore: use_build_context_synchronously
                              Navigator.of(context).pushNamed('/device_connected', arguments: {'device': data});
                              // bleProvider.connectToDevice(data.id);
                            },
                            child: const Text('Connect'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(onPressed: bleProvider.requestAllPermissions, child: const Text('Authorize BLE')),
                    ElevatedButton(
                        onPressed: () => bleProvider.startBleScan(
                              servicesFilter: [
                                Uuid.parse("19B10000-E8F2-537E-4F6C-D104768A1214"),
                              ],
                              maxResults: 8,
                            ),
                        child: const Text('Start Scan')),
                    ElevatedButton(
                        onPressed: () {
                          bleProvider.stopBleScan();
                          bleProvider.scanResultsList = [];
                        },
                        child: const Text('Stop Scan')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
