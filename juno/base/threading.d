/**
 * Copyright: (c) 2009 John Chapman
 *
 * License: See $(LINK2 ..\..\licence.txt, licence.txt) for use and distribution terms.
 */
module juno.base.threading;

import juno.base.core,
  juno.base.string,
  juno.base.native,
  juno.base.time;

/**
 * Suspends the current thread for a specified time.
 * Params: milliseconds = The number of _milliseconds for which the thread is blocked. Specify -1 to block the thread indefinitely.
 */
void sleep(uint milliseconds) {
  .Sleep(milliseconds);
}

/**
 * Suspends the current thread for a specified time.
 * Params: timeout = The amount of time for which the thread is blocked. Specify -1 to block the thread indefinitely.
 */
void sleep(TimeSpan timeout) {
  .Sleep(cast(uint)timeout.totalMilliseconds);
}

enum EventResetMode {
  Auto,
  Manual
}

abstract class WaitHandle {

  private Handle handle_ = cast(Handle)INVALID_HANDLE_VALUE;

  void close() {
    if (handle_ != Handle.init) {
      CloseHandle(handle_);
      handle_ = Handle.init;
    }
  }

  bool waitOne(uint millisecondsTimeout = INFINITE) {
    uint r = WaitForSingleObjectEx(handle_, millisecondsTimeout, 1);
    return (r != WAIT_ABANDONED && r != WAIT_TIMEOUT);
  }

  bool waitOne(TimeSpan timeout) {
    return waitOne(cast(uint)timeout.totalMilliseconds);
  }

  static bool waitAll(WaitHandle[] waitHandles, uint millisecondsTimeout = INFINITE) {
    Handle[] handles = new Handle[waitHandles.length];
    foreach (i, waitHandle; waitHandles) {
      handles[i] = waitHandle.handle_;
    }

    uint r = WaitForMultipleObjectsEx(cast(uint)handles.length, handles.ptr, 1, millisecondsTimeout, 1);
    return (r != WAIT_ABANDONED && r != WAIT_TIMEOUT);
  }

  static uint waitAny(WaitHandle[] waitHandles, uint millisecondsTimeout = INFINITE) {
    Handle[] handles = new Handle[waitHandles.length];
    foreach (i, waitHandle; waitHandles) {
      handles[i] = waitHandle.handle_;
    }

    return WaitForMultipleObjectsEx(cast(uint)handles.length, handles.ptr, 0, millisecondsTimeout, 1);
  }

  static bool signalAndWait(WaitHandle toSignal, WaitHandle toWaitOn, uint millisecondsTimeout = INFINITE) {
    uint r = SignalObjectAndWait(toSignal.handle_, toWaitOn.handle_, millisecondsTimeout, 1);
    return (r != WAIT_ABANDONED && r != WAIT_TIMEOUT);
  }

  static bool signalAndWait(WaitHandle toSignal, WaitHandle toWaitOn, TimeSpan timeout) {
    return signalAndWait(toSignal, toWaitOn, cast(uint)timeout.totalMilliseconds);
  }

  @property void handle(Handle value) {
    if (value == Handle.init)
      handle_ = INVALID_HANDLE_VALUE;
    else
      handle_ = handle;
  }

  @property Handle handle() {
    if (handle_ == Handle.init)
      return INVALID_HANDLE_VALUE;
    return handle_;
  }

}

class EventWaitHandle : WaitHandle {

  this(bool initialState, EventResetMode mode) {
    handle_ = CreateEvent(null, (mode == EventResetMode.Manual) ? 1 : 0, initialState ? 1 : 0, null);
  }

  final bool set() {
    return SetEvent(handle_) != 0;
  }

  final bool reset() {
    return ResetEvent(handle_) != 0;
  }

}

final class AutoResetEvent : EventWaitHandle {

  this(bool initialState) {
    super(initialState, EventResetMode.Auto);
  }

}

final class ManualResetEvent : EventWaitHandle {

  this(bool initialState) {
    super(initialState, EventResetMode.Manual);
  }

}

final class Mutex : WaitHandle {

  this(bool initiallyOwned = false, string name = null) {
    Handle hMutex = CreateMutex(null, (initiallyOwned ? 1 : 0), name.toUtf16z());
    uint error = GetLastError();

    if (error == ERROR_ACCESS_DENIED && (hMutex == Handle.init || hMutex == INVALID_HANDLE_VALUE))
      hMutex = OpenMutex(MUTEX_MODIFY_STATE | SYNCHRONIZE, 0, name.toUtf16z());

    handle_ = hMutex;
  }

  void release() {
    ReleaseMutex(handle_);
  }

}

final class Semaphore : WaitHandle {

  this(int initialCount, int maximumCount, string name = null) {
    handle_ = CreateSemaphore(null, initialCount, maximumCount, name.toUtf16z());
  }

  int release(int releaseCount = 1) {
    int prevCount;
    if (!ReleaseSemaphore(handle_, releaseCount, prevCount))
      throw new Exception("Adding the given count to the semaphore would cause it to exceed its maximum count.");
    return prevCount;
  }

}
