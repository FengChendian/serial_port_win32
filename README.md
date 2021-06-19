# serial_port_win32

A SerialPort library using win32 API.

[![pub](https://img.shields.io/pub/v/serial_port_win32?color=blue)](https://pub.dev/packages/serial_port_win32)

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

### Set parameters

```dart
port.BaudRate = 115200;
port.ByteSize = 8;
port.StopBits = 0;
/// and so on, parameters like win32.
```

### Read

```dart
print(await ports.readBytes(2));
```

### Close Serial Port

```dart
port.close();
```

### Full Example

```dart
import 'package:serial_port_win32/src/serial_port.dart';

void main() {
    var ports = SerialPort.getAvailablePorts();
    print(ports);
    if(ports.isNotEmpty){
      var port = SerialPort(ports[0]);
      port.BaudRate = 115200;
      port.StopBits = 1;
      port.close();
    }
}
```
