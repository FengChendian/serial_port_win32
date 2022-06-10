import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';

class SerialPort {
  /// [portName] like COM3
  final String portName;

  /// just a native string
  final LPWSTR _portNameUtf16;

  /// [dcb] is win32 [DCB] struct
  final dcb = calloc<DCB>();

  /// win32 [COMMTIMEOUTS] struct
  final commTimeouts = calloc<COMMTIMEOUTS>();

  /// file handle
  /// [handler] will be [INVALID_HANDLE_VALUE] if failed
  int? handler;

  Pointer<DWORD> _bytesRead = calloc<DWORD>();

  Pointer<OVERLAPPED> _over = calloc<OVERLAPPED>();

  /// EventMask
  Pointer<DWORD> _dwCommEvent = calloc<DWORD>();

  /// erros
  final _errors = calloc<DWORD>();

  /// staus
  final _status = calloc<COMSTAT>();

  /// [_keyPath] is registry path which will be oepned
  static final _keyPath = TEXT("HARDWARE\\DEVICEMAP\\SERIALCOMM");

  /// [isOpened] is true when port was opened, [CreateFile] function will open a port.
  bool _isOpened = false;

  bool get isOpened => _isOpened;

  static final Map<String, SerialPort> _cache = <String, SerialPort>{};

  /// stream data
  late Stream<Uint8List> _readStream;

  /// [readOnListenFunction] define what  to do when data comming
  Function(Uint8List value) readOnListenFunction = (value) {};

  /// [readOnBeforeFunction] define what  to do when data comming
  Function() readOnBeforeFunction = () {};

  /// read data which has size [_readBytesSize]
  int _readBytesSize = 1;

  /// using [readBytesSize] setting [_readBytesSize]
  set readBytesSize(int value) {
    _readBytesSize = value;
  }

  /// [EV_RXCHAR]
  /// A character was received and placed in the input buffer.
  static const int EV_RXCHAR = 0x0001;

  /// [ERROR_IO_PENDING]
  /// Overlapped I/O operation is in progress.
  static const int ERROR_IO_PENDING = 997;

  /// [CLRDTR]
  /// Clears the DTR (data-terminal-ready) signal.
  static const int CLRDTR = 6;

  /// [CLRRTS]
  /// Clears the RTS (request-to-send) signal.
  static const int CLRRTS = 4;

  /// [SETDTR]
  /// Sends the DTR (data-terminal-ready) signal.
  static const int SETDTR = 5;

  /// [SETRTS]
  /// Sends the RTS (request-to-send) signal.
  static const int SETRTS = 3;

  /// reusable instance using [factory]
  factory SerialPort(
    String portName, {
    // ignore: non_constant_identifier_names
    int BaudRate = CBR_115200,
    // ignore: non_constant_identifier_names
    int Parity = NOPARITY,
    // ignore: non_constant_identifier_names
    int StopBits = ONESTOPBIT,
    // ignore: non_constant_identifier_names
    int ByteSize = 8,
    // ignore: non_constant_identifier_names
    int ReadIntervalTimeout = 10,
    // ignore: non_constant_identifier_names
    int ReadTotalTimeoutConstant = 1,
    // ignore: non_constant_identifier_names
    int ReadTotalTimeoutMultiplier = 0,

    /// if you want open port when create instance, set [openNow] true
    bool openNow = true,
  }) {
    return _cache.putIfAbsent(
        portName,
        () => SerialPort._internal(
              portName,
              TEXT('\\\\.\\$portName'),
              BaudRate: BaudRate,
              Parity: Parity,
              StopBits: StopBits,
              ByteSize: ByteSize,
              ReadIntervalTimeout: ReadIntervalTimeout,
              ReadTotalTimeoutConstant: ReadTotalTimeoutConstant,
              ReadTotalTimeoutMultiplier: ReadTotalTimeoutMultiplier,
              openNow: openNow,
            ));
  }

