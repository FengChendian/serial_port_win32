import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';
import 'package:collection/collection.dart';

enum StringConverter {
  nativeUtf8,
  ANSI,
}

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
  /// [handler] will be [INVALID_HANDLE_VALUE] if function is failed
  int? handler;

  Pointer<DWORD> _bytesRead = calloc<DWORD>();

  Pointer<OVERLAPPED> _over = calloc<OVERLAPPED>();

  /// EventMask
  Pointer<DWORD> _dwCommEvent = calloc<DWORD>();

  /// errors
  final _errors = calloc<DWORD>();

  /// status
  final _status = calloc<COMSTAT>();

  /// [_keyPath] is registry path which will be opened
  static final _keyPath = TEXT("HARDWARE\\DEVICEMAP\\SERIALCOMM");

  /// [isOpened] is true when port was opened, [CreateFile] function will open a port.
  bool _isOpened = false;

  bool get isOpened => _isOpened;

  static final Map<String, SerialPort> _cache = <String, SerialPort>{};

  /// [readOnBeforeFunction] define what  to do when data coming
  /// a byte will cause a callback
  Function() readOnBeforeFunction = () {};

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
    int Parity = DCB_PARITY.NOPARITY,
    // ignore: non_constant_identifier_names
    int StopBits = DCB_STOP_BITS.ONESTOPBIT,
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
    /// Do not open a port which has been opened
    if (_isOpened == false) {
      handler = CreateFile(
          _portNameUtf16,
          GENERIC_ACCESS_RIGHTS.GENERIC_READ |
              GENERIC_ACCESS_RIGHTS.GENERIC_WRITE,
          0,
          nullptr,
          FILE_CREATION_DISPOSITION.OPEN_EXISTING,
          FILE_FLAGS_AND_ATTRIBUTES.FILE_FLAG_OVERLAPPED,
          NULL);

      if (handler == INVALID_HANDLE_VALUE) {
        final lastError = GetLastError();
        if (lastError == WIN32_ERROR.ERROR_FILE_NOT_FOUND) {
          throw Exception(_portNameUtf16.toDartString() + "is not available");
        } else {
          throw Exception('Open port failed, win32 error code is $lastError');
        }
      }

      _setCommState();

      _setCommTimeouts();

      _isOpened = true;

      if (SetCommMask(handler!, COMM_EVENT_MASK.EV_RXCHAR) == 0) {
        throw Exception('SetCommMask error');
      }
      _createEvent();
    } else {
      throw Exception('Port has been opened');
    }
  }

  /// if you want open a port with some extra settings, use [openWithSettings]
  void openWithSettings({
    // ignore: non_constant_identifier_names
    int BaudRate = CBR_115200,
    // ignore: non_constant_identifier_names
    int Parity = DCB_PARITY.NOPARITY,
    // ignore: non_constant_identifier_names
    int StopBits = DCB_STOP_BITS.ONESTOPBIT,
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
      PurgeComm(handler!,
          PURGE_COMM_FLAGS.PURGE_RXCLEAR | PURGE_COMM_FLAGS.PURGE_TXCLEAR);
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

  /// 1 stop bit is [DCB_STOP_BITS.ONESTOPBIT], value is 0
  /// more docs in https://docs.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-dcb
  // ignore: non_constant_identifier_names
  set StopBits(int stopBits) {
    dcb.ref.StopBits = stopBits;
    _setCommState();
  }

  /// You can use [DCB_PARITY.NOPARITY], [DCB_PARITY.ODDPARITY] and so on like win32
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

  /// [_read] is a fundamental read function
  Future<Uint8List> _read(int bytesSize) async {
    final lpBuffer = calloc<Uint8>(bytesSize);
    Uint8List uint8list;
    try {
      readOnBeforeFunction();
      ReadFile(handler!, lpBuffer, bytesSize, _bytesRead, _over);
    } finally {
      /// Uint16 need to be casted for real Uint8 data
      var u8l = lpBuffer.asTypedList(_bytesRead.value);

      /// Copy data
      uint8list = Uint8List.fromList(u8l);
      free(lpBuffer);
    }

    return uint8list;
  }

  /// [_getDataSizeInQueue] will return received data size in queue
  Future<int> _getDataSizeInQueue(
      {Duration dataPollingInterval =
          const Duration(microseconds: 500)}) async {
    int event = 0;

    while (true) {
      event = WaitCommEvent(handler!, _dwCommEvent, _over);
      if (event != FALSE) {
        ClearCommError(handler!, _errors, _status);
        return _status.ref.cbInQue;
      } else {
        if (GetLastError() == WIN32_ERROR.ERROR_IO_PENDING) {
          if (WaitForSingleObject(_over.ref.hEvent, 0) == 0) {
            ClearCommError(handler!, _errors, _status);
            var cbInQue = _status.ref.cbInQue;
            ResetEvent(_over.ref.hEvent);
            return cbInQue;
          } else {
            ResetEvent(_over.ref.hEvent);
          }
        } else {
          /// Fallback
        }
      }
      await Future.delayed(dataPollingInterval);
    }
  }

  /// [readFixedSizeBytes] will always read until readData.length == bytesSize.
  /// [dataPollingInterval] is used for await to execute UI, default set to 500 μs.
  Future<Uint8List> readFixedSizeBytes(int bytesSize,
      {Duration dataPollingInterval =
          const Duration(microseconds: 500)}) async {
    int event = 0;
    List<int> readData = List<int>.empty(growable: true);

    while (true) {
      event = WaitCommEvent(handler!, _dwCommEvent, _over);
      if (event != FALSE) {
        ClearCommError(handler!, _errors, _status);
        if (_status.ref.cbInQue != 0) {
          readData.add((await _read(1))[0]);
        } else {
          /// do nothing
        }
      } else {
        if (GetLastError() == WIN32_ERROR.ERROR_IO_PENDING) {
          if (WaitForSingleObject(_over.ref.hEvent, 0) == 0) {
            ClearCommError(handler!, _errors, _status);
            if (_status.ref.cbInQue != 0) {
              readData.add((await _read(1))[0]);
            } else {
              /// do nothing
            }
            ResetEvent(_over.ref.hEvent);
          } else {
            ResetEvent(_over.ref.hEvent);
          }
        } else {
          /// Fallback
        }
      }

      if (readData.length == bytesSize) {
        break;
      }
      await Future.delayed(dataPollingInterval);
    }
    return Uint8List.fromList(readData);
  }

  /// If [timeout] is none, will read until specified [bytesSize], same as [readFixedSizeBytes] (may cause deadlock).
  /// Or read until [timeout] or specified [bytesSize]
  Future<Uint8List> readBytes(int bytesSize,
      {required Duration? timeout}) async {
    if (timeout == null) {
      return readFixedSizeBytes(bytesSize);
    } else {
      final timeoutTimer = Timer(timeout, () {});

      final completer = Completer<int>();

      // ignore: unused_local_variable
      final readTimer =
          Timer.periodic(Duration(microseconds: 100), (timer) async {
        var currentSize = await _getDataSizeInQueue();
        if (currentSize == bytesSize || !timeoutTimer.isActive) {
          completer.complete(currentSize);
          timer.cancel();
        }
      });
      final dataSizeInQueue = await completer.future;
      return readFixedSizeBytes(
          dataSizeInQueue <= bytesSize ? dataSizeInQueue : bytesSize);
    }
  }

  /// [readBytesUntil] will read until an [expected] sequence is found
  Future<Uint8List> readBytesUntil(
    Uint8List expectedList, {
    Duration dataPollingInterval = const Duration(microseconds: 500),
  }) async {
    int event = 0;
    List<int> readData = List<int>.empty(growable: true);

    final expected = expectedList.toList(growable: false);
    final expectedListLength = expected.length;

    while (true) {
      event = WaitCommEvent(handler!, _dwCommEvent, _over);
      if (event != FALSE) {
        ClearCommError(handler!, _errors, _status);
        if (_status.ref.cbInQue != 0) {
          readData.add((await _read(1))[0]);
        } else {
          /// do nothing
        }
      } else {
        if (GetLastError() == WIN32_ERROR.ERROR_IO_PENDING) {
          /// wait io complete, timeout in 500ms
          for (int i = 0; i < 1000; i++) {
            if (WaitForSingleObject(_over.ref.hEvent, 0) == 0) {
              ClearCommError(handler!, _errors, _status);
              if (_status.ref.cbInQue != 0) {
                readData.add((await _read(1))[0]);
              } else {}
              ResetEvent(_over.ref.hEvent);
              // break for next read operation.
              break;
            } else {
              ResetEvent(_over.ref.hEvent);
              // continue waiting
              await Future.delayed(dataPollingInterval);
            }
          }
        } else {
          /// Fallback
        }
      }
      if (readData.length < expectedListLength) {
        continue;
      } else {
        if (ListEquality<int>().equals(
            readData.sublist(readData.length - expectedListLength), expected)) {
          return Uint8List.fromList(readData);
        } else {
          await Future.delayed(dataPollingInterval);
          continue;
        }
      }
    }
  }

  /// [writeBytesFromString] will convert String to ANSI Code corresponding to char
  ///
  /// if you write "hello" in String, PC will send "hello\0" with "\0" automatically when set includeZeroTerminator true.
  ///
  /// - Unit of [timeout] is ms
  /// [stringConverter] decides how to convert your string to uint8 code unit
  Future<bool> writeBytesFromString(String buffer,
      {int timeout = 500,
      required bool includeZeroTerminator,
      StringConverter stringConverter = StringConverter.nativeUtf8}) async {
    /// convert dart string to code unit array
    final Pointer<Utf8> lpBuffer;
    final lpNumberOfBytesWritten = calloc<DWORD>();
    final int length;

    if (stringConverter == StringConverter.nativeUtf8) {
      lpBuffer = buffer.toNativeUtf8();
    } else {
      lpBuffer = buffer.toANSI();
    }

    if (includeZeroTerminator == true) {
      length = lpBuffer.length + 1;
    } else {
      length = lpBuffer.length;
    }

    try {
      if (WriteFile(handler!, lpBuffer.cast<Uint8>(), length,
              lpNumberOfBytesWritten, _over) !=
          TRUE) {
        return _getOverlappedResult(
            handler!, _over, lpNumberOfBytesWritten, timeout);
      }
      return true;
    } finally {
      free(lpBuffer);
      free(lpNumberOfBytesWritten);
    }
  }

  /// [writeBytesFromUint8List] will write Uint8List directly, please ensure the last
  /// of list is 0 terminator if you want to convert it to char.
  Future<bool> writeBytesFromUint8List(Uint8List uint8list,
      {int timeout = 500}) async {
    final lpBuffer = uint8list.allocatePointer();
    final lpNumberOfBytesWritten = calloc<DWORD>();

    try {
      if (WriteFile(handler!, lpBuffer, uint8list.length,
              lpNumberOfBytesWritten, _over) !=
          TRUE) {
        /// Overlapped will cause IO_PENDING
        return _getOverlappedResult(
            handler!, _over, lpNumberOfBytesWritten, timeout);
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
      Pointer<Uint32> lpNumberOfBytesTransferred, int timeout) {
    for (int i = 0; i < timeout; i++) {
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
    int lResult;
    try {
      lResult = RegOpenKeyEx(
          HKEY_LOCAL_MACHINE, _keyPath, 0, REG_SAM_FLAGS.KEY_READ, hKeyPtr);
      if (lResult != WIN32_ERROR.ERROR_SUCCESS) {
        // RegCloseKey(hKeyPtr.value);
        throw Exception("RegistryKeyValue Not Found");
      } else {
        return hKeyPtr.value;
      }
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
        case WIN32_ERROR.ERROR_SUCCESS:
          return lpData.cast<Utf16>().toDartString();
        case WIN32_ERROR.ERROR_MORE_DATA:
          throw Exception("ERROR_MORE_DATA");
        case WIN32_ERROR.ERROR_NO_MORE_ITEMS:
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
    final int hKey;

    /// Get registry key of Serial Port
    try {
      hKey = _getRegistryKeyValue();
    } on Exception {
      return List.empty();
    }

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

  /// Using [getPortsWithFullMessages] to get Serial Ports Info
  /// Parameter: {String classGUIDStr = GUID_DEVINTERFACE_COMPORT}, refer to https://learn.microsoft.com/en-us/windows-hardware/drivers/install/guid-devinterface-comport
  /// You can set classGUIDStr = GUID_DEVINTERFACE_USB_DEVICE
  /// return [PortInfo({
  ///     required this.portName,
  ///     required this.friendlyName,
  ///     required this.hardwareID,
  //     required this.manufactureName,
  ///   })];
  static List<PortInfo> getPortsWithFullMessages(
      {String classGUIDStr = GUID_DEVINTERFACE_COMPORT}) {
    /// Storage port information
    var portInfoLists = <PortInfo>[];

    /// Set Class GUID
    final classGUID = calloc<GUID>();
    classGUID.ref.setGUID(classGUIDStr);

    /// Get Device info handle
    final hDeviceInfo = SetupDiGetClassDevs(
        classGUID,
        nullptr,
        0,
        SETUP_DI_GET_CLASS_DEVS_FLAGS.DIGCF_DEVICEINTERFACE |
            SETUP_DI_GET_CLASS_DEVS_FLAGS.DIGCF_PRESENT);

    if (hDeviceInfo != INVALID_HANDLE_VALUE) {
      /// Init device info data
      final devInfoData = calloc<SP_DEVINFO_DATA>();
      devInfoData.ref.cbSize = sizeOf<SP_DEVINFO_DATA>();

      /// Enum device
      for (var i = 0;
          SetupDiEnumDeviceInfo(hDeviceInfo, i, devInfoData) == TRUE;
          i++) {
        /// Init [PortName] and [friendlyName] Pointer
        final portName = calloc<Uint8>(256);
        final pcbData = calloc<DWORD>()..value = 255;
        final friendlyName = calloc<BYTE>(256);
        final hardwareID = calloc<BYTE>(256);
        final manufactureName = calloc<BYTE>(256);

        /// [SP_DEVICE_INTERFACE_DATA] in dart
        // final deviceInterfaceData = calloc<SP_DEVICE_INTERFACE_DATA>();
        // deviceInterfaceData.ref.cbSize = sizeOf<SP_DEVICE_INTERFACE_DATA>();
        //
        // final deviceInterfaceDetailData =
        //     calloc<SP_DEVICE_INTERFACE_DETAIL_DATA_>(1024);
        // deviceInterfaceDetailData.ref.cbSize =
        //     sizeOf<SP_DEVICE_INTERFACE_DETAIL_DATA_>();

        try {
          var hDevKey = SetupDiOpenDevRegKey(
              hDeviceInfo,
              devInfoData,
              SETUP_DI_PROPERTY_CHANGE_SCOPE.DICS_FLAG_GLOBAL,
              0,
              DIREG_DEV,
              REG_SAM_FLAGS.KEY_READ);

          if (hDevKey != INVALID_HANDLE_VALUE) {
            RegQueryValueEx(
                hDevKey, TEXT("PortName"), nullptr, nullptr, portName, pcbData);
            RegCloseKey(hDevKey);
          }

          /// Get friendly name
          if (SetupDiGetDeviceRegistryProperty(
                  hDeviceInfo,
                  devInfoData,
                  SPDRP.SPDRP_FRIENDLYNAME,
                  nullptr,
                  friendlyName,
                  255,
                  nullptr) !=
              TRUE) {
            continue;
          }

          /// Get Hardware ID
          if (SetupDiGetDeviceRegistryProperty(hDeviceInfo, devInfoData,
                  SPDRP.SPDRP_HARDWAREID, nullptr, hardwareID, 255, nullptr) !=
              TRUE) {
            continue;
          }

          /// Get MFG
          if (SetupDiGetDeviceRegistryProperty(hDeviceInfo, devInfoData,
                  SPDRP.SPDRP_MFG, nullptr, manufactureName, 255, nullptr) !=
              TRUE) {
            continue;
          }

          // if (SetupDiEnumDeviceInterfaces(hDeviceInfo, devInfoData, classGUID, i, deviceInterfaceData) != TRUE) {
          //   continue;
          // }
          //
          // if (SetupDiGetDeviceInterfaceDetail(hDeviceInfo, deviceInterfaceData, deviceInterfaceDetailData, 1023, nullptr, nullptr) != TRUE) {
          //   continue;
          // }

          /// Convert Wchar to String
          final String portNameStr = portName.cast<Utf16>().toDartString();
          final String friendlyNameStr =
              friendlyName.cast<Utf16>().toDartString();
          // final String interfaceDetailDataStr = deviceInterfaceDetailData.ref.DevicePath;
          // print(interfaceDetailDataStr);
          final String hardwareIDStr = hardwareID.cast<Utf16>().toDartString();
          final String manufactureNameStr =
              manufactureName.cast<Utf16>().toDartString();

          /// add to lists
          portInfoLists.add(PortInfo(
              portName: portNameStr,
              friendlyName: friendlyNameStr,
              hardwareID: hardwareIDStr,
              manufactureName: manufactureNameStr));
        } finally {
          free(portName);
          free(pcbData);
          free(friendlyName);
          free(hardwareID);
          free(manufactureName);
          // free(deviceInterfaceData);
          // free(deviceInterfaceDetailData);
        }
      }

      /// [Destroy Device Info List]
      SetupDiDestroyDeviceInfoList(hDeviceInfo);
    }
    return portInfoLists;
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

/// [PortInfo] storages [portName], [friendlyName], [hardwareID], [manufactureName]
/// [hardwareID] Refer to https://learn.microsoft.com/en-us/windows-hardware/drivers/install/hardware-ids
class PortInfo {
  /// COM Port Name like [COM1]
  final String portName;

  /// Friendly name in windows property
  final String friendlyName;

  final String hardwareID;
  final String manufactureName;

  const PortInfo({
    required this.portName,
    required this.friendlyName,
    required this.hardwareID,
    required this.manufactureName,
  });

  @override
  String toString() {
    return 'Port Name: $portName, FriendlyName: $friendlyName, hardwareID: $hardwareID, manufactureName: $manufactureName';
  }
}
