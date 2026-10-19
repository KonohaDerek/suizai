#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/picker-verification
# Collect device evidence before the emulator action shuts the device down,
# including when instrumentation fails before the picker check can run.
collect_logs() {
  adb logcat -d > build/picker-verification/instrumentation-logcat.txt || true
  adb logcat -d -s 'SUIZAI_METRIC:I' '*:S' > build/picker-verification/rust-read-measurements.log || true
}
trap collect_logs EXIT

start=$(date +%s)
gradle --no-daemon connectedDebugAndroidTest
echo "SUIZAI_METRIC workload=gradle_connected_android_test elapsed_s=$(($(date +%s)-start))"
python3 .github/scripts/verify_system_picker.py
