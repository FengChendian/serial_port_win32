import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';
import 'dart:ffi';

///[wait] is WaitCommEvent
Future<int> wait(int? handler) async {
  /// EventMask
  Pointer<DWORD> _dwCommEvent = calloc<DWORD>();
  return WaitCommEvent(handler!, _dwCommEvent, nullptr);
}