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
    final List<PortInfo> portInfoLists = SerialPort.getPortsWithFullMessages();
    ports = SerialPort.getAvailablePorts();

    print(portInfoLists);
    print(ports);
    if (ports.isNotEmpty) {
      port = SerialPort("COM8", openNow: false);
      // port
      port.open();
    }
    setState(() {});
  }

  void _send() async {
    if (!port.isOpened) {
      port.open();
    }

    print('⬇---------------------------- general read (read <=  18 bytes)');
    await port.writeBytesFromString("😄我AT",
        includeZeroTerminator: false,
        stringConverter: StringConverter.nativeUtf8);
    var read = port.readBytes(18, timeout: Duration(milliseconds: 10))
      ..then((onValue) => print(onValue));
    await Future.delayed(Duration(milliseconds: 5));
    await port.writeBytesFromString("😄我AT",
        includeZeroTerminator: false,
        stringConverter: StringConverter.nativeUtf8);
    Uint8List readUint8List = await read;
    print('await result: $readUint8List');

    print(
        '⬇---------------------------- time out read,try to read **18 bytes** data in queue (read <= 18 bytes)');
    await port.writeBytesFromString("😄AT",
        includeZeroTerminator: false,
        stringConverter: StringConverter.nativeUtf8);
    var timeOutRead = port.readBytes(18, timeout: Duration(milliseconds: 10))
      ..then((onValue) => print(onValue));

    /// timeout
    await Future.delayed(Duration(milliseconds: 15));
    await port.writeBytesFromString("😄我AT",
        includeZeroTerminator: false,
        stringConverter: StringConverter.nativeUtf8);

    await timeOutRead;

    print(
        '⬇---------------------------- read successful without timeout, but you just want 8 bytes (read <= 8 bytes)');
    await port.writeBytesFromString("😄AT",
        includeZeroTerminator: false,
        stringConverter: StringConverter.nativeUtf8);
    var wantedBytesRead = port.readBytes(8, timeout: Duration(milliseconds: 10))
      ..then((onValue) => print(onValue));
    await port.writeBytesFromString("😄我AT",
        includeZeroTerminator: false,
        stringConverter: StringConverter.nativeUtf8);

    await wantedBytesRead;

    print(
        '⬇---------------------------- read until specified fixed size (2 bytes), it may cause deadlock (read == 2 bytes)');
    await port.writeBytesFromString("😄AT",
        includeZeroTerminator: false,
        stringConverter: StringConverter.nativeUtf8);
    var fixedBytesRead = port.readFixedSizeBytes(2)
      ..then((onValue) => print(onValue));
    await port.writeBytesFromString("😄我AT",
        includeZeroTerminator: false,
        stringConverter: StringConverter.nativeUtf8);

    await fixedBytesRead;

    /// Test disconnected
    while (true) {
      try {
        await port.readBytes(1, timeout: Duration(seconds: 1));
      } catch (e) {
        print(e);
        break;
      }
    }

    port.close();
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
