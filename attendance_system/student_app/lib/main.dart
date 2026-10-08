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
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _enrollmentController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMsg = "";

  // CONFIGURATION: Replace this with your actual Ngrok URL
  final String _loginApiUrl = "https://glandular-removable-railing.ngrok-free.dev/api/auth/student/login"; 
  // Using 10.0.2.2 for Android Emulator, use ngrok URL for physical device

  Future<void> _login() async {
    if (_enrollmentController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() { _errorMsg = "Please enter enrollment and password"; });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = "";
    });

    try {
      final response = await http.post(
        Uri.parse(_loginApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "computer_code": _enrollmentController.text.trim().toUpperCase(),
          "password": _passwordController.text.trim(),
        }),
      );

      setState(() { _isLoading = false; });

      if (response.statusCode == 200) {
        // Success
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ScannerScreen(enrollmentNo: _enrollmentController.text.trim().toUpperCase())),
        );
      } else {
        setState(() { _errorMsg = "Invalid Credentials"; });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = "Network Error: Could not reach server";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school, size: 80, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text("Student Portal", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 40),
              TextField(
                controller: _enrollmentController,
                decoration: const InputDecoration(
                  labelText: "Enrollment Number",
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMsg.isNotEmpty)
                Text(_errorMsg, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Login", style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen()));
                },
                child: const Text("New Student? Register Face First", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _enrollmentController = TextEditingController();
  File? _selfieImage;
  bool _isRegistering = false;
  String _status = "Enter Enrollment No & Take Selfie";
  
  // CONFIGURATION: Replace with actual Ngrok URL
  final String _registerApiUrl = "https://glandular-removable-railing.ngrok-free.dev/api/student";

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
        _status = "Photo captured! Ready to register.";
      });
    }
  }

  Future<void> _registerFace() async {
    if (_enrollmentController.text.trim().isEmpty || _selfieImage == null) {
      setState(() { _status = "Please provide both Enrollment No and Selfie!"; });
      return;
    }

    setState(() {
      _isRegistering = true;
      _status = "Uploading and extracting face embedding...";
    });

    try {
      var uri = Uri.parse("$_registerApiUrl/${_enrollmentController.text.trim().toUpperCase()}/register_face");
      var request = http.MultipartRequest('POST', uri);
      
      var pic = await http.MultipartFile.fromPath('file', _selfieImage!.path);
      request.files.add(pic);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final respData = jsonDecode(response.body);

      setState(() {
        _isRegistering = false;
        if (response.statusCode == 200) {
          _status = "✅ SUCCESS: ${respData['message']}";
        } else {
          _status = "❌ ERROR: ${respData['detail']}";
        }
      });
    } catch (e) {
      setState(() {
        _isRegistering = false;
        _status = "❌ NETWORK ERROR: Could not connect to server.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Face Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _enrollmentController,
              decoration: const InputDecoration(labelText: "Enrollment Number", border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: _status.contains("ERROR") ? Colors.red : Colors.green)),
            const SizedBox(height: 20),
            if (_selfieImage == null)
              ElevatedButton.icon(
                onPressed: _takeSelfie,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Take Registration Selfie"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
              )
            else ...[
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_selfieImage!, height: 200, fit: BoxFit.cover)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isRegistering ? null : _registerFace,
                icon: _isRegistering ? const CircularProgressIndicator() : const Icon(Icons.upload),
                label: Text(_isRegistering ? "Registering..." : "Submit Registration"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              )
            ],
          ],
        ),
      ),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  final String enrollmentNo;
  const ScannerScreen({super.key, required this.enrollmentNo});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // CONFIGURATION: Replace this with your actual Ngrok URL
  final String _apiUrl = "https://glandular-removable-railing.ngrok-free.dev/api/student/mark";
  
  bool _isScanning = false;
  String _status = "Step 1: Scan for Class";
  String? _foundToken;
  
  File? _selfieImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
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
      var uri = Uri.parse(_apiUrl);
      var request = http.MultipartRequest('POST', uri);
      
      request.fields['enrollment_no'] = widget.enrollmentNo;
      request.fields['token'] = _foundToken!;
      
      var pic = await http.MultipartFile.fromPath('file', _selfieImage!.path);
      request.files.add(pic);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
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
        title: Text("Welcome ${widget.enrollmentNo}"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
