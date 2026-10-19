use std::collections::HashMap;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::thread;
use std::time::{Duration, Instant};

const MAX_OUTPUT: usize = 65_536;
const MAX_DELAY_MS: u32 = 500;
const FIXTURE_ID: &[u8] = b"bridge-welcome";
const ZH_TW: &[u8] = "SUIZAI 共用核心測試檔案\n".as_bytes();
const EN: &[u8] = b"SUIZAI shared core test file\n";
const JA: &[u8] = "SUIZAI 共通コアのテストファイル\n".as_bytes();

#[repr(i32)]
#[derive(Debug, PartialEq, Eq)]
enum Status {
    Ok = 0,
    InvalidInput = 1,
    InvalidHandle = 2,
    Cancelled = 3,
    BufferTooSmall = 4,
    InternalError = 5,
}

struct Operation {
    bytes: &'static [u8],
    delay: Duration,
    cancelled: AtomicBool,
}

static OPERATIONS: OnceLock<Mutex<HashMap<u64, Arc<Operation>>>> = OnceLock::new();
static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);
#[cfg(test)]
static READ_ACQUIRED: AtomicBool = AtomicBool::new(false);

fn operations() -> &'static Mutex<HashMap<u64, Arc<Operation>>> {
    OPERATIONS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn with_operations<T>(f: impl FnOnce(&mut HashMap<u64, Arc<Operation>>) -> T) -> T {
    let mut guard = operations()
        .lock()
        .unwrap_or_else(|error| error.into_inner());
    f(&mut guard)
}

fn guarded(f: impl FnOnce() -> Status) -> i32 {
    catch_unwind(AssertUnwindSafe(f)).unwrap_or(Status::InternalError) as i32
}

unsafe fn input<'a>(pointer: *const u8, length: usize, max: usize) -> Result<&'a [u8], Status> {
    if length > max || (length != 0 && pointer.is_null()) {
        return Err(Status::InvalidInput);
    }
    if length == 0 {
        Ok(&[])
    } else {
        Ok(std::slice::from_raw_parts(pointer, length))
    }
}

#[no_mangle]
pub extern "C" fn suizai_fixture_open(
    fixture_id: *const u8,
    fixture_id_len: usize,
    locale: *const u8,
    locale_len: usize,
    delay_ms: u32,
    out_handle: *mut u64,
) -> i32 {
    guarded(|| {
        if out_handle.is_null() {
            return Status::InvalidInput;
        }
        unsafe { *out_handle = 0 };
        if delay_ms > MAX_DELAY_MS {
            return Status::InvalidInput;
        }
        let id = unsafe { input(fixture_id, fixture_id_len, 64) };
        let locale = unsafe { input(locale, locale_len, 32) };
        let (Ok(id), Ok(locale)) = (id, locale) else {
            return Status::InvalidInput;
        };
        if id != FIXTURE_ID {
            return Status::InvalidInput;
        }
        let Ok(locale) = std::str::from_utf8(locale) else {
            return Status::InvalidInput;
        };
        let bytes = if locale == "en" || locale.starts_with("en-") {
            EN
        } else if locale == "ja" || locale.starts_with("ja-") {
            JA
        } else {
            ZH_TW
        };
        let Ok(handle) = NEXT_HANDLE.fetch_update(Ordering::Relaxed, Ordering::Relaxed, |next| {
            next.checked_add(1)
        }) else {
            return Status::InternalError;
        };
        let operation = Arc::new(Operation {
            bytes,
            delay: Duration::from_millis(u64::from(delay_ms)),
            cancelled: AtomicBool::new(false),
        });
        with_operations(|registry| {
            registry.insert(handle, operation);
        });
        unsafe { *out_handle = handle };
        Status::Ok
    })
}

