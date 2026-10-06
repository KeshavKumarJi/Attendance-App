import 'package:flutter/material.dart';
import 'teacher_ble.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teacher App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TeacherHomePage(),
    );
  }
}

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final TeacherBleEngine _bleEngine = TeacherBleEngine();
  bool isBroadcasting = false;

  void toggleBroadcasting() {
    setState(() {
      isBroadcasting = !isBroadcasting;
    });

    if (isBroadcasting) {
      _bleEngine.startBroadcasting();
    } else {
      _bleEngine.stopBroadcasting();
    }
  }

  @override
  void dispose() {
    _bleEngine.stopBroadcasting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Teacher BLE Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              isBroadcasting ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              size: 100,
              color: isBroadcasting ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              isBroadcasting ? 'Broadcasting Attendance Token...' : 'Broadcast Stopped',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: toggleBroadcasting,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                backgroundColor: isBroadcasting ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isBroadcasting ? 'STOP BROADCASTING' : 'START BROADCASTING',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
