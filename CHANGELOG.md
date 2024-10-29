## 1.4.0

- require `includeZeroTerminator` parameter for clear write function.
- update dependency versions for bugs fixed


## 1.3.0

- fix bugs
- add `readBytesUntil` function
- add more option when read or write
- update docs

## 1.2.0

- update read performance
- add timeout option in write function

## 1.1.0

- remove `readBytesOnce` Function to fix async race
- Don't purge com before read. Some computers may purge com after read in async mode.

## 1.0.0

- Temporarily remove readBytesOnListen for bugs, using `readBytesOnce` instead.

## 0.7.0

- add query for hardwareID(include VID and PID ), MFG(manufacture name)
- can query different class GUID

## 0.6.0

- add [getPortsWithFullMessages] functions
- plan to support VID and PID
- can get friendly name of port

## 0.5.4

- catch registry not found exception

## 0.5.3

- update packages: win32 & ffi
- Maintenance updates
- doc updates

## 0.5.2

- bug fixed
  - write operation always return false

## 0.5.1

- bug fixed
  - random data due to pointer free
  - open greater than COM9

## 0.5.0

- add Flow Control

## 0.4.9

- delete flutter sdk dependency

## 0.4.8

- delete print message in source code
- update doc

## 0.4.7

- using WaitingForSingleObject Function
- adaptive read size if InQue < readByteSize

## 0.4.6

- always read byteSize which was set

## 0.4.5

- bugs fixed

## 0.4.4

- fix read bug

## 0.4.3

- fix read bug

## 0.4.2

- using overlapped mode
- streaming reading data
- add `readOnBeforeFunction`
- add `readOnListenFunction`
- bug fixed

## 0.4.1

- fix `close` bug

## 0.4.0

- fix ui blocking

## 0.3.1

- add [readBytesOnceOnListen] function

## 0.3.0

- using waitEvent to listen port

## 0.2.2

- change `readBytesOnListen` API
- add `readBytesOnce`, `openStatus` ...

## 0.1.2

- add `readOnListen` API

## 0.1.1

- add `closeOnListen()` API

## 0.1.0

- add more write API
- revise doc

## 0.0.9

- add write API
- add more doc

## 0.0.8

- remove `reopenPort` function, instead by `open()`
- add `openWithSettings()` API
- can setup parameters when create instance

## 0.0.7

- make API more efficient
- add more API
- Compatible with new win32 package API
- fix bugs
- add more doc

## 0.0.6

- fix bugs
- add reopen method

## 0.0.5

- fix memory allocation bug
- change Function getAvailablePorts() structure

## 0.0.4

free pointers when called

## 0.0.3

Add more docs.

## 0.0.2

Update example and fix bug.

## 0.0.1

Init all files about Serial Port on Windows.
