import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:serial_port_win32/serial_port_win32.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var ports = <String>[];
  late SerialPort port;

  final sendData = Uint8List.fromList(List.filled(4, 1, growable: false));

  String data = '';

  void _getPortsAndOpen() {
    ports = SerialPort.getAvailablePorts();
    print(ports);
    if (ports.isNotEmpty) {
      port = SerialPort(ports[0],
          openNow: false, ReadIntervalTimeout: 1, ReadTotalTimeoutConstant: 2);
      port.open();
      print(port.isOpened);
      port.readBytesOnListen(16, (value) {
        data = String.fromCharCodes(value);
        print(DateTime.now());
        print(data);
        setState(() {});
      });
    }
    setState(() {});
    // setState(() {
    //   ports = SerialPort.getAvailablePorts();
    // });
  }

  void _send() {
    // print(sendData);
    print(port.writeBytesFromUint8List(sendData));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              ports.toString(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(data),
            ElevatedButton(
              onPressed: () {
                port.close();
              },
              child: Text("close"),
            ),
            ElevatedButton(
              onPressed: () {
                _send();
              },
              child: Text("write"),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getPortsAndOpen,
        tooltip: 'GetPorts',
        child: Icon(Icons.search),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
