import 'dart:core';
import 'package:flutter/material.dart';
import 'package:multi_sensor_collector/UserInfoForm.dart';
import 'package:multi_sensor_collector/Utils/BodyPositions.dart';
import 'package:provider/provider.dart';
import 'package:timer_count_down/timer_count_down.dart';
import 'AppModel.dart';
import 'DeviceListModel.dart';
import 'DeviceModel.dart';

class DevicesConfigurationPage extends StatefulWidget {

  @override
  State<StatefulWidget> createState() {
    return _DevicesConfigurationPageState();
  }
}

class _DevicesConfigurationPageState extends State<DevicesConfigurationPage> {
  late Map<BodyPositions, bool> _callbackSuccess;
  late bool _devicesConfigurationCompleted;
  late ValueNotifier<bool> _configurationCompleted;
  late DeviceListModel deviceListModel;
  late AppModel _model;
  final GlobalKey<FormState> userIdFormKey = GlobalKey<FormState>();
  final TextEditingController _userIdTextController = TextEditingController();
  final TextEditingController _userAgeTextController = TextEditingController();
  final TextEditingController _userSexTextController = TextEditingController();
  final TextEditingController _userHeightTextController = TextEditingController();
  final TextEditingController _userWeightTextController = TextEditingController();

  static const String movementDetected = "Movement detected";
  static const String deviceSelection = "Is the device with the LED on the one located on the POSITION_PLACEHOLDER?";
  static const String yes = "Yes";
  static const String no = "No";
  static const String ok = "Ok";
  static const String getReady = "Get ready for the configuration of the sensor in position POSITION_PLACEHOLDER";
  static const String getInPosition = "Stand up with arms extended along the body and perform the movement at the end of the countdown";
  static const String cancel = "Cancel";
  static const String movementDetection = "Movement detection";
  static const String moveSensor = "Move the POSITION_PLACEHOLDER sensor";
  static const String confirmResetConf = "Do you confirm that you want to reset the configuration?";
  static const String configIncomplete = "Fill all the user information and configure at least one device";
  static const String devicesConfiguration = "Configuration";
  static const String configComplete = "Configuration successful";
  static const String resetConfiguration = "Reset configuration";
  static const String userInfo = "User Info";
  static const String devicesConfig = "Devices Position";
  static const String submitConfiguration = "Submit configuration";

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppModel>(context, listen: false);
    initDevicesState();
  }

  void initDevicesState() {
    deviceListModel = DeviceListModel();
    _callbackSuccess = Map();
    DeviceModel deviceModel;
    _callbackSuccess = {
      for (var value in BodyPositions.values) value: false
    };
    _model.deviceList.forEach((device) {
      deviceModel = DeviceModel(device.name, device.serial);
      deviceListModel.addDevice(deviceModel);
    });
    _devicesConfigurationCompleted = false;

    if (_model.configuredDeviceList.devices.length > 0) {
      for (var device in _model.configuredDeviceList.devices) {
        deviceListModel.removeDevice(device);
        _callbackSuccess[device.bodyPosition!] = true;
      }
        _devicesConfigurationCompleted = true;
    }
    _configurationCompleted = ValueNotifier<bool>(false);
  }

  Future<bool?> _showMovementDetectedDialog(BodyPositions bodyPart) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(movementDetected),
          content:  SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(deviceSelection.replaceAll("POSITION_PLACEHOLDER", bodyPart.name)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(yes),
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
            TextButton(
              child: const Text(no),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showCountDownDialog(BodyPositions bodyPart) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(getReady.replaceAll("POSITION_PLACEHOLDER", bodyPart.name)),
          content:  SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(getInPosition),
                Align(
                  alignment: Alignment.center,
                  child:
                  Countdown(
                    seconds: 0, // TODO: reset this
                    build: (BuildContext context, double time) => Text(
                      (time.toInt()+1).toString(),
                      style: TextStyle(
                        fontSize: 100,
                      ),),
                    interval: Duration(milliseconds: 1000),
                    onFinished: () {
                      Navigator.pop(context, true);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(cancel),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showMotionDetectionDialog(BodyPositions bodyPart) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(movementDetection),
          content:  SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(moveSensor.replaceAll("POSITION_PLACEHOLDER", bodyPart.name)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(cancel),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(confirmResetConf),
          actions: <Widget>[
            TextButton(
              child: const Text(yes),
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
            TextButton(
              child: const Text(no),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
          ],
        );
      },
    );
  }


  Future<bool?> _showConfigurationIncompleteDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(configIncomplete),
          actions: <Widget>[
            TextButton(
              child: const Text(ok),
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );
  }


  Future<void> _onPositionButtonPressed(BodyPositions bodyPart) async {
    bool? countDownDialogResult = await _showCountDownDialog(bodyPart);
    if (!countDownDialogResult!) {
      return;
    }

    // If user deletes operation from the dialog return, otherwise get result and continue
    Future<bool?> motionDetectionDialogResultFuture = _showMotionDetectionDialog(bodyPart);
    Future<List<DeviceModel>?> devicesSortedByMovementFuture = deviceListModel.checkForDevicesMovement();
    var futureResults = await Future.any([motionDetectionDialogResultFuture, devicesSortedByMovementFuture]);
    if (futureResults is bool && futureResults == false) {
      deviceListModel.unsubscribeAllDevicesToAccelerometer();
      return;
    }
    context.mounted ? Navigator.pop(context) : null;

    // Show the device that registered the most movement and make the user chose if it's the correct one
    for (final device in deviceListModel.devices) {
      if (device.bodyPosition == null) { // Body part not yet defined
        device.switchLed();
        bool? movementDetectedDialogResult = await _showMovementDetectedDialog(bodyPart);
        device.switchLed();
        if (movementDetectedDialogResult != null && movementDetectedDialogResult) {
          DeviceModel selectedDevice = deviceListModel.devices
              .where((element) => element.serial == device.serial)
              .first;
          selectedDevice.bodyPosition = bodyPart;
          _model.configuredDeviceList.addDevice(selectedDevice);
          setState(() {
            _callbackSuccess[bodyPart] = true;
            _devicesConfigurationCompleted = true;
          });
          break;
        } else {
          deviceListModel.unsubscribeAllDevicesToAccelerometer();
        }
      }
    }



  }

  Future<void> _onResetButtonPressed() async {
    bool? confirmationDialogResult = await _showConfirmationDialog();
    if (confirmationDialogResult != null && confirmationDialogResult) {
      // deviceListModel = DeviceListModel();
      // DeviceModel deviceModel;
      // model.deviceList.forEach((device) => {
      //   deviceModel = DeviceModel(device.name, device.serial),
      //   deviceListModel.addDevice(deviceModel),
      // });
      // _callbackSuccess = {
      //   for (var value in BodyPositions.values) value: false
      // };
      setState(() {
        _model.clearConfiguredDevices();
        _devicesConfigurationCompleted = false;
        initDevicesState();
      });

    }
  }


  void _onSubmitConfigButtonPressed() {
    // Validate returns true if the form is valid, or false otherwise.
    if (userIdFormKey.currentState!.validate() && _devicesConfigurationCompleted) {
      _configurationCompleted.value = true;
      _model.configuredDeviceList.userId = _userIdTextController.text;
      for (final device in _model.configuredDeviceList.devices) {
        device.userId = _userIdTextController.text;
        device.userAge = _userAgeTextController.text;
        device.userSex = _userSexTextController.text;
        device.userHeight = _userHeightTextController.text;
        device.userWeight = _userWeightTextController.text;
      }
    } else {
      _showConfigurationIncompleteDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in the state variable inside the build method
    _configurationCompleted.addListener(() {
      if (_configurationCompleted.value == true) {
        // Show a snackbar when the state variable changes to true
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(configComplete),
            ),
          );
        });
        _configurationCompleted.value = false;
        Navigator.pop(context);
      }
    });

    return ChangeNotifierProvider(
        create: (context) => deviceListModel,
        child: Consumer<DeviceListModel>(
            builder: (context, model, child)
            {
              return Scaffold(
                  appBar: AppBar(
                    title: Text(devicesConfiguration),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: _callbackSuccess.values.where((element) => element == true).length > 0 ? _onResetButtonPressed : null,
                        tooltip: resetConfiguration,
                      )
                    ],
                  ),
                  body:  Material(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              userInfo,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 20),
                            ),

                            // User info form
                            UserInfoForm(
                                formKey: userIdFormKey,
                                idController: _userIdTextController,
                                ageController: _userAgeTextController,
                                sexController: _userSexTextController,
                                heightController: _userHeightTextController,
                                weightController: _userWeightTextController,
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30, horizontal: 0),
                              child: Text(
                                devicesConfig,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                            ),

                            // Configure device buttons
                            for (final bodyPart in BodyPositions.values)
                              Card(
                                child: ListTile(
                                  title: Text(bodyPart.nameUpperCase),
                                  tileColor: _callbackSuccess[bodyPart]! ? Colors.green : null,
                                  enabled: _model.configuredDeviceList.devices.length < _model.connectedDeviceList.length && !_callbackSuccess[bodyPart]!,
                                  onTap: () => _onPositionButtonPressed(bodyPart),
                                ),
                              ),
                            Container(
                                margin: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 0.0),
                              child:
                                ElevatedButton(
                                  onPressed: () => _onSubmitConfigButtonPressed(),
                                   child: const Text(submitConfiguration),
                                )
                            )
                          ],
                        )
                  ))
              );
            }));
  }

}