  SerialPort._internal(
    this.portName,
    this._portNameUtf16, {
    // ignore: non_constant_identifier_names
    required int BaudRate,
    // ignore: non_constant_identifier_names
    required int Parity,
    // ignore: non_constant_identifier_names
    required int StopBits,
    // ignore: non_constant_identifier_names
    required int ByteSize,
    // ignore: non_constant_identifier_names
    required int ReadIntervalTimeout,
    // ignore: non_constant_identifier_names
    required int ReadTotalTimeoutConstant,
    // ignore: non_constant_identifier_names
    required int ReadTotalTimeoutMultiplier,
    required bool openNow,
  }) {
    dcb
      ..ref.BaudRate = BaudRate
      ..ref.Parity = Parity
      ..ref.StopBits = StopBits
      ..ref.ByteSize = ByteSize;
    commTimeouts
      ..ref.ReadIntervalTimeout = 10
      ..ref.ReadTotalTimeoutMultiplier = 10
      ..ref.ReadTotalTimeoutConstant = 1;
    if (openNow) {
      open();
    }
  }

  /// [open] can be called when handler is null or handler is closed
  void open() {
    if (_isOpened == false) {
      handler = CreateFile(_portNameUtf16, GENERIC_READ | GENERIC_WRITE, 0,
          nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, NULL);

      if (handler == INVALID_HANDLE_VALUE) {
        final lastError = GetLastError();
        if (lastError == ERROR_FILE_NOT_FOUND) {
          throw Exception(_portNameUtf16.toDartString() + "is not available");
        } else {
          throw Exception('Last error is $lastError');
        }
      }

      _setCommState();

      _setCommTimeouts();

      _isOpened = true;

      if (SetCommMask(handler!, EV_RXCHAR) == 0) {
        throw Exception('SetCommMask error');
      }
      _createEvent();

      _readStream = _lookUpEvent(Duration(milliseconds: 1));
      _readStream.listen((event) {
        readOnListenFunction(event);
      });
    } else {
      throw Exception('Port is opened');
    }
  }

  /// look up I/O event and read data using stream
  Stream<Uint8List> _lookUpEvent(Duration interval) async* {
    int event = 0;
    Uint8List data;
    PurgeComm(handler!, PURGE_RXCLEAR | PURGE_TXCLEAR);
    while (true) {
      await Future.delayed(interval);
      event = WaitCommEvent(handler!, _dwCommEvent, _over);
      if (event != 0) {
        ClearCommError(handler!, _errors, _status);
        if (_status.ref.cbInQue < _readBytesSize) {
          data = await _read(_status.ref.cbInQue);
        } else {
          data = await _read(_readBytesSize);
        }
        if (data.isNotEmpty) {
          yield data;
        }
      } else {
        if (GetLastError() == ERROR_IO_PENDING) {
          for (int i = 0; i < 500; i++) {
            if (WaitForSingleObject(_over.ref.hEvent, 0) == 0) {
              ClearCommError(handler!, _errors, _status);
              if (_status.ref.cbInQue < _readBytesSize) {
                data = await _read(_status.ref.cbInQue);
              } else {
                data = await _read(_readBytesSize);
              }
              if (data.isNotEmpty) {
                yield data;
              }
              ResetEvent(_over.ref.hEvent);
              break;
            }
            ResetEvent(_over.ref.hEvent);
            await Future.delayed(interval);
          }
        }
      }
    }
  }

  /// if you want open a port with some extra settings, use [openWithSettings]
  void openWithSettings({
    // ignore: non_constant_identifier_names
    int BaudRate = CBR_115200,
    // ignore: non_constant_identifier_names
    int Parity = NOPARITY,
    // ignore: non_constant_identifier_names
    int StopBits = ONESTOPBIT,
    // ignore: non_constant_identifier_names
    int ByteSize = 8,
    // ignore: non_constant_identifier_names
    int ReadIntervalTimeout = 10,
    // ignore: non_constant_identifier_names
    int ReadTotalTimeoutConstant = 1,
    // ignore: non_constant_identifier_names
    int ReadTotalTimeoutMultiplier = 0,
  }) {
    dcb
      ..ref.BaudRate = BaudRate
      ..ref.Parity = Parity
      ..ref.StopBits = StopBits
      ..ref.ByteSize = ByteSize;
    commTimeouts
      ..ref.ReadIntervalTimeout = 10
      ..ref.ReadTotalTimeoutConstant = 1
      ..ref.ReadTotalTimeoutMultiplier = 0;
    open();
  }

