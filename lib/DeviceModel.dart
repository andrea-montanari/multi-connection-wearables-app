import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:mdsflutter/Mds.dart';
import 'package:multi_sensor_collector/Utils/BodyPositions.dart';
import 'package:multi_sensor_collector/Utils/RunningStat.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceModel extends ChangeNotifier {
  static const double MOVEMENT_THRESHOLD = 4.0;
  int sampleRate = 26;

  String? _serial;
  String? _name;

  String? get name => _name;

  String? get serial => _serial;

  StreamSubscription? _accSubscription;
  Map<String, double> _accelerometerData = Map();

  Map<String, double> get accelerometerData => _accelerometerData;

  bool get accelerometerSubscribed => _accSubscription != null;

  StreamSubscription? _imu9Subscription;
  Map<String, String> _imu9Data = Map();
  RunningStat runningStatX = RunningStat();
  RunningStat runningStatY = RunningStat();
  RunningStat runningStatZ = RunningStat();
  double stdSum = 0.0;
  List<String> csvHeaderImu9 = ["Timestamp","AccX","AccY","AccZ","GyroX","GyroY","GyroZ","MagnX","MagnY","MagnZ"];
  List<List<String>> csvDataImu9 = [];
  late String csvDirectoryImu9;

  BodyPositions? bodyPosition;

  Map<String, String> get imu9Data => _imu9Data;

  bool get imu9Subscribed => _imu9Subscription != null;

  List<RunningStat> get runningStats =>
      [runningStatX, runningStatY, runningStatZ];

  StreamSubscription? _hrSubscription;
  String _hrData = "";
  List<String> csvHeaderHr = ["Timestamp","bpm"];
  List<List<String>> csvDataHr = [];
  late String csvDirectoryHr;

  String get hrData => _hrData;

  bool get hrSubscribed => _hrSubscription != null;

  bool _ledStatus = false;

  bool get ledStatus => _ledStatus;

  String _temperature = "";

  String get temperature => _temperature;

  DeviceModel(this._name, this._serial);

  @override
  void dispose() {
    _accSubscription?.cancel();
    _hrSubscription?.cancel();
    super.dispose();
  }


  Stopwatch stopwatch = Stopwatch();
  void subscribeToAccelerometer() {
    stopwatch = Stopwatch()..start();
    _accelerometerData = Map();
    _accSubscription = MdsAsync.subscribe(
        Mds.createSubscriptionUri(_serial!, "/Meas/Acc/104"), "{}")
        .handleError((error) => {
      debugPrint("Error on subscribeToAccelerometer: " + error.toString())
    })
        .listen((event) {
      _onNewAccelerometerData(event);
    });

    notifyListeners();
  }

  void _onNewAccelerometerData(dynamic accData) {
    Map<String, dynamic> body = accData["Body"];
    List<dynamic> accArray = body["ArrayAcc"];
    dynamic acc = accArray.last;
    _accelerometerData["x"] = acc["x"].toDouble();
    _accelerometerData["y"] = acc["y"].toDouble();
    _accelerometerData["z"] = acc["z"].toDouble();
    print("Elapsed: ${stopwatch.elapsedMilliseconds}");
    log("Acc data device $serial, timestamp: ${body["Timestamp"]}");
    notifyListeners();
  }

  void subscribeToAccelerometerCheckForMovement({required Function onMovementDetected}) {
    print("Subscribe to accelerometer");
    _accelerometerData = Map();
    runningStatX.clear();
    runningStatY.clear();
    runningStatZ.clear();
    stdSum = 0.0;

    _accSubscription = MdsAsync.subscribe(
        Mds.createSubscriptionUri(_serial!, "/Meas/Acc/13"), "{}")
        .handleError((error) => {
      debugPrint("Error on subscribeToAccelerometerCheckForMovement: $error")
    })
        .listen((event) {
      _onNewAccelerometerDataCheckMovement(event, onMovementDetected);
    });

    notifyListeners();
  }

  void _onNewAccelerometerDataCheckMovement(dynamic accData, Function onMovementDetected) {
    Map<String, dynamic> body = accData["Body"];
    List<dynamic> accArray = body["ArrayAcc"];
    dynamic acc = accArray.last;
    _accelerometerData["x"] = acc["x"].toDouble();
    _accelerometerData["y"] = acc["y"].toDouble();
    _accelerometerData["z"] = acc["z"].toDouble();
    runningStatX.push(_accelerometerData["x"]!);
    runningStatY.push(_accelerometerData["y"]!);
    runningStatZ.push(_accelerometerData["z"]!);
    stdSum = runningStatX.maxStd() + runningStatY.maxStd() + runningStatZ.maxStd();
    if (stdSum > MOVEMENT_THRESHOLD) {
      onMovementDetected();
    }
    notifyListeners();
  }

  void unsubscribeFromAccelerometer() {
    if (_accSubscription != null) {
      _accSubscription!.cancel();
    }
    _accSubscription = null;
    notifyListeners();
  }

  void subscribeToIMU9() {
    print("Subscribe to IMU 9");
    _imu9Data = Map();
    print("Subscribing to IMU9. Rate: $sampleRate");

    csvDataImu9 = [];
    csvDataImu9.add(csvHeaderImu9);

    _imu9Subscription = MdsAsync.subscribe(
        Mds.createSubscriptionUri(_serial!, "/Meas/IMU9/" + sampleRate.toString()), "{}")
        .handleError((error) {
      print("Error: " + error.toString());
    })
        .listen((event) {
      _onNewIMU9Data(event);
    });

    notifyListeners();
  }

  void _onNewIMU9Data(dynamic imuData) {
    Map<String, dynamic> body = imuData["Body"];
    List<dynamic> accArray = body["ArrayAcc"];
    List<dynamic> gyroArray = body["ArrayGyro"];
    List<dynamic> magnArray = body["ArrayMagn"];

    var sampleInterval = 1000 / sampleRate;

    for (var probeIdx = 0; probeIdx < accArray.length; probeIdx++) {

      // Interpolate timestamp within update
      int timestamp = body["Timestamp"] + (sampleInterval * probeIdx).round();

      List<String> csvRow = [
        timestamp.toString(),
        accArray[probeIdx]["x"].toStringAsFixed(2),
        accArray[probeIdx]["y"].toStringAsFixed(2),
        accArray[probeIdx]["z"].toStringAsFixed(2),
        gyroArray[probeIdx]["x"].toStringAsFixed(2),
        gyroArray[probeIdx]["y"].toStringAsFixed(2),
        gyroArray[probeIdx]["z"].toStringAsFixed(2),
        magnArray[probeIdx]["x"].toStringAsFixed(2),
        magnArray[probeIdx]["y"].toStringAsFixed(2),
        magnArray[probeIdx]["z"].toStringAsFixed(2),
      ];
      csvDataImu9.add(csvRow);
    }

  }

  void unsubscribeFromIMU9(String currentDate) async {
    if (_imu9Subscription != null) {
      _imu9Subscription!.cancel();
    }
    _imu9Subscription = null;

    // Write data to csv file
    print("Writing data to csv file");
    csvDirectoryImu9 = await createExternalDirectory();
    print("Directory: $csvDirectoryImu9");
    String csvData = const ListToCsvConverter().convert(csvDataImu9);
    print("Csv data: $csvData");
    String path = "$csvDirectoryImu9/${currentDate}_IMU9Data-$serial.csv";
    final File file = await File(path).create(recursive: true);
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    await file.writeAsString(csvData);
    print("File written");

    notifyListeners();
  }

  Future<String> createExternalDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Movesense'); // Change this path accordingly
    } else if (Platform.isIOS) {
      dir = await getApplicationSupportDirectory(); // For iOS
    }
    if (dir != null) {
      if ((await dir.exists())) {
        print("Dir exists, path: ${dir.path}");
        return dir.path;
      } else {
        print("Dir doesn't exist, creating...");
        dir.create();
        return dir.path;
      }
    } else {
      throw Exception('Platform not supported');
    }
  }

  void subscribeToHr() {
    _hrData = "";

    csvDataHr = [];
    csvDataHr.add(csvHeaderHr);

    _hrSubscription = MdsAsync.subscribe(
        Mds.createSubscriptionUri(_serial!, "/Meas/HR"), "{}")
        .listen((event) {
      _onNewHrData(event);
    });
    notifyListeners();
  }

  void _onNewHrData(dynamic hrData) {
    Map<String, dynamic> body = hrData["Body"];
    double hr = body["average"].toDouble();
    _hrData = hr.toStringAsFixed(1) + " bpm";
    notifyListeners();
  }

  void unsubscribeFromHr() {
    if (_hrSubscription != null) {
      _hrSubscription!.cancel();
    }
    _hrSubscription = null;
    notifyListeners();
  }

  void switchLed() {
    debugPrint("switchLed()");
    Map<String, bool> contract = new Map<String, bool>();
    contract["isOn"] = !_ledStatus;
    MdsAsync.put(Mds.createRequestUri(_serial!, "/Component/Led"),
        jsonEncode(contract))
        .then((value) {
      debugPrint("switchLed then: $value");
      _ledStatus = !_ledStatus;
      notifyListeners();
    });
  }

  void getTemperature() async {
    debugPrint("getTemperature()");
    MdsAsync.get(Mds.createRequestUri(_serial!, "/Meas/Temp"), "{}")
        .then((value) {
      debugPrint("getTemperature value: $value");
      double kelvin = value["Measurement"];
      double temperatureVal = kelvin - 273.15;
      _temperature = temperatureVal.toStringAsFixed(1) + " C";
      notifyListeners();
    });
  }
}