# serial_port_win32

A SerialPort library using win32 API. 

[![pub](https://img.shields.io/pub/v/serial_port_win32?color=blue)](https://pub.dev/packages/serial_port_win32)

## Getting Started

### Get Ports

```dart
final ports = SerialPort.getAvailablePorts();
print(ports);
/// result like [COM3, COM4]
```

### Create Serial Port
The port instance is **Singleton Pattern**. Don't re-create port for same Com name.

```dart
final port = SerialPort("COM5", openNow: false, ByteSize: 8, ReadIntervalTimeout: 1, ReadTotalTimeoutConstant: 2);
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
port.readBytesOnListen(8, (value) => print(value.toString()));
// or
port.readBytesSize = 8;
port.readOnListenFunction = (value) {
  print(value);
};
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

### Flow Control

```dart
port.setFlowControlSignal(SerialPort.SETDTR);
port.setFlowControlSignal(SerialPort.CLRDTR);
```

### Close Serial Port

#### Close Without Listen

```dart
port.close();
```

#### Close On Listen

```dart
port.closeOnListen(
  onListen: () => print(port.isOpened),
)
  ..onError((err) {
    print(err);
  })
  ..onDone(() {
    print("is closed");
    print(port.isOpened);
  });
```

### Attention

If you want to read or write strings using serial, be careful to handle the terminator at the end.

Although in most cases, like "Hello\0" (68 65 6C 6C 6F 00) and "Hello"(68 65 6C 6C 6F) both can be identified by computer.

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
