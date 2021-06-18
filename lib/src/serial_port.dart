import 'dart:ffi';
import 'dart:typed_data';

import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';

class SerialPort {
  final String portName;
  final LPWSTR _portNameUtf16;

  /// DCB struct
  final dcb = calloc<DCB>();

  final commTimeouts = calloc<COMMTIMEOUTS>();

  int? handler;

  Pointer<DWORD> bytesRead = calloc<DWORD>();

  Pointer<OVERLAPPED> over = calloc<OVERLAPPED>();

  static final Map<String, SerialPort> _cache = <String, SerialPort>{};

  factory SerialPort(String portName) {
    return _cache.putIfAbsent(
        portName, () => SerialPort._internal(portName, TEXT(portName)));
  }

  SerialPort._internal(this.portName, this._portNameUtf16) {
    handler = CreateFile(_portNameUtf16, GENERIC_READ | GENERIC_WRITE, 0,
        nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);

    if (handler == INVALID_HANDLE_VALUE) {
      final lastError = GetLastError();
      if (lastError == ERROR_FILE_NOT_FOUND) {
        Exception(_portNameUtf16.toDartString() + "不可用");
      } else {
        Exception('get ${lastError}');
      }
      Exception("handler error");
      return;
    }

    initDCB();

    /// Timeout setting
    commTimeouts.ref.ReadIntervalTimeout = 10;
    commTimeouts.ref.ReadTotalTimeoutConstant = 1;
    commTimeouts.ref.ReadTotalTimeoutMultiplier = 0;
    SetCommTimeouts(handler!, commTimeouts);
  }

  void initDCB() {
    /// [dcb] parameters initialize
    /// default BaudRate is 115200
    dcb.ref.BaudRate = 115200;

    dcb.ref.ByteSize = 8;

    dcb.ref.StopBits = 1;

    dcb.ref.Parity = 0;

    /// [setCommState] must be called when setting dcb parameters
    setCommState();
  }

  void setCommState() {
    if (SetCommState(handler!, dcb) == 0) {
      Exception('SetCommState error');
      return;
    } else {
      PurgeComm(handler!, 0x0008 | 0x0004);
    }
  }

  // ignore: non_constant_identifier_names
  set BaudRate(int rate) {
    dcb.ref.BaudRate = rate;
    setCommState();
  }

  // ignore: non_constant_identifier_names
  set ByteSize(int size) {
    dcb.ref.ByteSize = size;
    setCommState();
  }

  // ignore: non_constant_identifier_names
  set StopBits(int stopBits) {
    dcb.ref.StopBits = stopBits;
    setCommState();
  }

  // ignore: non_constant_identifier_names
  set Parity(int parity) {
    dcb.ref.Parity = parity;
    setCommState();
  }

  Future<Uint8List> readBytes(int bytesSize) async {
    final lpBuffer = calloc<Uint16>(bytesSize);
    ReadFile(handler!, lpBuffer, bytesSize, bytesRead, over);
    return lpBuffer.asTypedList(bytesSize).buffer.asUint8List();
  }

  static List<String> getAvailablePorts() {
    /// availablePorts String list
    List<String> portsList = [];

    final hKeyPtr = calloc<IntPtr>();
    final keyPath = TEXT("HARDWARE\\DEVICEMAP\\SERIALCOMM");

    if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, keyPath, 0, KEY_READ, hKeyPtr) !=
        ERROR_SUCCESS) {
      RegCloseKey(hKeyPtr.value);
      Exception("can't open Register");
      return portsList;
    }

    int status = ERROR_SUCCESS;

    /// The index of the value to be retrieved.
    /// This parameter should be zero for the first call to the RegEnumValue function and then be incremented for subsequent calls.
    int dwIndex = 0;

    /// lpValueName
    /// A pointer to a buffer that receives the name of the value as a null-terminated string.
    /// This buffer must be large enough to include the terminating null character.
    final lpValueName = wsalloc(MAX_PATH);

    /// lpcchValueName
    /// A pointer to a variable that specifies the size of the buffer pointed to by the lpValueName parameter
    final lpcchValueName = calloc<Uint32>();
    lpcchValueName.value = MAX_PATH;

    /// A pointer to a variable that receives a code indicating the type of data stored in the specified value.
    final lpType = calloc<Uint32>();

    /// A pointer to a buffer that receives the data for the value entry.
    /// This parameter can be NULL if the data is not required.
    Pointer<Uint8> lpData = calloc<Uint8>();

    /// lpcbData
    /// A pointer to a variable that specifies the size of the buffer pointed to by the lpData parameter, in bytes.
    /// When the function returns, the variable receives the number of bytes stored in the buffer.
    var lpcbData = calloc<DWORD>();
    lpcbData.value = MAX_PATH;

    while (status != ERROR_NO_MORE_ITEMS) {
      status = RegEnumValue(hKeyPtr.value, dwIndex++, lpValueName,
          lpcchValueName, nullptr, lpType, lpData, lpcbData);

      switch (status) {
        case ERROR_SUCCESS:
          Pointer<Utf8> str = wsalloc(1000).cast();
          WideCharToMultiByte(
              0, 0, lpData.cast(), -1, str, MAX_PATH, nullptr, nullptr);
          // portsList.add(String.fromCharCodes(lpData.asTypedList(8)));
          portsList.add(str.toDartString());
          break;
        case ERROR_MORE_DATA:
          Exception("ERROR_MORE_DATA");
          break;
        default:
          break;
      }
      // lpValueName = wsalloc(1000);
      // lpcchValueName = calloc<Uint32>();
      // free(lpcbData);
      // free(lpValueName);
      // lpValueName = wsalloc(MAX_PATH);
      // lpcbData = calloc<DWORD>();
    }
    RegCloseKey(hKeyPtr.value);
    return portsList;
  }

  void close() {
    CloseHandle(handler!);
  }
}
