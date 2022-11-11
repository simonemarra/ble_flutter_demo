import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleDeviceModel {
  final String id;
  final String name;

  BleDeviceModel({required this.id, required this.name});

  DeviceConnectionState? connectionState;
  Stream<ConnectionStateUpdate> connectionStateStream = const Stream.empty();
  StreamSubscription<ConnectionStateUpdate>? connectionStateSubscription;

  // List of notifications characteristics Streams
  List<Stream<List<int>>?> notificationsStreams = [];
  List<StreamSubscription<List<int>>?> notificationsStreamsSubscriptions = [];

  // List of discovered services
  List<DiscoveredService> discoveredServices = [];
}
