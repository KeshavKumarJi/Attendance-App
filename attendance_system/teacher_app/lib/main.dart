import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'teacher_ble.dart'; // Apna BLE logic import karo

// AAPKA NGROK URL YAHAN HAI
const String API_URL = 'https://glandular-removable-railing.ngrok-free.dev';

void main() {
  runApp(const TeacherApp());
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teacher App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
    );
  }
}

// 1. AUTH CHECK
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    if (!mounted) return;
    
    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// 2. LOGIN SCREEN
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$API_URL/api/auth/login'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'ngrok-skip-browser-warning': '69420'
        },
        body: {
          'username': _usernameController.text,
          'password': _passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        
        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
      } else {
        _showError('Login Failed: Incorrect username or password');
      }
    } catch (e) {
      _showError('Network error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username (e.g. T1)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: const Text('LOGIN'),
                  ),
          ],
        ),
      ),
    );
  }
}

// 3. MAIN NAVIGATION (WITH TABS)
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const DashboardTab(),
    const HistoryTab(),
    const ReportsTab(),
  ];

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher App'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout)
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: 'Start Class'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History & Edit'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Reports'),
        ],
      ),
    );
  }
}

// 4. DASHBOARD TAB (Start Class)
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<dynamic> _sections = [];
  int? _selectedSection;
  String _selectedBatch = 'BOTH';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSections();
  }

  Future<void> _fetchSections() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/sections'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420'
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _sections = json.decode(response.body);
          if (_sections.isNotEmpty) {
            _selectedSection = _sections[0]['id'];
          }
        });
      }
    } catch (e) {}
    setState(() => _isLoading = false);
  }

  Future<void> _startClass() async {
    if (_selectedSection == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final now = DateTime.now();
    final endTime = now.add(const Duration(hours: 2));
    
    final formatTime = (DateTime dt) => 
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00';
    final formatDate = (DateTime dt) => 
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    try {
      final response = await http.post(
        Uri.parse('$API_URL/api/attendance/auto_session'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '69420'
        },
        body: json.encode({
          'section_id': _selectedSection,
          'batch_type': _selectedBatch,
          'date': formatDate(now),
          'start_time': formatTime(now),
          'end_time': formatTime(endTime),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveClassScreen(
              sessionId: data['id'],
              sectionName: _sections.firstWhere((s) => s['id'] == _selectedSection)['name'],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network Error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Start a New Class', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            value: _selectedSection,
            decoration: const InputDecoration(labelText: 'Select Section'),
            items: _sections.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
            onChanged: (val) => setState(() => _selectedSection = val),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedBatch,
            decoration: const InputDecoration(labelText: 'Select Batch'),
            items: const [
              DropdownMenuItem(value: 'BOTH', child: Text('BOTH')),
              DropdownMenuItem(value: 'A', child: Text('Batch A')),
              DropdownMenuItem(value: 'B', child: Text('Batch B')),
            ],
            onChanged: (val) => setState(() => _selectedBatch = val!),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: _startClass,
            child: const Text('START CLASS & BLE BROADCAST'),
          ),
        ],
      ),
    );
  }
}

// 5. HISTORY TAB (Edit Sessions)
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<dynamic> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/attendance/sessions'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420'
        },
      );
      if (response.statusCode == 200) {
        setState(() => _sessions = json.decode(response.body));
      }
    } catch (e) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_sessions.isEmpty) return const Center(child: Text("No sessions today."));

    return ListView.builder(
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final s = _sessions[index];
        return ListTile(
          title: Text('Session ${s['id']} (Section: ${s['section_id']})'),
          subtitle: Text('${s['date']} | ${s['start_time']} - ${s['end_time']}'),
          trailing: const Icon(Icons.edit),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditSessionScreen(sessionData: s)),
            );
          },
        );
      },
    );
  }
}