  /// When [dcb] struct is changed, you must call [_setCommState] to update settings.
  void _setCommState() {
    if (SetCommState(handler!, dcb) == FALSE) {
      throw Exception('SetCommState error');
    } else {
      PurgeComm(handler!, PURGE_RXCLEAR | PURGE_TXCLEAR);
    }
  }

  /// When [commTimeouts] struct is changed, you must call [_setCommTimeouts] to update settings.
  void _setCommTimeouts() {
    if (SetCommTimeouts(handler!, commTimeouts) == FALSE) {
      throw Exception('SetCommTimeouts error');
    }
  }

  /// CreateEvent for overlapped I/O
  /// Initialize the rest of the OVERLAPPED structure
  void _createEvent() {
    _over.ref.hEvent = CreateEvent(nullptr, TRUE, FALSE, nullptr);
    _over
      ..ref.Internal = 0
      ..ref.InternalHigh = 0;
  }

  // set serial port [BaudRate]
  /// using standard win32 Value like [CBR_115200]
  // ignore: non_constant_identifier_names
  set BaudRate(int rate) {
    dcb.ref.BaudRate = rate;
    _setCommState();
  }

  /// data byteSize
  // ignore: non_constant_identifier_names
  set ByteSize(int size) {
    dcb.ref.ByteSize = size;
    _setCommState();
  }

  /// 1 stop bit is [ONESTOPBIT], value is 0
  /// more docs in https://docs.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-dcb
  // ignore: non_constant_identifier_names
  set StopBits(int stopBits) {
    dcb.ref.StopBits = stopBits;
    _setCommState();
  }

  /// You can use [NOPARITY], [ODDPARITY] and so on like win32
  // ignore: non_constant_identifier_names
  set Parity(int parity) {
    dcb.ref.Parity = parity;
    _setCommState();
  }

  /// change [isOpened] value if necessary
  set openStatus(bool status) {
    _isOpened = status;
  }

  /// [ReadIntervalTimeout]
  ///
  /// The maximum time allowed to elapse before the arrival of the next byte on the communications line,
  /// in milliseconds. If the interval between the arrival of any two bytes exceeds this amount,
  /// the ReadFile operation is completed and any buffered data is returned.
  /// A value of zero indicates that interval time-outs are not used.
  ///
  // ignore: non_constant_identifier_names
  set ReadIntervalTimeout(int readIntervalTimeout) {
    commTimeouts.ref.ReadTotalTimeoutConstant = readIntervalTimeout;
    _setCommTimeouts();
  }

  /// [ReadTotalTimeoutMultiplier]
  ///
  /// The multiplier used to calculate the total time-out period for read operations, in milliseconds.
  /// For each read operation, this value is multiplied by the requested number of bytes to be read
  ///
  // ignore: non_constant_identifier_names
  set ReadTotalTimeoutMultiplier(int readTotalTimeoutMultiplier) {
    commTimeouts.ref.ReadTotalTimeoutMultiplier = readTotalTimeoutMultiplier;
    _setCommTimeouts();
  }

  /// A constant used to calculate the total time-out period for read operations, in milliseconds.
  /// For each read operation, this value is added to the product of the [ReadTotalTimeoutMultiplier]
  /// member and the requested number of bytes.
  ///
  /// A value of zero for both the [ReadTotalTimeoutMultiplier] and [ReadTotalTimeoutConstant] members
  /// indicates that total time-outs are not used for read operations.
  ///
  // ignore: non_constant_identifier_names
  set ReadTotalTimeoutConstant(int readTotalTimeoutConstant) {
    commTimeouts.ref.ReadTotalTimeoutConstant = readTotalTimeoutConstant;
    _setCommTimeouts();
  }

