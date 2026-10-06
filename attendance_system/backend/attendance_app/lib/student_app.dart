import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// --- Student Login Page ---
class StudentLoginPage extends StatefulWidget {
  @override
  _StudentLoginPageState createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final url = Uri.parse('http://10.0.2.2:8000/api/auth/student/login'); // 10.0.2.2 for Android Emulator
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'computer_code': _codeController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StudentDashboard(
              studentName: data['student']['name'],
              enrollmentNo: data['student']['enrollment_no'],
            ),
          ),
        );
      } else {
        final data = json.decode(response.body);
        setState(() => _errorMessage = data['detail'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Network Error. Check Server.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school, size: 60, color: Colors.blueAccent),
                  SizedBox(height: 16),
                  Text("Student Portal", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 32),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: "Computer Code",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  SizedBox(height: 12),
                  if (_errorMessage.isNotEmpty)
                    Text(_errorMessage, style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading 
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text("LOGIN", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Student Dashboard (Next Page) ---
class StudentDashboard extends StatefulWidget {
  final String studentName;
  final String enrollmentNo;

  StudentDashboard({required this.studentName, required this.enrollmentNo});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String _detectedToken = '';
  bool _isScanning = false;
  bool _isMarking = false;
  File? _selfieImage;

  void _scanForBluetooth() {
    setState(() => _isScanning = true);
    // TODO: Implement actual BLE scanning logic here to extract token from Teacher's broadcast
    // For UI demonstration, we simulate finding a token after 2 seconds
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _detectedToken = 'A1B2C3D4'; // Simulated Token
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Classroom BLE Detected!')));
    });
  }

  Future<void> _captureSelfie() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (image != null) {
      setState(() {
        _selfieImage = File(image.path);
      });
    }
  }

  Future<void> _markAttendance() async {
    if (_selfieImage == null || _detectedToken.isEmpty) return;

    setState(() => _isMarking = true);
    final url = Uri.parse('http://10.0.2.2:8000/api/student/mark');
    
    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['enrollment_no'] = widget.enrollmentNo;
      request.fields['token'] = _detectedToken;
      request.files.add(await http.MultipartFile.fromPath('file', _selfieImage!.path));

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Attendance Marked!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${data["detail"]}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network Error!')));
    } finally {
      setState(() => _isMarking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.studentName.split(" ")[0]}'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.lightBlueAccent.withOpacity(0.2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.bluetooth_searching, size: 48, color: _detectedToken.isNotEmpty ? Colors.green : Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        _detectedToken.isNotEmpty 
                          ? "Classroom Detected!" 
                          : "Scan to find your Classroom",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: StadiumBorder()
                        ),
                        onPressed: _isScanning ? null : _scanForBluetooth,
                        icon: _isScanning 
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(Icons.radar, color: Colors.white),
                        label: Text(_isScanning ? "Scanning..." : "Scan Classroom BLE", style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              if (_detectedToken.isNotEmpty) ...[
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        _selfieImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_selfieImage!, height: 120, width: 120, fit: BoxFit.cover),
                              )
                            : Icon(Icons.camera_front, size: 60, color: Colors.orange),
                        SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _captureSelfie,
                          icon: Icon(Icons.camera_alt),
                          label: Text(_selfieImage != null ? "Retake Selfie" : "Take Live Selfie"),
                        ),
                        SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            onPressed: (_selfieImage != null && !_isMarking) ? _markAttendance : null,
                            child: _isMarking 
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text("MARK ATTENDANCE", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
