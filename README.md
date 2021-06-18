# serial_port_win32

A SerialPort library using win32 API.

## Getting Started

### Get Ports

```dart
var ports = SerialPort.getAvailablePorts();
print(ports);
/// result like [COM3, COM4]
```

### Create Serial Port

```dart
final port = SerialPort("COM5");
```

### Example
```dart
import 'package:serial_port_win32/src/serial_port.dart';

void main() {
    var ports = SerialPort.getAvailablePorts();
    print(ports);
    if(ports.isNotEmpty){
      var port = SerialPort(ports[0]);
      port.BaudRate = 115200;
      port.close();
    }
}
```