  /// [WriteTotalTimeoutMultiplier]
  ///
  /// The multiplier used to calculate the total time-out period for write operations, in milliseconds.
  /// For each write operation, this value is multiplied by the number of bytes to be written.
  ///
  // ignore: non_constant_identifier_names
  set WriteTotalTimeoutMultiplier(int writeTotalTimeoutMultiplier) {
    commTimeouts.ref.WriteTotalTimeoutMultiplier = writeTotalTimeoutMultiplier;
    _setCommTimeouts();
  }

  /// [WriteTotalTimeoutConstant]
  ///
  /// A constant used to calculate the total time-out period for write operations, in milliseconds.
  /// For each write operation, this value is added to the product of the WriteTotalTimeoutMultiplier
  /// member and the number of bytes to be written.
  ///
  /// A value of zero for both the WriteTotalTimeoutMultiplier and WriteTotalTimeoutConstant
  /// members indicates that total time-outs are not used for write operations.
  ///
  // ignore: non_constant_identifier_names
  set WriteTotalTimeoutConstant(int writeTotalTimeoutConstant) {
    commTimeouts.ref.WriteTotalTimeoutConstant = writeTotalTimeoutConstant;
    _setCommTimeouts();
  }

  /// [setFlowControlSignal] can set DTR and RTS signal
  /// Controlling DTR and RTS
  void setFlowControlSignal(int flag) {
    EscapeCommFunction(handler!, flag);
  }

  /// [_read] is a fundamental read function/
  Future<Uint8List> _read(int bytesSize) async {
    final lpBuffer = calloc<Uint16>(bytesSize);
    Uint8List uint8list;

    try {
      readOnBeforeFunction();
      ReadFile(handler!, lpBuffer, bytesSize, _bytesRead, _over);
    } finally {
      /// Uint16 need to be casted for real Uint8 data
      var u8l = lpBuffer.cast<Uint8>().asTypedList(_bytesRead.value);
      uint8list = Uint8List.fromList(u8l);
      free(lpBuffer);
    }

    return uint8list;
  }

  /// [readBytesOnce] read data only once.
  Future<Uint8List> readBytesOnce(int bytesSize) async {
    return _read(bytesSize);
  }

  /// [readBytesOnListen] can constantly listen data, you can use [onData] to get data.
  void readBytesOnListen(int bytesSize, Function(Uint8List value) onData,
      {void onBefore()?}) {
    _readBytesSize = bytesSize;
    readOnListenFunction = onData;
    readOnBeforeFunction = onBefore ?? () {};
  }

  /// [writeBytesFromString] will convert String to ANSI Code corresponding to char
  /// Serial devices can receive ANSI code
  /// if you write "hello" in String, device will get "hello\0" with "\0" automatically.
  bool writeBytesFromString(String buffer) {
    final lpBuffer = buffer.toANSI();
    final lpNumberOfBytesWritten = calloc<DWORD>();
    try {
      if (WriteFile(handler!, lpBuffer, lpBuffer.length + 1,
              lpNumberOfBytesWritten, _over) !=
          TRUE) {
        return _getOverlappedResult(handler!, _over, lpNumberOfBytesWritten);
      }
      return true;
    } finally {
      free(lpBuffer);
      free(lpNumberOfBytesWritten);
    }
  }

  /// [writeBytesFromUint8List] will write Uint8List directly, please ensure the last
  /// of list is 0 terminator if you want to convert it to char.
  bool writeBytesFromUint8List(Uint8List uint8list) {
    final lpBuffer = uint8list.allocatePointer();
    final lpNumberOfBytesWritten = calloc<DWORD>();
    try {
      if (WriteFile(handler!, lpBuffer, uint8list.length,
              lpNumberOfBytesWritten, _over) !=
          TRUE) {
        /// Overlapped will cause IO_PENDING
        return _getOverlappedResult(handler!, _over, lpNumberOfBytesWritten);
      }
      return true;
    } finally {
      free(lpBuffer);
      free(lpNumberOfBytesWritten);
    }
  }

