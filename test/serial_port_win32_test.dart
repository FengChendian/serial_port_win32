import 'package:serial_port_win32/src/serial_port.dart';
import 'package:win32/win32.dart';

void main() async {
  var ports = SerialPort.getAvailablePorts();
  print(ports);
  if (ports.isNotEmpty) {
    var port = SerialPort(ports[0]);
    for (var i = 0; i < 100; i++) {
      print(await port.readBytes(2));
    }
    // port.BaudRate = CBR_115200;
    port.close();
  }
}
