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

### Get Ports with more messages (Experimental)

```dart
final List<PortInfo> ports = SerialPort.getPortsWithFullMessages();
print(ports); 
/// print [Port Name: COM3, FriendlyName: 蓝牙链接上的标准串行 (COM3), hardwareID: BTHENUM\{00001101-0000-1000-8000-00803f9b55fb}_LOCALMFG&0000, manufactureName: Microsoft]
PortInfo({
required this.portName,
required this.friendlyName,
required this.hardwareID,
required this.manufactureName,
});
```

### Create Serial Port Instance

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
print(await port.readBytesUntil(Uint8List.fromList("T".codeUnits))); /// '\0' is not included
/// or
var read = port.readBytes(18, timeout: Duration(milliseconds: 10)).then((onValue) => print(onValue));
await read;
/// or
var fixedBytesRead = port.readFixedSizeBytes(2).then((onValue) => print(onValue));
await fixedBytesRead;
/// see more in small example
};
```

### Write

#### Write String

```dart
String buffer = "hello";
await port.writeBytesFromString(buffer, includeZeroTerminator: false, stringConverter: StringConverter.nativeUtf8);
```

#### Write Uint8List

```dart
final uint8_data = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
print(await port.writeBytesFromUint8List(uint8_data));
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

### Some Examples

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

void _send() async {
  if (!port.isOpened) {
    port.open();
  }

  print('⬇---------------------------- read');
  await port.writeBytesFromString("😄我AT", includeZeroTerminator: false, stringConverter: StringConverter.nativeUtf8);
  var read = port.readBytes(18, timeout: Duration(milliseconds: 10)).then((onValue) => print(onValue));
  await Future.delayed(Duration(milliseconds: 5));
  await port.writeBytesFromString("😄我AT", includeZeroTerminator: false, stringConverter: StringConverter.nativeUtf8);

  await read;
  print('⬇---------------------------- time out read, read all data in queue (<= 18 bytes)');
  await port.writeBytesFromString("😄AT", includeZeroTerminator: false, stringConverter: StringConverter.nativeUtf8);
  var timeOutRead = port.readBytes(18, timeout: Duration(milliseconds: 10)).then((onValue) => print(onValue));
  await port.writeBytesFromString("😄我AT", includeZeroTerminator: false, stringConverter: StringConverter.nativeUtf8);

  await timeOutRead;

  print('⬇---------------------------- read successful without timeout, but want 8 bytes');
  await port.writeBytesFromString("😄AT", includeZeroTerminator: false, stringConverter: StringConverter.nativeUtf8);
  var wantedBytesRead = port.readBytes(8, timeout: Duration(milliseconds: 10)).then((onValue) => print(onValue));
  await port.writeBytesFromString("😄我AT", includeZeroTerminator: false, stringConverter: StringConverter.nativeUtf8);

  await wantedBytesRead;

  print('⬇---------------------------- read until specified fixed size (8 bytes), may cause deadlock');
  await port.writeBytesFromString("😄AT", includeZeroTerminator: false, stringConverter: StringConverter.nativeUtf8);
  var fixedBytesRead = port.readFixedSizeBytes(2).then((onValue) => print(onValue));
  await port.writeBytesFromString("😄我AT", includeZeroTerminator: false, stringConverter: StringConverter.nativeUtf8);

  await fixedBytesRead;

  port.close();
}
```
