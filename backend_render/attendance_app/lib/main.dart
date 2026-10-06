import 'package:flutter/material.dart';
import 'student_app.dart';

void main() {
  runApp(AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Attendance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StudentLoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