#[no_mangle]
pub extern "C" fn suizai_fixture_read(
    handle: u64,
    out: *mut u8,
    capacity: usize,
    out_len: *mut usize,
) -> i32 {
    guarded(|| {
        if out_len.is_null() {
            return Status::InvalidInput;
        }
        unsafe { *out_len = 0 };
        if capacity > MAX_OUTPUT || (capacity != 0 && out.is_null()) {
            return Status::InvalidInput;
        }
        let Some(operation) = with_operations(|registry| registry.get(&handle).cloned()) else {
            return Status::InvalidHandle;
        };
        #[cfg(test)]
        READ_ACQUIRED.store(true, Ordering::Release);
        if operation.cancelled.load(Ordering::Acquire) {
            return Status::Cancelled;
        }
        if capacity < operation.bytes.len() {
            unsafe { *out_len = operation.bytes.len() };
            return Status::BufferTooSmall;
        }
        let deadline = Instant::now() + operation.delay;
        while Instant::now() < deadline {
            if operation.cancelled.load(Ordering::Acquire) {
                return Status::Cancelled;
            }
            thread::sleep(
                deadline
                    .saturating_duration_since(Instant::now())
                    .min(Duration::from_millis(5)),
            );
        }
        // This is the read's cancellation decision point; a later cancel cannot retract copied bytes.
        if operation.cancelled.load(Ordering::Acquire) {
            return Status::Cancelled;
        }
        unsafe {
            ptr::copy_nonoverlapping(operation.bytes.as_ptr(), out, operation.bytes.len());
            *out_len = operation.bytes.len();
        }
        Status::Ok
    })
}

#[no_mangle]
pub extern "C" fn suizai_fixture_cancel(handle: u64) -> i32 {
    guarded(|| {
        let Some(operation) = with_operations(|registry| registry.get(&handle).cloned()) else {
            return Status::InvalidHandle;
        };
        operation.cancelled.store(true, Ordering::Release);
        Status::Ok
    })
}

#[no_mangle]
pub extern "C" fn suizai_fixture_release(handle: u64) -> i32 {
    guarded(|| {
        let Some(operation) = with_operations(|registry| registry.remove(&handle)) else {
            return Status::InvalidHandle;
        };
        operation.cancelled.store(true, Ordering::Release);
        Status::Ok
    })
}