// 6. EDIT SESSION SCREEN
class EditSessionScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  const EditSessionScreen({super.key, required this.sessionData});

  @override
  State<EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<EditSessionScreen> {
  List<dynamic> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/attendance/session/${widget.sessionData['id']}/live'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420'
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _records = data['records']);
      }
    } catch (e) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    List<Map<String, dynamic>> updatedRecords = _records.map((r) => {
      'student_id': r['student_id'],
      'status': r['status']
    }).toList();

    try {
      await http.put(
        Uri.parse('$API_URL/api/attendance/session/${widget.sessionData['id']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '69420'
        },
        body: json.encode({
          'section_id': widget.sessionData['section_id'],
          'batch_type': widget.sessionData['batch_type'],
          'date': widget.sessionData['date'],
          'start_time': widget.sessionData['start_time'],
          'end_time': widget.sessionData['end_time'],
          'records': updatedRecords,
        }),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving changes.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Attendance'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveChanges)
        ],
      ),
      body: ListView.builder(
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final r = _records[index];
          final isPresent = r['status'] == 'PRESENT';
          return SwitchListTile(
            title: Text(r['name']),
            subtitle: Text(r['enrollment_no']),
            value: isPresent,
            onChanged: (val) {
              setState(() {
                _records[index]['status'] = val ? 'PRESENT' : 'ABSENT';
              });
            },
          );
        },
      ),
    );
  }
}

// 7. REPORTS TAB
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  List<dynamic> _sections = [];
  int? _selectedSection;
  List<dynamic> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSections();
  }

  Future<void> _fetchSections() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/sections'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420'
        },
      );
      if (response.statusCode == 200) {
        setState(() => _sections = json.decode(response.body));
      }
    } catch (e) {}
    setState(() => _isLoading = false);
  }

  Future<void> _fetchReports(int sectionId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/reports/percentages?section_id=$sectionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420'
        },
      );
      if (response.statusCode == 200) {
        setState(() => _reports = json.decode(response.body));
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<int>(
            value: _selectedSection,
            decoration: const InputDecoration(labelText: 'Select Section to View Report'),
            items: _sections.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
            onChanged: (val) {
              setState(() {
                _selectedSection = val;
                _reports = [];
              });
              if (val != null) _fetchReports(val);
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _reports.length,
            itemBuilder: (context, index) {
              final r = _reports[index];
              return ListTile(
                title: Text(r['name']),
                subtitle: Text('${r['classes_attended']} / ${r['total_classes']} classes attended'),
                trailing: Text('${r['percentage']}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              );
            },
          ),
        )
      ],
    );
  }
}

// 8. LIVE CLASS SCREEN (No Changes)
class LiveClassScreen extends StatefulWidget {
  final int sessionId;
  final String sectionName;

  const LiveClassScreen({super.key, required this.sessionId, required this.sectionName});

  @override
  State<LiveClassScreen> createState() => _LiveClassScreenState();
}

class _LiveClassScreenState extends State<LiveClassScreen> {
  final TeacherBleEngine _bleEngine = TeacherBleEngine();
  List<dynamic> _records = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startLiveTracking();
  }

  void _startLiveTracking() {
    _bleEngine.startBroadcasting(); // Start BLE automatically
    _fetchLiveAttendance();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchLiveAttendance();
    });
  }

  Future<void> _fetchLiveAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/attendance/session/${widget.sessionId}/live'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420'
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) setState(() => _records = data['records']);
      }
    } catch (e) {}
  }

  Future<void> _endClass() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      await http.post(
        Uri.parse('$API_URL/api/attendance/session/${widget.sessionId}/end'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420'
        },
      );
    } catch (e) {}
    
    _bleEngine.stopBroadcasting();
    _timer?.cancel();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bleEngine.stopBroadcasting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int presentCount = _records.where((r) => r['status'] == 'PRESENT').length;

    return Scaffold(
      appBar: AppBar(title: Text('Live: ${widget.sectionName}'), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bluetooth_connected, color: Colors.green),
                    SizedBox(width: 8),
                    Text('BLE Active', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('Present: $presentCount / ${_records.length}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final student = _records[index];
                final isPresent = student['status'] == 'PRESENT';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPresent ? Colors.green : Colors.grey,
                    child: Icon(isPresent ? Icons.check : Icons.person, color: Colors.white),
                  ),
                  title: Text(student['name']),
                  subtitle: Text(student['enrollment_no']),
                  trailing: Text(isPresent ? 'Present' : 'Absent', style: TextStyle(color: isPresent ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              onPressed: _endClass,
              child: const Text('END CLASS & STOP BLE', style: TextStyle(fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }
}
