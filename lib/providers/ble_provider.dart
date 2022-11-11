import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleProvider with ChangeNotifier {
  static final FlutterReactiveBle flutterReactiveBle = FlutterReactiveBle();

  static String bleStatusText(BleStatus status) {
    switch (status) {
      case BleStatus.unsupported:
        return "This device does not support Bluetooth";
      case BleStatus.unauthorized:
        return "Authorize the app to use Bluetooth and location";
      case BleStatus.poweredOff:
        return "Bluetooth is powered off on your device turn it on";
      case BleStatus.locationServicesDisabled:
        return "Enable location services";
      case BleStatus.ready:
        return "Bluetooth is up and running";
      default:
        return "Waiting to fetch Bluetooth status $status";
    }
  }

  Future<PermissionStatus> requestAllPermissions() async {
    final locationPerm = await Permission.locationAlways.request();
    var blePerm = PermissionStatus.denied;
    debugPrint('locationPerm: $locationPerm');
    if (Platform.isIOS) {
      blePerm = await Permission.bluetooth.request();
    } else if (Platform.isAndroid) {
      final bleScanPerm = await Permission.bluetoothScan.request();
      final bleConnectPerm = await Permission.bluetoothConnect.request();
      blePerm = bleScanPerm.isGranted && bleConnectPerm.isGranted ? PermissionStatus.granted : PermissionStatus.denied;
    }
    return locationPerm == PermissionStatus.granted && blePerm == PermissionStatus.granted ? PermissionStatus.granted : PermissionStatus.denied;
  }

  static BleStatus _bleStatus = BleStatus.unknown;
  BleStatus get bleStatus => _bleStatus;
  set bleStatus(BleStatus status) {
    _bleStatus = status;
    notifyListeners();
  }

  static Stream<DiscoveredDevice>? _bleScanStream;
  Stream<DiscoveredDevice>? get bleScanStream => _bleScanStream;
  set bleScanStream(Stream<DiscoveredDevice>? stream) {
    _bleScanStream = stream;
    notifyListeners();
  }

  static Stream<BleStatus>? _bleStatusStream;
  Stream<BleStatus>? get bleStatusStream => _bleStatusStream;
  set bleStatusStream(Stream<BleStatus>? stream) {
    _bleStatusStream = stream;
    notifyListeners();
  }

  static bool _bleScanRunning = false;
  bool get bleScanRunning => _bleScanRunning;
  set bleScanRunning(bool value) {
    _bleScanRunning = value;
    notifyListeners();
  }

  static final List<DiscoveredDevice> _scanResultsListComplete = [];
  static List<DiscoveredDevice> _scanResultsList = [];
  List<DiscoveredDevice> get scanResultsList => _scanResultsList;
  set scanResultsList(List<DiscoveredDevice> list) {
    _scanResultsList = list;
    notifyListeners();
  }

  BleProvider() {
    // TODO: verifica se lo status stream è già in ascolto e se lo è non fare niente
    bleStatusStream = flutterReactiveBle.statusStream;
    bleStatusStream?.listen((status) {
      bleStatus = status;
      debugPrint('BleService statusStream: ${bleStatusText(status)}');
      // if (kDebugMode) {
      //   print('BleService statusStream: ${bleStatusText(status)}');
      // }
    });
  }

  Future<void> startBleScan({List<Uuid>? servicesFilter, ScanMode? scanMode, int? maxResults}) async {
    if (!bleScanRunning && await requestAllPermissions() == PermissionStatus.granted) {
      if (bleScanStream != null) {
        bleScanStream = null;
        stopBleScan();
      }
      bleScanStream = flutterReactiveBle.scanForDevices(
        withServices: servicesFilter ?? [],
        scanMode: scanMode ?? ScanMode.lowLatency,
      );
      if (bleScanStream != null) {
        bleScanRunning = true;
        // start the ble scan
        bleScanStream!.listen((scanResult) {
          // filter only named devices for now:
          if (kDebugMode) {
            print('BleService scanStream: ${scanResult.name} ${scanResult.id} ${scanResult.serviceData} ${scanResult.serviceUuids}');
          }
          if (_scanResultsListComplete.any((element) => element.id == scanResult.id)) {
            _scanResultsListComplete.removeWhere((element) => element.id == scanResult.id);
          }
          _scanResultsListComplete.add(scanResult);
          _scanResultsList = _scanResultsListComplete;
          // results with name should be in upper position, then results without name, all sorted by rssi
          final resWithName = _scanResultsList.where((element) => element.name.isNotEmpty == true).toList();
          final resWithoutName = _scanResultsList.where((element) => element.name.isEmpty == true).toList();
          resWithName.sort((a, b) => b.rssi.compareTo(a.rssi));
          resWithoutName.sort((a, b) => b.rssi.compareTo(a.rssi));
          _scanResultsList = resWithName + resWithoutName;
          if (scanResultsList.length > (maxResults ?? 10)) {
            scanResultsList.removeAt(0);
          }
          scanResultsList = [...scanResultsList];
        }).onError((error) {
          if (kDebugMode) {
            print('error: $error');
          }
        });
      }
    }
  }

  Future<void> stopBleScan() async {
    if (bleScanRunning) {
      bleScanRunning = false;
      bleScanStream = null;
    }
    debugPrint('BleProvider: stopBleScan');
    await flutterReactiveBle.deinitialize();
    await Future.delayed(const Duration(seconds: 1), () async {
      debugPrint('BleProvider: Future initialize');
      await flutterReactiveBle.initialize();
    });
  }

  Stream<ConnectionStateUpdate> _deviceConnectionStatusStream = const Stream.empty();
  Stream<ConnectionStateUpdate> get deviceConnectionStatusStream => _deviceConnectionStatusStream;
  set deviceConnectionStatusStream(Stream<ConnectionStateUpdate> stream) {
    _deviceConnectionStatusStream = stream;
    notifyListeners();
  }

  Stream<ConnectionStateUpdate> connectToDevice(String deviceId) {
    if (kDebugMode) {
      debugPrint('BleProvider: connectToDevice $deviceId');
    }
    final conn = flutterReactiveBle.connectToDevice(
      id: deviceId,
      // withServices: [],
      // prescanDuration: const Duration(seconds: 1),
      connectionTimeout: const Duration(seconds: 10),
    );
    // stopBleScan();
    return conn;
  }

  Stream<ConnectionStateUpdate> connectToAdvertisingDevice(
    String deviceId,
    List<Uuid> withServices,
    Duration prescanDuration, {
    Map<Uuid, List<Uuid>>? servicesWithCharacteristicsToDiscover,
    Duration? connectionTimeout,
  }) {
    if (kDebugMode) {
      debugPrint('BleProvider: connectToAdvertisingDevice $deviceId');
    }
    final conn = flutterReactiveBle.connectToAdvertisingDevice(
      id: deviceId,
      withServices: [],
      prescanDuration: prescanDuration,
      servicesWithCharacteristicsToDiscover: servicesWithCharacteristicsToDiscover,
      connectionTimeout: connectionTimeout ?? const Duration(seconds: 10),
    );
    return conn;
  }

  Future<List<int>> readCharacteristics(String deviceId, String characteristicUuid, String serviceUuid) async {
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUuid),
      characteristicId: Uuid.parse(characteristicUuid),
      deviceId: deviceId,
    );
    final response = await flutterReactiveBle.readCharacteristic(characteristic);
    return response;
  }

  Future<void> writeCharacteristics(String deviceId, String characteristicUuid, String serviceUuid, List<int> value) async {
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUuid),
      characteristicId: Uuid.parse(characteristicUuid),
      deviceId: deviceId,
    );
    await flutterReactiveBle.writeCharacteristicWithResponse(characteristic, value: value);
  }

  Stream<List<int>> subscribeToCharacteristic(String deviceId, String characteristicUuid, String serviceUuid) {
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUuid),
      characteristicId: Uuid.parse(characteristicUuid),
      deviceId: deviceId,
    );
    return flutterReactiveBle.subscribeToCharacteristic(characteristic);
  }
}