  /// [_getOverlappedResult] will get write result in non-blocking mode
  /// 500 ms
  bool _getOverlappedResult(int handler, Pointer<OVERLAPPED> lpOverlapped,
      Pointer<Uint32> lpNumberOfBytesTransferred){
    for (int i = 0; i < 500; i++) {
      Future.delayed(Duration(milliseconds: 1));
      if (GetOverlappedResult(handler, _over, lpNumberOfBytesTransferred, 0) ==
          TRUE) {
        return true;
      }
    }
    return false;
  }

  /// [_getRegistryKeyValue] will open RegistryKey in Serial Path.
  static int _getRegistryKeyValue() {
    final hKeyPtr = calloc<IntPtr>();
    try {
      if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, _keyPath, 0, KEY_READ, hKeyPtr) !=
          ERROR_SUCCESS) {
        RegCloseKey(hKeyPtr.value);
        throw Exception("can't open Register");
      }
      return hKeyPtr.value;
    } finally {
      free(hKeyPtr);
    }
  }

  static String? _enumerateKey(int hKey, int dwIndex) {
    /// [lpValueName]
    /// A pointer to a buffer that receives the name of the value as a null-terminated string.
    /// This buffer must be large enough to include the terminating null character.
    final lpValueName = wsalloc(MAX_PATH);

    /// [lpcchValueName]
    /// A pointer to a variable that specifies the size of the buffer pointed to by the lpValueName parameter
    final lpcchValueName = calloc<DWORD>();
    lpcchValueName.value = MAX_PATH;

    /// A pointer to a variable that receives a code indicating the type of data stored in the specified value.
    final lpType = calloc<DWORD>();

    /// A pointer to a buffer that receives the data for the value entry.
    /// This parameter can be NULL if the data is not required.
    final lpData = calloc<BYTE>(MAX_PATH);

    /// [lpcbData]
    /// A pointer to a variable that specifies the size of the buffer pointed to by the lpData parameter, in bytes.
    /// When the function returns, the variable receives the number of bytes stored in the buffer.
    final lpcbData = calloc<DWORD>();
    lpcbData.value = MAX_PATH;

    try {
      final status = RegEnumValue(hKey, dwIndex, lpValueName, lpcchValueName,
          nullptr, lpType, lpData, lpcbData);

      switch (status) {
        case ERROR_SUCCESS:
          return lpData.cast<Utf16>().toDartString();
        case ERROR_MORE_DATA:
          throw Exception("ERROR_MORE_DATA");
        case ERROR_NO_MORE_ITEMS:
          return null;
        default:
          throw Exception("Unknown error!");
      }
    } finally {
      /// free all pointer
      free(lpValueName);
      free(lpcchValueName);
      free(lpType);
      free(lpData);
      free(lpcbData);
    }
  }

  /// read Registry in Windows to get ports
  /// [getAvailablePorts] can be called using SerialPort.getAvailablePorts()
  static List<String> getAvailablePorts() {
    /// availablePorts String list
    List<String> portsList = [];

    final hKey = _getRegistryKeyValue();

    /// The index of the value to be retrieved.
    /// This parameter should be zero for the first call to the RegEnumValue function and then be incremented for subsequent calls.
    int dwIndex = 0;

    String? item;
    item = _enumerateKey(hKey, dwIndex);
    if (item == null) {
      portsList.add('');
    }

    while (item != null) {
      portsList.add(item);
      dwIndex++;
      item = _enumerateKey(hKey, dwIndex);
    }

    RegCloseKey(hKey);

    return portsList;
  }

  /// [close] port which was opened
  void close() {
    CloseHandle(handler!);
    _isOpened = false;
  }

  /// [closeOnListen[ let you can close onListen function before closing port and
  /// using onError or onDone when port is closed.
  StreamSubscription closeOnListen({required Function() onListen}) {
    ///定义一个Controller
    final _closeController = StreamController<String>(
      onListen: onListen,
    );
    final _closeSink = _closeController.sink;

    ///事件订阅对象
    StreamSubscription _closeSubscription =
        _closeController.stream.listen((event) {});
    try {
      CloseHandle(handler!);
      _isOpened = false;
    } catch (e) {
      _closeSink.addError(e.toString());
    } finally {
      _closeSink.close();
      _closeController.close();
    }
    return _closeSubscription;
  }
}
