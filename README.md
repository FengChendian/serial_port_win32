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
final port = SerialPort("COM5", openNow: false);
// port.open()
port.openWithSettings(BaudRate: CBR_115200);
// final port = SerialPort("COM5"); /// auto open with default settings
```

### Set parameters

```dart
port.BaudRate = CBR_115200;
port.ByteSize = 8;
port.StopBits = ONESTOPBIT;
port.Parity = NOPARITY;
port.ReadIntervalTimeout = 10;
/// and so on, parameters like win32.
```

### Read

```dart
print(await ports.readBytes(2));
```

### Write

#### Write String

```dart
String buffer = "hello";
port.writeBytesFromString(buffer);
```

#### Write Uint8List

```dart
final uint8_data = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
print(port.writeBytesFromUint8List(uint8_data));
```

### Get Port Connection Status

```dart
port.isOpened == false;
```

### Close Serial Port

```dart
port.close();
```

### Small Example

```dart
import 'package:serial_port_win32/src/serial_port.dart';

void main() {
    var ports = SerialPort.getAvailablePorts();
    print(ports);
    if(ports.isNotEmpty){
      var port = SerialPort(ports[0]);
      port.BaudRate = CBR_115200;
      port.StopBits = ONESTOPBIT;
      port.close();
    }
}
```