#[no_mangle]
pub extern "C" fn suizai_fixture_active_handles() -> usize {
    // A count cannot unwind into C; a poisoned mutex remains readable.
    catch_unwind(|| with_operations(|registry| registry.len())).unwrap_or(usize::MAX)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    static TEST_LOCK: Mutex<()> = Mutex::new(());

    fn open(locale: &[u8], delay_ms: u32) -> u64 {
        let mut handle = 0;
        assert_eq!(
            suizai_fixture_open(
                FIXTURE_ID.as_ptr(),
                FIXTURE_ID.len(),
                locale.as_ptr(),
                locale.len(),
                delay_ms,
                &mut handle,
            ),
            Status::Ok as i32
        );
        handle
    }

    fn await_read_acquired() {
        let deadline = Instant::now() + Duration::from_secs(1);
        while !READ_ACQUIRED.load(Ordering::Acquire) {
            assert!(
                Instant::now() < deadline,
                "reader did not acquire its operation"
            );
            thread::yield_now();
        }
    }

    #[test]
    fn locales_and_buffer_contract() {
        let _guard = TEST_LOCK.lock().unwrap();
        for (locale, expected) in [("zh-TW", ZH_TW), ("en", EN), ("ja", JA), ("fr", ZH_TW)] {
            let handle = open(locale.as_bytes(), 0);
            let mut len = 123;
            assert_eq!(
                suizai_fixture_read(handle, ptr::null_mut(), 0, &mut len),
                Status::BufferTooSmall as i32
            );
            assert_eq!(len, expected.len());
            let mut output = [0u8; 128];
            assert_eq!(
                suizai_fixture_read(handle, output.as_mut_ptr(), output.len(), &mut len),
                Status::Ok as i32
            );
            assert_eq!(&output[..len], expected);
            assert_eq!(suizai_fixture_release(handle), Status::Ok as i32);
        }
        assert_eq!(suizai_fixture_active_handles(), 0);
    }

    #[test]
    fn invalid_inputs_and_repeated_release() {
        let _guard = TEST_LOCK.lock().unwrap();
        let mut handle = 99;
        assert_eq!(
            suizai_fixture_open(ptr::null(), 1, ptr::null(), 0, 0, &mut handle),
            Status::InvalidInput as i32
        );
        assert_eq!(handle, 0);
        assert_eq!(
            suizai_fixture_open(
                FIXTURE_ID.as_ptr(),
                FIXTURE_ID.len(),
                b"\xff".as_ptr(),
                1,
                0,
                &mut handle
            ),
            Status::InvalidInput as i32
        );
        assert_eq!(
            suizai_fixture_open(b"unknown".as_ptr(), 7, ptr::null(), 0, 0, &mut handle),
            Status::InvalidInput as i32
        );
        assert_eq!(
            suizai_fixture_open(
                FIXTURE_ID.as_ptr(),
                FIXTURE_ID.len(),
                ptr::null(),
                0,
                0,
                ptr::null_mut()
            ),
            Status::InvalidInput as i32
        );
        assert_eq!(
            suizai_fixture_open(
                FIXTURE_ID.as_ptr(),
                FIXTURE_ID.len(),
                ptr::null(),
                0,
                501,
                &mut handle
            ),
            Status::InvalidInput as i32
        );
        let handle = open(b"en", 0);
        let mut len = 1;
        assert_eq!(
            suizai_fixture_read(handle, ptr::null_mut(), 1, &mut len),
            Status::InvalidInput as i32
        );
        assert_eq!(len, 0);
        assert_eq!(
            suizai_fixture_read(handle, ptr::null_mut(), MAX_OUTPUT + 1, &mut len),
            Status::InvalidInput as i32
        );
        assert_eq!(
            suizai_fixture_read(handle, ptr::null_mut(), 0, ptr::null_mut()),
            Status::InvalidInput as i32
        );
        assert_eq!(suizai_fixture_release(handle), Status::Ok as i32);
        assert_eq!(suizai_fixture_release(handle), Status::InvalidHandle as i32);
        assert_eq!(suizai_fixture_cancel(handle), Status::InvalidHandle as i32);
        assert_eq!(
            suizai_fixture_read(handle, ptr::null_mut(), 0, &mut len),
            Status::InvalidHandle as i32
        );
        assert_eq!(suizai_fixture_active_handles(), 0);
    }

    #[test]
    fn cancellation_before_and_during_read() {
        let _guard = TEST_LOCK.lock().unwrap();
        let before = open(b"en", 0);
        assert_eq!(suizai_fixture_cancel(before), Status::Ok as i32);
        let mut output = [0u8; 128];
        let mut len = 123;
        assert_eq!(
            suizai_fixture_read(before, output.as_mut_ptr(), output.len(), &mut len),
            Status::Cancelled as i32
        );
        assert_eq!(len, 0);
        assert_eq!(suizai_fixture_release(before), Status::Ok as i32);

        let during = open(b"ja", 500);
        READ_ACQUIRED.store(false, Ordering::Release);
        let reader = thread::spawn(move || {
            let mut output = [0u8; 128];
            let mut len = 123;
            let status = suizai_fixture_read(during, output.as_mut_ptr(), output.len(), &mut len);
            (status, len)
        });
        await_read_acquired();
        assert_eq!(suizai_fixture_cancel(during), Status::Ok as i32);
        assert_eq!(reader.join().unwrap(), (Status::Cancelled as i32, 0));
        assert_eq!(suizai_fixture_release(during), Status::Ok as i32);
        assert_eq!(suizai_fixture_active_handles(), 0);
    }

    #[test]
    fn release_during_read_keeps_operation_alive_safely() {
        let _guard = TEST_LOCK.lock().unwrap();
        let handle = open(b"zh-TW", 500);
        READ_ACQUIRED.store(false, Ordering::Release);
        let reader = thread::spawn(move || {
            let mut output = [0u8; 128];
            let mut len = 123;
            (
                suizai_fixture_read(handle, output.as_mut_ptr(), output.len(), &mut len),
                len,
            )
        });
        await_read_acquired();
        assert_eq!(suizai_fixture_release(handle), Status::Ok as i32);
        assert_eq!(reader.join().unwrap(), (Status::Cancelled as i32, 0));
        assert_eq!(suizai_fixture_active_handles(), 0);
    }
}
