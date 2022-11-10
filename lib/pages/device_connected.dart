import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';

import '../providers/ble_provider.dart';

class DeviceConnectedInfoPage extends StatefulWidget {
  final DiscoveredDevice device;
  const DeviceConnectedInfoPage({super.key, required this.device});

  @override
  State<DeviceConnectedInfoPage> createState() => _DeviceConnectedInfoPageState();
}

class _DeviceConnectedInfoPageState extends State<DeviceConnectedInfoPage> {
  Stream<ConnectionStateUpdate> _connectionStateStream = const Stream.empty();
  StreamSubscription<ConnectionStateUpdate>? _connectionStateSubscription;
  DeviceConnectionState? _connectionState = DeviceConnectionState.disconnected;
  bool shouldCancelConnection = false;

  int ledCharValue = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      _connectionStateStream = bleProvider.connectToDevice(widget.device.id);
      _connectionStateSubscription = _connectionStateStream.listen((connStatus) {
        if (shouldCancelConnection || mounted == false) {
          debugPrint('DeviceConnectedInfoPage > shouldCancelConnection: $shouldCancelConnection');
          _connectionStateSubscription?.cancel();
        }
        if (connStatus.deviceId == widget.device.id) {
          switch (connStatus.connectionState) {
            case DeviceConnectionState.connected:
              debugPrint('DeviceConnectedInfoPage > device connected');
              Future.delayed(Duration.zero, () async {
                final readRes =
                    await bleProvider.readCharacteristics(widget.device.id, '19B10001-E8F2-537E-4F6C-D104768A1214', '19B10000-E8F2-537E-4F6C-D104768A1214');
                if (readRes.isNotEmpty) {
                  if (mounted && ledCharValue != readRes.first) {
                    setState(() {
                      ledCharValue = readRes.first;
                    });
                  }
                }
              });
              break;
            case DeviceConnectionState.disconnected:
              debugPrint('DeviceConnectedInfoPage > device disconnected');
              Navigator.of(context).pop();
              break;
            default:
              debugPrint('DeviceConnectedInfoPage > device default');
          }
          setState(() => _connectionState = connStatus.connectionState);
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    try {
      debugPrint('DeviceConnectedInfoPage > dispose');
      _connectionStateSubscription?.cancel();
    } catch (e) {
      debugPrint('DeviceConnectedInfoPage > dispose > error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final BleProvider bleProvider = Provider.of<BleProvider>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(bleProvider.scanResultsList.any((element) => element.id == widget.device.id)
            ? bleProvider.scanResultsList.firstWhere((element) => element.id == widget.device.id).name
            : 'Device Not found on scanned list'),
      ),
      body: SafeArea(
        child: _connectionState != DeviceConnectionState.connected
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const Text('Connecting to device...'),
                    Text('Status: $_connectionState'),
                  ],
                ),
              )
            : SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text('Device Connected: ${widget.device.name.isNotEmpty ? widget.device.name : widget.device.id}'),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          // Led switch value
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('LED status', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Switch.adaptive(
                                  value: (ledCharValue != 0),
                                  activeColor: Colors.indigo.shade400,
                                  onChanged: (value) async {
                                    await bleProvider.writeCharacteristics(widget.device.id, '19B10001-E8F2-537E-4F6C-D104768A1214',
                                        '19B10000-E8F2-537E-4F6C-D104768A1214', (value == true) ? [1] : [0]);
                                    final readRes = await bleProvider.readCharacteristics(
                                        widget.device.id, '19B10001-E8F2-537E-4F6C-D104768A1214', '19B10000-E8F2-537E-4F6C-D104768A1214');
                                    debugPrint('DeviceConnectedInfoPage > readRes: $readRes');
                                    if (readRes.isNotEmpty == true) {
                                      setState(() => ledCharValue = readRes.first);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          // TODO: register to notification characteristic...
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
