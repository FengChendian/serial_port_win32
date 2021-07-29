import 'dart:io';

import 'package:serial_port_win32/src/serial_port.dart';
import 'package:win32/win32.dart';

void main() async {
  var ports = SerialPort.getAvailablePorts();
  print(ports);
  if (ports.isNotEmpty) {
    var port = SerialPort(ports[0]);
    port.readBytesOnListen(8, (value) => print(value));
    sleep(Duration(seconds: 10));
    // port.BaudRate = CBR_115200;
    // port.close();
  }
}
