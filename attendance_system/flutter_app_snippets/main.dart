import 'package:flutter/material.dart';
import 'teacher_ble.dart'; // Humari engine file import ki hai

void main() {
  runApp(const TeacherApp());
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teacher BLE App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TeacherBleEngine bleEngine = TeacherBleEngine();
  bool isBroadcasting = false;

  void toggleBroadcast() {
    if (isBroadcasting) {
      bleEngine.stopBroadcasting();
    } else {
      bleEngine.startBroadcasting();
    }
    
    setState(() {
      isBroadcasting = !isBroadcasting;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Dashboard"),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBroadcasting ? Icons.bluetooth_audio : Icons.bluetooth_disabled,
              size: 100,
              color: isBroadcasting ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              isBroadcasting ? "Class is LIVE! Broadcasting..." : "Class is Stopped",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isBroadcasting ? Colors.red : Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: toggleBroadcast,
              child: Text(
                isBroadcasting ? "END SESSION" : "START SESSION",
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
