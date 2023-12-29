import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:mdsflutter/Mds.dart';
import 'package:multi_sensor_collector/Utils/BodyPositions.dart';
import 'package:multi_sensor_collector/Utils/RunningStat.dart';

class DeviceModel extends ChangeNotifier {
  static const double MOVEMENT_THRESHOLD = 4.0;

  String? _serial;
  String? _name;

  String? get name => _name;

  String? get serial => _serial;

  StreamSubscription? _accSubscription;
  Map<String, double> _accelerometerData = Map();

  Map<String, double> get accelerometerData => _accelerometerData;

  bool get accelerometerSubscribed => _accSubscription != null;

  StreamSubscription? _IMU9Subscription;
  Map<String, String> _IMU9Data = Map();
  RunningStat runningStatX = RunningStat();
  RunningStat runningStatY = RunningStat();
  RunningStat runningStatZ = RunningStat();
  double stdSum = 0.0;

  BodyPositions? bodyPosition;

  Map<String, String> get IMU9Data => _IMU9Data;

  bool get IMU9Subscribed => _IMU9Subscription != null;

  List<RunningStat> get runningStats =>
      [runningStatX, runningStatY, runningStatZ];

  StreamSubscription? _hrSubscription;
  String _hrData = "";

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

  void subscribeToIMU9({String rate = '104'}) {
    print("Subscribe to IMU 9");
    _IMU9Data = Map();
    print("Subscribing to IMU9. Rate: $rate");
    _IMU9Subscription = MdsAsync.subscribe(
        Mds.createSubscriptionUri(_serial!, "/Meas/IMU9/104"), "{}")
        .handleError((error) {
      print("Error: " + error.toString());
    })
        .listen((event) {
      _onNewIMU9Data(event);
    })
    ;

    notifyListeners();
  }

  void _onNewIMU9Data(dynamic imuData) {
    Map<String, dynamic> body = imuData["Body"];
    List<dynamic> accArray = body["ArrayAcc"];
    List<dynamic> gyroArray = body["ArrayGyro"];
    List<dynamic> magnArray = body["ArrayMagn"];
    dynamic acc = accArray.last;
    dynamic gyro = gyroArray.last;
    dynamic magn = magnArray.last;
    _IMU9Data["Timestamp"] = body["Timestamp"].toString();
    print("Timestamp: ${_IMU9Data["Timestamp"]}");
    for (var probe in body["ArrayAcc"]) {
      print("Probe: $probe");
    }
    _IMU9Data["Acc"] = "x: " +
        acc["x"].toStringAsFixed(2) +
        "\ny: " +
        acc["y"].toStringAsFixed(2) +
        "\nz: " +
        acc["z"].toStringAsFixed(2);
    _IMU9Data["Gyro"] = "x: " +
        gyro["x"].toStringAsFixed(2) +
        "\ny: " +
        gyro["y"].toStringAsFixed(2) +
        "\nz: " +
        gyro["z"].toStringAsFixed(2);
    _IMU9Data["Magn"] = "x: " +
        magn["x"].toStringAsFixed(2) +
        "\ny: " +
        magn["y"].toStringAsFixed(2) +
        "\nz: " +
        magn["z"].toStringAsFixed(2);
    // notifyListeners();
  }

  void unsubscribeFromIMU9() {
    if (_IMU9Subscription != null) {
      _IMU9Subscription!.cancel();
    }
    _IMU9Subscription = null;
    notifyListeners();
  }

  void subscribeToHr() {
    _hrData = "";
    _hrSubscription = MdsAsync.subscribe(
        Mds.createSubscriptionUri(_serial!, "/Meas/HR"), "{}")
        .listen((event) {
      _onNewHrData(event);
    });
    notifyListeners();
  }

  void _onNewHrData(dynamic hrData) {
    Map<String, dynamic> body = hrData["Body"];
    double hr = body["average"];
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