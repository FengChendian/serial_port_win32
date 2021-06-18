import 'package:serial_port_win32/src/serial_port.dart';

void main() {
  var ports = SerialPort.getAvailablePorts();
  print(ports);
  if (ports.isNotEmpty) {
    var port = SerialPort(ports[0]);
    port.BaudRate = 115200;
    port.close();
  }
}
