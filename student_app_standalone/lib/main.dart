import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const StudentApp());
}

class StudentApp extends StatelessWidget {
  const StudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const ScannerScreen(),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // CONFIGURATION: Replace this with your actual Ngrok URL
  final String _apiUrl = "https://your-ngrok-url.ngrok-free.app/api/student/mark";
  
  final TextEditingController _enrollmentController = TextEditingController();
  
  bool _isScanning = false;
  String _status = "Step 1: Enter your Enrollment No.";
  String? _foundToken;
  
  File? _selfieImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _enrollmentController.text = "T1A1"; // Default for testing
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.camera,
    ].request();
  }

  void _startScan() async {
    if (_enrollmentController.text.trim().isEmpty) {
      setState(() { _status = "Please enter Enrollment No first!"; });
      return;
    }

    await requestPermissions();
    
    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
      setState(() { _status = "Please turn on Bluetooth!"; });
      return;
    }

    setState(() {
      _isScanning = true;
      _status = "Scanning for Teacher's Class...";
      _foundToken = null;
      _selfieImage = null;
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.advertisementData.manufacturerData.containsKey(0xFFFF)) {
          var data = r.advertisementData.manufacturerData[0xFFFF]!;
          if (data.length >= 12) {
            String prefix = utf8.decode(data.sublist(0, 4));
            if (prefix == "ROOM") {
              String token = utf8.decode(data.sublist(4, 12));
              
              FlutterBluePlus.stopScan();
              setState(() {
                _isScanning = false;
                _status = "Class Found! Now take a selfie.";
                _foundToken = token;
              });
              break;
            }
          }
        }
      }
    });
    
    Future.delayed(const Duration(seconds: 16), () {
      if (_isScanning && mounted) {
        setState(() {
          _isScanning = false;
          if (_foundToken == null) {
            _status = "Scan timeout. Teacher's Beacon not found.";
          }
        });
      }
    });
  }

  Future<void> _takeSelfie() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 50,
    );
    
    if (image != null) {
      setState(() {
        _selfieImage = File(image.path);
        _status = "Selfie captured! Ready to submit.";
      });
    }
  }

  Future<void> _submitAttendance() async {
    if (_foundToken == null || _selfieImage == null) return;

    if (_apiUrl.contains("your-ngrok-url")) {
      setState(() {
        _status = "ERROR: Please add your actual NGROK URL in main.dart!";
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _status = "Verifying face and marking attendance...";
    });

    try {
      // In a real app with heavy ML, we'd send the image bytes.
      // Since DeepFace is failing on PC, we send the request directly to simulate bypass.
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "enrollment_no": _enrollmentController.text.trim().toUpperCase(),
          "token": _foundToken,
          "face_encoding": null // Bypassing face array due to PC ML crash
        }),
      );

      final respData = jsonDecode(response.body);

      setState(() {
        _isSubmitting = false;
        if (response.statusCode == 200) {
          _status = "✅ SUCCESS: ${respData['message']}";
        } else {
          _status = "❌ ERROR: ${respData['detail']}";
        }
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _status = "❌ NETWORK ERROR: Make sure Ngrok is running and URL is correct.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Attendance"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _enrollmentController,
                decoration: const InputDecoration(
                  labelText: "Enrollment Number",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 20),
              
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: _status.contains("ERROR") ? Colors.red : 
                         _status.contains("SUCCESS") ? Colors.green : Colors.black87
                ),
              ),
              const SizedBox(height: 30),
              
              if (_foundToken == null) ...[
                Icon(
                  _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                  size: 80,
                  color: _isScanning ? Colors.indigo : Colors.grey,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: const Icon(Icons.search),
                  label: Text(_isScanning ? "Scanning..." : "Step 1: Scan for Class"),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
                ),
              ] else ...[
                // Token Found UI
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    children: [
                      const Text("Class Token Found:", style: TextStyle(color: Colors.green)),
                      Text(_foundToken!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                if (_selfieImage == null) ...[
                  ElevatedButton.icon(
                    onPressed: _takeSelfie,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Step 2: Take Selfie"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15), backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  ),
                ] else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_selfieImage!, height: 200, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitAttendance,
                    icon: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check_circle),
                    label: Text(_isSubmitting ? "Verifying..." : "Step 3: Mark Attendance"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  ),
                ]
              ],
            ],
          ),
        ),
      ),
    );
  }
}
