import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class TeacherBleEngine {
  static const String classroomId = "ROOM_101";
  static const String secretKey = "Indore_Secure_Classroom_Salt_2026";
  static const int cycleIntervalSec = 4;
  
  final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();
  Timer? _timer;
  int _currentWindow = -1;

  // 1. Token Generate karne ka logic (Same as Python)
  int _getCurrentWindow() {
    return (DateTime.now().millisecondsSinceEpoch / 1000 ~/ cycleIntervalSec);
  }

  String _generateToken() {
    int targetWindow = _getCurrentWindow();
    String message = "$classroomId:$targetWindow";
    
    var key = utf8.encode(secretKey);
    var bytes = utf8.encode(message);
    
    var hmacSha256 = Hmac(sha256, key);
    var digest = hmacSha256.convert(bytes);
    
    // First 8 characters uppercase
    return digest.toString().substring(0, 8).toUpperCase();
  }

  // 2. Broadcast start karne ka logic
  void startBroadcasting() async {
    bool isSupported = await blePeripheral.isSupported;
    if (!isSupported) {
      print("BLE Advertising is not supported on this phone.");
      return;
    }

    // Har 4 second me check karega naya window
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      int windowNow = _getCurrentWindow();
      
      if (windowNow != _currentWindow) {
        _currentWindow = windowNow;
        String activeToken = _generateToken();
        print("[BLE_ENGINE] Emitted Token: $activeToken");

        // Payload ban banana
        List<int> roomBytes = utf8.encode("ROOM");
        List<int> tokenBytes = utf8.encode(activeToken);
        List<int> manufacturerData = [...roomBytes, ...tokenBytes];

        AdvertiseData advertiseData = AdvertiseData(
          manufacturerId: 0xFFFF, // Custom Company ID
          manufacturerSpecificData: manufacturerData,
          includeDeviceName: false,
        );

        AdvertiseSettings advertiseSettings = AdvertiseSettings(
          advertiseMode: AdvertiseMode.advertiseModeBalanced,
          txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
          connectable: false,
        );

        if (await blePeripheral.isAdvertising) {
          await blePeripheral.stop();
        }
        
        await blePeripheral.start(
          advertiseData: advertiseData,
          advertiseSettings: advertiseSettings,
        );
      }
    });
  }

  // 3. Broadcast stop karne ka logic
  void stopBroadcasting() async {
    _timer?.cancel();
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
    }
    print("[BLE_ENGINE] Stopped broadcasting.");
  }
}
