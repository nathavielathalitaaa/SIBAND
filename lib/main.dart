import 'package:flutter/material.dart';
import 'services/ble_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalmiBand',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'CalmiBand BLE Test'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final BleService _bleService = BleService();
  String _status = "Belum connect";

  @override
  void initState() {
    super.initState();
  }

  void _startScan() {
    setState(() {
      _status = "Scanning...";
    });
    _bleService.scanAndConnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(_status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            const Text(
              "Cek terminal/log buat lihat BPM yang masuk",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startScan,
        tooltip: 'Scan & Connect',
        child: const Icon(Icons.bluetooth_searching),
      ),
    );
  }
}